//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import LibSignalClient

public class OWSMessageDecrypter {

    private var senderIdsResetDuringCurrentBatch = NSMutableSet()
    private var placeholderCleanupTimer: Timer? {
        didSet { oldValue?.invalidate() }
    }

    public init(appReadiness: AppReadiness) {
        SwiftSingletons.register(self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(messageProcessorDidDrainQueue),
            name: MessageProcessor.messageProcessorDidDrainQueue,
            object: nil
        )

        appReadiness.runNowOrWhenAppDidBecomeReadyAsync { [weak self] in
            guard let self = self else { return }
            guard CurrentAppContext().isMainApp else { return }
            self.cleanUpExpiredPlaceholders()
        }
    }

    @objc
    func messageProcessorDidDrainQueue() {
        // We don't want to send additional resets until we
        // have received the "empty" response from the WebSocket
        // or finished at least one REST fetch.
        guard SSKEnvironment.shared.messageFetcherJobRef.hasCompletedInitialFetch else { return }

        // We clear all recently reset sender ids any time the
        // decryption queue has drained, so that any new messages
        // that fail to decrypt will reset the session again.
        senderIdsResetDuringCurrentBatch.removeAllObjects()
    }

    private func trySendNullMessage(
        in contactThread: TSContactThread,
        senderId: String,
        transaction: SDSAnyWriteTransaction
    ) {
        if RemoteConfig.current.automaticSessionResetKillSwitch {
            Logger.warn("Skipping null message after undecryptable message from \(senderId) due to kill switch.")
            return
        }

        let store = KeyValueStore(collection: "OWSMessageDecrypter+NullMessage")

        let lastNullMessageDate = store.getDate(senderId, transaction: transaction.asV2Read)
        let timeSinceNullMessage = abs(lastNullMessageDate?.timeIntervalSinceNow ?? .infinity)
        guard timeSinceNullMessage > RemoteConfig.current.automaticSessionResetAttemptInterval else {
            Logger.warn("Skipping null message after undecryptable message from \(senderId), " +
                            "last null message sent \(lastNullMessageDate!.ows_millisecondsSince1970).")
            return
        }

        Logger.info("Sending null message to reset session after undecryptable message from: \(senderId)")
        store.setDate(Date(), key: senderId, transaction: transaction.asV2Write)

        transaction.addAsyncCompletionOffMain {
            SSKEnvironment.shared.databaseStorageRef.write { transaction in
                let nullMessage = OWSOutgoingNullMessage(contactThread: contactThread, transaction: transaction)
                let preparedMessage = PreparedOutgoingMessage.preprepared(
                    transientMessageWithoutAttachments: nullMessage
                )
                SSKEnvironment.shared.messageSenderJobQueueRef.add(
                    .promise,
                    message: preparedMessage,
                    transaction: transaction
                ).done(on: DispatchQueue.global()) {
                    Logger.info("Successfully sent null message after session reset " +
                                    "for undecryptable message from \(senderId)")
                }.catch(on: DispatchQueue.global()) { error in
                    if error is UntrustedIdentityError {
                        Logger.info("Failed to send null message after session reset for " +
                                        "for undecryptable message from \(senderId) (\(error))")
                    } else {
                        owsFailDebug("Failed to send null message after session reset " +
                                        "for undecryptable message from \(senderId) (\(error))")
                    }
                }
            }
        }
    }

    private func trySendReactiveProfileKey(to sourceAci: Aci, tx transaction: SDSAnyWriteTransaction) {
        let store = KeyValueStore(collection: "OWSMessageDecrypter+ReactiveProfileKey")

        let lastProfileKeyMessageDate = store.getDate(sourceAci.serviceIdUppercaseString, transaction: transaction.asV2Read)
        let timeSinceProfileKeyMessage = abs(lastProfileKeyMessageDate?.timeIntervalSinceNow ?? .infinity)
        guard timeSinceProfileKeyMessage > RemoteConfig.current.reactiveProfileKeyAttemptInterval else {
            Logger.warn("Skipping reactive profile key for \(sourceAci), last reactive profile key message sent \(lastProfileKeyMessageDate!.ows_millisecondsSince1970).")
            return
        }

        Logger.info("Sending reactive profile key to \(sourceAci)")
        store.setDate(Date(), key: sourceAci.serviceIdUppercaseString, transaction: transaction.asV2Write)

        let contactThread = TSContactThread.getOrCreateThread(
            withContactAddress: SignalServiceAddress(sourceAci),
            transaction: transaction
        )

        let profileKeyMessage = OWSProfileKeyMessage(thread: contactThread, transaction: transaction)
        let preparedMessage = PreparedOutgoingMessage.preprepared(
            transientMessageWithoutAttachments: profileKeyMessage
        )
        SSKEnvironment.shared.messageSenderJobQueueRef.add(message: preparedMessage, transaction: transaction)
    }

    private struct UnsealedEnvelope {
        let sourceAci: Aci
        let sourceDeviceId: UInt32
        let content: Data?
        let cipherType: CiphertextMessage.MessageType
        let untrustedGroupId: Data?
        let contentHint: SealedSenderContentHint
    }

    private func processError(
        _ error: Error,
        validatedEnvelope: ValidatedIncomingEnvelope,
        unsealedEnvelope: UnsealedEnvelope?,
        tx transaction: SDSAnyWriteTransaction
    ) -> Error {
        let logString = "Error while decrypting \(Self.description(for: validatedEnvelope.envelope)), error: \(error)"

        if case SignalError.duplicatedMessage(_) = error {
            Logger.warn(logString)
            // Duplicate messages are not recorded in the database.
            return OWSError(error: .failedToDecryptDuplicateMessage,
                            description: "Duplicate message",
                            isRetryable: false,
                            userInfo: [NSUnderlyingErrorKey: error])
        }

        Logger.error(logString)

        let wrappedError: Error
        if (error as NSError).domain == OWSError.errorDomain {
            wrappedError = error
        } else {
            wrappedError = OWSError(error: .failedToDecryptMessage,
                                    description: "Decryption error",
                                    isRetryable: false,
                                    userInfo: [NSUnderlyingErrorKey: error])
        }

        guard let unsealedEnvelope else {
            return wrappedError
        }

        let sourceAci = unsealedEnvelope.sourceAci
        let sourceAddress = SignalServiceAddress(sourceAci)

        if
            SSKEnvironment.shared.blockingManagerRef.isAddressBlocked(sourceAddress, transaction: transaction) ||
            DependenciesBridge.shared.recipientHidingManager.isHiddenAddress(sourceAddress, tx: transaction.asV2Read)
        {
            Logger.info("Ignoring decryption error for blocked or hidden user \(sourceAddress) \(wrappedError).")
            return wrappedError
        }

        let contactThread = TSContactThread.getOrCreateThread(withContactAddress: sourceAddress, transaction: transaction)

        let errorMessage: TSErrorMessage?

        switch validatedEnvelope.localIdentity {
        case .aci:
            if
                !RemoteConfig.current.messageResendKillSwitch,
                let modernResendErrorMessageBytes = buildResendRequestDecryptionError(
                    validatedEnvelope: validatedEnvelope,
                    unsealedEnvelope: unsealedEnvelope
                )
            {
                Logger.info("Performing modern resend of \(unsealedEnvelope.contentHint) content with timestamp \(validatedEnvelope.timestamp)")

                switch unsealedEnvelope.contentHint {
                case .default:
                    // If default, insert an error message right away
                    errorMessage = .failedDecryption(
                        sender: sourceAddress,
                        groupId: unsealedEnvelope.untrustedGroupId,
                        timestamp: validatedEnvelope.timestamp,
                        tx: transaction
                    )
                case .resendable:
                    // If resendable, insert a placeholder
                    let recoverableErrorMessage = OWSRecoverableDecryptionPlaceholder(
                        failedEnvelopeTimestamp: validatedEnvelope.timestamp,
                        sourceAci: AciObjC(sourceAci),
                        untrustedGroupId: unsealedEnvelope.untrustedGroupId,
                        transaction: transaction
                    )
                    if let recoverableErrorMessage {
                        schedulePlaceholderCleanupIfNecessary(for: recoverableErrorMessage)
                    }
                    errorMessage = recoverableErrorMessage
                case .implicit:
                    errorMessage = nil
                default:
                    owsFailDebug("Unexpected content hint")
                    errorMessage = nil
                }

                // We always send a resend request, even if the contentHint indicates the sender
                // won't be able to fulfill the request. This will notify the sender to reset
                // the session.
                sendResendRequest(
                    errorMessageBytes: modernResendErrorMessageBytes,
                    sourceAci: sourceAci,
                    failedEnvelopeGroupId: unsealedEnvelope.untrustedGroupId,
                    transaction: transaction
                )
            } else {
                Logger.info("Performing legacy session reset of \(unsealedEnvelope.contentHint) content with timestamp \(validatedEnvelope.timestamp)")

                let didReset = resetSessionIfNecessary(
                    for: sourceAci,
                    sourceDeviceId: unsealedEnvelope.sourceDeviceId,
                    contactThread: contactThread,
                    transaction: transaction
                )

                if didReset {
                    // Always notify the user that we have performed an automatic archive.
                    errorMessage = .sessionRefresh(thread: contactThread)
                } else {
                    errorMessage = nil
                }
            }
        case .pni:
            Logger.info("Not resetting or requesting resend of message sent to PNI.")

            DependenciesBridge.shared.linkedDevicePniKeyManager
                .recordSuspectedIssueWithPniIdentityKey(tx: transaction.asV2Write)

            errorMessage = .failedDecryption(
                sender: sourceAddress,
                groupId: unsealedEnvelope.untrustedGroupId,
                timestamp: validatedEnvelope.timestamp,
                tx: transaction
            )
        }

        switch error as? SignalError {
        case .untrustedIdentity:
            // Should no longer get here, since we now record the new identity for incoming messages.
            owsFailDebug("Failed to trust identity on incoming message from \(sourceAci)")
        case .duplicatedMessage:
            preconditionFailure("checked above")
        default: // another SignalError, or another kind of Error altogether
            break
        }

        if let errorMessage = errorMessage {
            errorMessage.anyInsert(transaction: transaction)
            SSKEnvironment.shared.notificationPresenterRef.notifyUser(forErrorMessage: errorMessage, thread: contactThread, transaction: transaction)
            SSKEnvironment.shared.notificationPresenterRef.notifyTestPopulation(ofErrorMessage: "Failed decryption of envelope: \(validatedEnvelope.timestamp)")
        }

        return wrappedError
    }

    private func buildResendRequestDecryptionError(
        validatedEnvelope: ValidatedIncomingEnvelope,
        unsealedEnvelope: UnsealedEnvelope
    ) -> Data? {
        guard validatedEnvelope.localIdentity == .aci else {
            return nil
        }

        guard [.whisper, .senderKey, .preKey, .plaintext].contains(unsealedEnvelope.cipherType) else {
            return nil
        }

        guard let unsealedContent = unsealedEnvelope.content else {
            return nil
        }

        do {
            let errorMessage = try DecryptionErrorMessage(
                originalMessageBytes: unsealedContent,
                type: unsealedEnvelope.cipherType,
                timestamp: validatedEnvelope.timestamp,
                originalSenderDeviceId: unsealedEnvelope.sourceDeviceId
            )
            return Data(errorMessage.serialize())
        } catch {
            owsFailDebug("Could not build DecryptionError: \(error)")
            return nil
        }
    }

    private func sendResendRequest(
        errorMessageBytes: Data,
        sourceAci: Aci,
        failedEnvelopeGroupId: Data?,
        transaction: SDSAnyWriteTransaction
    ) {
        let resendRequest = OWSOutgoingResendRequest(
            errorMessageBytes: errorMessageBytes,
            sourceAci: AciObjC(sourceAci),
            failedEnvelopeGroupId: failedEnvelopeGroupId,
            transaction: transaction
        )
        let preparedMessage = PreparedOutgoingMessage.preprepared(
            transientMessageWithoutAttachments: resendRequest
        )
        SSKEnvironment.shared.messageSenderJobQueueRef.add(message: preparedMessage, transaction: transaction)
    }

    private func resetSessionIfNecessary(
        for sourceAci: Aci,
        sourceDeviceId: UInt32,
        contactThread: TSContactThread,
        transaction: SDSAnyWriteTransaction
    ) -> Bool {
        // Since the message failed to decrypt, we want to reset our session
        // with this device to ensure future messages we receive are decryptable.
        // We achieve this by archiving our current session with this device.
        // It's important we don't do this if we've already recently reset the
        // session for a given device, for example if we're processing a backlog
        // of 50 message from Alice that all fail to decrypt we don't want to
        // reset the session 50 times. We accomplish this by tracking the UUID +
        // device ID pair that we have recently reset, so we can skip subsequent
        // resets. When the message decrypt queue is drained, the list of recently
        // reset IDs is cleared.
        let senderId = "\(sourceAci).\(sourceDeviceId)"
        if !senderIdsResetDuringCurrentBatch.contains(senderId) {
            senderIdsResetDuringCurrentBatch.add(senderId)

            // We don't reset sessions for messages sent to our PNI because those are
            // receive-only & we don't send retries FROM our PNI back to the sender.

            Logger.warn("Archiving session for undecryptable message from \(senderId)")
            let sessionStore = DependenciesBridge.shared.signalProtocolStoreManager.signalProtocolStore(for: .aci).sessionStore
            sessionStore.archiveSession(for: sourceAci, deviceId: sourceDeviceId, tx: transaction.asV2Write)

            trySendNullMessage(in: contactThread, senderId: senderId, transaction: transaction)
            return true
        } else {
            Logger.warn("Skipping session reset for undecryptable message from \(senderId), " +
                            "already reset during this batch")
            return false
        }
    }

    func decryptIdentifiedEnvelope(
        _ validatedEnvelope: ValidatedIncomingEnvelope,
        cipherType: CiphertextMessage.MessageType,
        localIdentifiers: LocalIdentifiers,
        tx transaction: SDSAnyWriteTransaction
    ) throws -> DecryptedIncomingEnvelope {
        // This method is only used for identified envelopes. If an unidentified
        // envelope is ever passed here, we'll reject on the next line because it
        // won't have a source.
        let (sourceAci, sourceDeviceId) = try validatedEnvelope.validateSource(Aci.self)
        let localIdentity = validatedEnvelope.localIdentity
        do {
            guard let encryptedData = validatedEnvelope.envelope.content else {
                throw OWSError(error: .failedToDecryptMessage,
                               description: "Envelope has no content",
                               isRetryable: false)
            }

            let identityManager = DependenciesBridge.shared.identityManager
            let protocolAddress = ProtocolAddress(sourceAci, deviceId: sourceDeviceId)
            let signalProtocolStore = DependenciesBridge.shared.signalProtocolStoreManager.signalProtocolStore(for: validatedEnvelope.localIdentity)

            let plaintext: [UInt8]
            switch cipherType {
            case .whisper:
                let message = try SignalMessage(bytes: encryptedData)
                plaintext = try signalDecrypt(
                    message: message,
                    from: protocolAddress,
                    sessionStore: signalProtocolStore.sessionStore,
                    identityStore: identityManager.libSignalStore(for: localIdentity, tx: transaction.asV2Write),
                    context: transaction
                )
                sendReactiveProfileKeyIfNecessary(to: sourceAci, tx: transaction)
            case .preKey:
                if DependenciesBridge.shared.tsAccountManager.registrationState(tx: transaction.asV2Read).isRegistered {
                    DependenciesBridge.shared.preKeyManager.checkPreKeysIfNecessary(tx: transaction.asV2Read)
                }
                let message = try PreKeySignalMessage(bytes: encryptedData)
                plaintext = try signalDecryptPreKey(
                    message: message,
                    from: protocolAddress,
                    sessionStore: signalProtocolStore.sessionStore,
                    identityStore: identityManager.libSignalStore(for: localIdentity, tx: transaction.asV2Write),
                    preKeyStore: signalProtocolStore.preKeyStore,
                    signedPreKeyStore: signalProtocolStore.signedPreKeyStore,
                    kyberPreKeyStore: signalProtocolStore.kyberPreKeyStore,
                    context: transaction
                )
            case .senderKey:
                plaintext = try groupDecrypt(
                    encryptedData,
                    from: protocolAddress,
                    store: SSKEnvironment.shared.senderKeyStoreRef,
                    context: transaction
                )
            case .plaintext:
                let plaintextMessage = try PlaintextContent(bytes: encryptedData)
                plaintext = plaintextMessage.body

            // FIXME: return this to @unknown default once cipherType is represented
            // as a finite enum.
            default:
                owsFailDebug("Unexpected ciphertext type: \(cipherType.rawValue)")
                throw OWSError(error: .failedToDecryptMessage,
                               description: "Unexpected Ciphertext type.",
                               isRetryable: false)
            }

            let plaintextData = Data(plaintext).withoutPadding()
            let decryptedEnvelope = DecryptedIncomingEnvelope(
                validatedEnvelope: validatedEnvelope,
                updatedEnvelope: validatedEnvelope.envelope,
                sourceAci: sourceAci,
                sourceDeviceId: sourceDeviceId,
                wasReceivedByUD: false,
                plaintextData: plaintextData
            )

            processDecryptedEnvelope(
                decryptedEnvelope,
                localIdentifiers: localIdentifiers,
                mergeRecipient: { transaction in
                    let recipientFetcher = DependenciesBridge.shared.recipientFetcher
                    return recipientFetcher.fetchOrCreate(serviceId: sourceAci, tx: transaction)
                },
                tx: transaction.asV2Write
            )

            return decryptedEnvelope
        } catch {
            throw processError(
                error,
                validatedEnvelope: validatedEnvelope,
                unsealedEnvelope: UnsealedEnvelope(
                    sourceAci: sourceAci,
                    sourceDeviceId: sourceDeviceId,
                    content: validatedEnvelope.envelope.content,
                    cipherType: cipherType,
                    untrustedGroupId: nil,
                    contentHint: .default
                ),
                tx: transaction
            )
        }
    }

    private func sendReactiveProfileKeyIfNecessary(to sourceAci: Aci, tx transaction: SDSAnyWriteTransaction) {
        if DependenciesBridge.shared.tsAccountManager.localIdentifiers(tx: transaction.asV2Read)?.aci == sourceAci {
            return
        }

        if SSKEnvironment.shared.blockingManagerRef.isAddressBlocked(SignalServiceAddress(sourceAci), transaction: transaction) {
            Logger.info("Skipping send of reactive profile key to blocked address")
            return
        }

        // We do this work in an async completion so we don't delay
        // receipt of this message.
        transaction.addAsyncCompletionOffMain {
            let needsReactiveProfileKeyMessage: Bool = SSKEnvironment.shared.databaseStorageRef.read { transaction in
                // This user is whitelisted, they should have our profile key / be sending UD messages
                // Send them our profile key in case they somehow lost it.
                if SSKEnvironment.shared.profileManagerRef.isUser(
                    inProfileWhitelist: SignalServiceAddress(sourceAci),
                    transaction: transaction
                ) {
                    return true
                }

                // If we're in a V2 group with this user, they should also have our profile key /
                // be sending UD messages. Send them it in case they somehow lost it.
                var needsReactiveProfileKeyMessage = false
                TSGroupThread.enumerateGroupThreads(
                    with: SignalServiceAddress(sourceAci),
                    transaction: transaction
                ) { thread, stop in
                    guard thread.isGroupV2Thread else { return }
                    guard thread.isLocalUserFullMember else { return }
                    stop.pointee = true
                    needsReactiveProfileKeyMessage = true
                }
                return needsReactiveProfileKeyMessage
            }

            if needsReactiveProfileKeyMessage {
                SSKEnvironment.shared.databaseStorageRef.write { transaction in
                    self.trySendReactiveProfileKey(to: sourceAci, tx: transaction)
                }
            }
        }
    }

    func decryptUnidentifiedSenderEnvelope(
        _ validatedEnvelope: ValidatedIncomingEnvelope,
        localIdentifiers: LocalIdentifiers,
        localDeviceId: UInt32,
        tx transaction: SDSAnyWriteTransaction
    ) throws -> DecryptedIncomingEnvelope {
        let localIdentity = validatedEnvelope.localIdentity
        guard let encryptedData = validatedEnvelope.envelope.content else {
            throw OWSAssertionError("UD Envelope is missing content.")
        }
        let identityManager = DependenciesBridge.shared.identityManager
        let signalProtocolStore = DependenciesBridge.shared.signalProtocolStoreManager.signalProtocolStore(for: localIdentity)

        let cipher = try SMKSecretSessionCipher(
            sessionStore: signalProtocolStore.sessionStore,
            preKeyStore: signalProtocolStore.preKeyStore,
            signedPreKeyStore: signalProtocolStore.signedPreKeyStore,
            kyberPreKeyStore: signalProtocolStore.kyberPreKeyStore,
            identityStore: identityManager.libSignalStore(for: localIdentity, tx: transaction.asV2Write),
            senderKeyStore: SSKEnvironment.shared.senderKeyStoreRef
        )

        let decryptResult: SMKDecryptResult
        do {
            decryptResult = try cipher.decryptMessage(
                trustRoot: SSKEnvironment.shared.udManagerRef.trustRoot,
                cipherTextData: encryptedData,
                timestamp: validatedEnvelope.serverTimestamp,
                localIdentifiers: localIdentifiers,
                localDeviceId: localDeviceId,
                protocolContext: transaction
            )
        } catch let outerError as SecretSessionKnownSenderError {
            throw handleUnidentifiedSenderDecryptionError(
                outerError.underlyingError,
                validatedEnvelope: validatedEnvelope,
                unsealedEnvelope: UnsealedEnvelope(
                    sourceAci: outerError.senderAci,
                    sourceDeviceId: outerError.senderDeviceId,
                    content: outerError.unsealedContent,
                    cipherType: outerError.cipherType,
                    untrustedGroupId: outerError.groupId,
                    contentHint: SealedSenderContentHint(outerError.contentHint)
                ),
                transaction: transaction
            )
        } catch {
            throw handleUnidentifiedSenderDecryptionError(
                error,
                validatedEnvelope: validatedEnvelope,
                unsealedEnvelope: nil,
                transaction: transaction
            )
        }

        if
            decryptResult.messageType == .prekey,
            DependenciesBridge.shared.tsAccountManager.registrationState(tx: transaction.asV2Read).isRegistered
        {
            DependenciesBridge.shared.preKeyManager.checkPreKeysIfNecessary(tx: transaction.asV2Read)
        }

        let rawSourceDeviceId = decryptResult.senderDeviceId
        guard rawSourceDeviceId > 0, rawSourceDeviceId < UInt32.max else {
            throw OWSAssertionError("Invalid UD sender device id.")
        }
        let sourceDeviceId = rawSourceDeviceId

        let envelopeBuilder = validatedEnvelope.envelope.asBuilder()
        envelopeBuilder.setSourceServiceID(decryptResult.senderAci.serviceIdString)
        envelopeBuilder.setSourceDevice(sourceDeviceId)

        let decryptedEnvelope = DecryptedIncomingEnvelope(
            validatedEnvelope: validatedEnvelope,
            updatedEnvelope: try envelopeBuilder.build(),
            sourceAci: decryptResult.senderAci,
            sourceDeviceId: sourceDeviceId,
            wasReceivedByUD: validatedEnvelope.envelope.sourceServiceID == nil,
            plaintextData: decryptResult.paddedPayload.withoutPadding()
        )

        processDecryptedEnvelope(
            decryptedEnvelope,
            localIdentifiers: localIdentifiers,
            mergeRecipient: { transaction in
                return DependenciesBridge.shared.recipientMerger.applyMergeFromSealedSender(
                    localIdentifiers: localIdentifiers,
                    aci: decryptResult.senderAci,
                    phoneNumber: E164(decryptResult.senderE164),
                    tx: transaction
                )
            },
            tx: transaction.asV2Write
        )

        return decryptedEnvelope
    }

    private func handleUnidentifiedSenderDecryptionError(
        _ error: Error,
        validatedEnvelope: ValidatedIncomingEnvelope,
        unsealedEnvelope: UnsealedEnvelope?,
        transaction: SDSAnyWriteTransaction
    ) -> Error {
        switch error {
        case SMKSecretSessionCipherError.selfSentMessage:
            // Self-sent messages can be safely discarded. Return as-is.
            return error
        case is SignalError,
            SSKPreKeyStore.Error.noPreKeyWithId(_),
            SSKSignedPreKeyStore.Error.noPreKeyWithId(_),
            SSKKyberPreKeyStore.Error.noKyberPreKeyWithId(_):
            return processError(
                error,
                validatedEnvelope: validatedEnvelope,
                unsealedEnvelope: unsealedEnvelope,
                tx: transaction
            )
        default:
            owsFailDebug("Could not decrypt UD message: \(error), source: \(String(describing: unsealedEnvelope?.sourceAci)), envelope: \(Self.description(for: validatedEnvelope.envelope))")
            return error
        }
    }

    private func processDecryptedEnvelope(
        _ decryptedEnvelope: DecryptedIncomingEnvelope,
        localIdentifiers: LocalIdentifiers,
        mergeRecipient: (DBWriteTransaction) -> SignalRecipient,
        tx: DBWriteTransaction
    ) {
        // We need to handle the PNI signature first b/c `mergeRecipient()`
        // might produce a visible event and the PNI signature won't.
        handlePniSignatureIfNeeded(in: decryptedEnvelope, localIdentifiers: localIdentifiers, tx: tx)

        let recipientManager = DependenciesBridge.shared.recipientManager
        recipientManager.markAsRegisteredAndSave(
            mergeRecipient(tx),
            deviceId: decryptedEnvelope.sourceDeviceId,
            shouldUpdateStorageService: true,
            tx: tx
        )
    }

    private func handlePniSignatureIfNeeded(
        in envelope: DecryptedIncomingEnvelope,
        localIdentifiers: LocalIdentifiers,
        tx: DBWriteTransaction
    ) {
        guard let pniSignatureMessage = envelope.content?.pniSignatureMessage else {
            return
        }
        do {
            try PniSignatureProcessorImpl(
                identityManager: DependenciesBridge.shared.identityManager,
                recipientDatabaseTable: DependenciesBridge.shared.recipientDatabaseTable,
                recipientMerger: DependenciesBridge.shared.recipientMerger
            ).handlePniSignature(
                pniSignatureMessage,
                from: envelope.sourceAci,
                localIdentifiers: localIdentifiers,
                tx: tx
            )
        } catch {
            Logger.warn("Ignoring Pni signature message: \(error)")
        }
    }

    private func schedulePlaceholderCleanupIfNecessary(for placeholder: OWSRecoverableDecryptionPlaceholder) {
        DispatchQueue.main.async {
            self.schedulePlaceholderCleanup(noLaterThan: placeholder.expirationDate)
        }
    }

    private func schedulePlaceholderCleanup(noLaterThan expirationDate: Date) {
        let fireDate = placeholderCleanupTimer?.fireDate ?? .distantFuture
        // Only change the fireDate if it's changed "enough", where we consider
        // about 5 seconds of leeway sufficient.
        let latestAcceptableFireDate = expirationDate.addingTimeInterval(5)

        if latestAcceptableFireDate.isBefore(fireDate) {
            placeholderCleanupTimer = Timer.scheduledTimer(
                withTimeInterval: expirationDate.timeIntervalSinceNow,
                repeats: false,
                block: { [weak self] _ in self?.cleanUpExpiredPlaceholders() }
            )
        }
    }

    func cleanUpExpiredPlaceholders() {
        Task { await self._cleanUpExpiredPlaceholders() }
    }

    private func _cleanUpExpiredPlaceholders() async {
        let (expiredPlaceholderIds, nextExpirationDate) = SSKEnvironment.shared.databaseStorageRef.read { tx in
            var expiredPlaceholderIds = [String]()
            var nextExpirationDate: Date?
            InteractionFinder.enumeratePlaceholders(transaction: tx) { placeholder in
                guard placeholder.expirationDate.isBeforeNow else {
                    nextExpirationDate = [nextExpirationDate, placeholder.expirationDate].compacted().min()
                    return
                }
                expiredPlaceholderIds.append(placeholder.uniqueId)
            }
            return (expiredPlaceholderIds, nextExpirationDate)
        }

        let batchSize = 25
        var remainingPlaceholderIds = expiredPlaceholderIds[...]
        while !remainingPlaceholderIds.isEmpty {
            let thisBatchPlaceholderIds = remainingPlaceholderIds.prefix(batchSize)
            remainingPlaceholderIds = remainingPlaceholderIds.dropFirst(batchSize)

            await SSKEnvironment.shared.databaseStorageRef.awaitableWrite { tx in
                for placeholderId in thisBatchPlaceholderIds {
                    guard let placeholder = OWSRecoverableDecryptionPlaceholder.anyFetchRecoverableDecryptionPlaceholder(
                        uniqueId: placeholderId,
                        transaction: tx
                    ) else {
                        continue
                    }
                    Logger.info("Cleaning up placeholder \(placeholder.timestamp)")
                    DependenciesBridge.shared.interactionDeleteManager
                        .delete(placeholder, sideEffects: .default(), tx: tx.asV2Write)
                    guard let thread = placeholder.thread(tx: tx) else {
                        return
                    }
                    let errorMessage: TSErrorMessage = .failedDecryption(
                        thread: thread,
                        timestamp: MessageTimestampGenerator.sharedInstance.generateTimestamp(),
                        sender: placeholder.sender
                    )
                    errorMessage.anyInsert(transaction: tx)
                    SSKEnvironment.shared.notificationPresenterRef.notifyUser(forErrorMessage: errorMessage, thread: thread, transaction: tx)
                }
            }
        }

        if let nextExpirationDate {
            await MainActor.run { self.schedulePlaceholderCleanup(noLaterThan: nextExpirationDate) }
        }
    }

    // MARK: - OWSMessageHandler methods

    private static func descriptionForEnvelopeType(_ envelope: SSKProtoEnvelope) -> String {
        guard envelope.hasType else {
            return "Missing Type."
        }
        switch envelope.unwrappedType {
        case .unknown:
            // Shouldn't happen
            return "Unknown"
        case .ciphertext:
            return "SignalEncryptedMessage"
        case .keyExchange:
            // Unsupported
            return "KeyExchange"
        case .prekeyBundle:
            return "PreKeyEncryptedMessage"
        case .receipt:
            return "DeliveryReceipt"
        case .unidentifiedSender:
            return "UnidentifiedSender"
        case .senderkeyMessage:
            return "SenderKey"
        case .plaintextContent:
            return "PlaintextContent"
        }
    }

    static func description(for envelope: SSKProtoEnvelope) -> String {
        return "<Envelope type: \(descriptionForEnvelopeType(envelope)), source: \(envelope.formattedAddress), timestamp: \(envelope.timestamp), serverTimestamp: \(envelope.serverTimestamp), serverGuid: \(envelope.serverGuid ?? "(null)"), content.length: \(envelope.content?.count ?? 0) />"
    }
}
