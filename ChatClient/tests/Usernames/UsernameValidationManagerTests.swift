//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import GRDB
import LibSignalClient
import XCTest

@testable import SignalServiceKit

final class UsernameValidationManagerTest: XCTestCase {
    typealias Username = String

    private var mockAccountServiceClient: MockAccountServiceClient!
    private var mockContext: UsernameValidationManagerImpl.Context!
    private var mockDB: (any DB)!
    private var mockLocalUsernameManager: MockLocalUsernameManager!
    private var mockMessageProcessor: MockMessageProcessor!
    private var mockScheduler: TestScheduler!
    private var mockStorageServiceManager: MockStorageServiceManager!
    private var mockUsernameLinkManager: MockUsernameLinkManager!

    private var validationManager: UsernameValidationManagerImpl!

    override func setUp() {
        mockAccountServiceClient = MockAccountServiceClient()
        mockDB = InMemoryDB()
        mockLocalUsernameManager = MockLocalUsernameManager()
        mockMessageProcessor = MockMessageProcessor()
        mockScheduler = TestScheduler()
        mockStorageServiceManager = MockStorageServiceManager()
        mockUsernameLinkManager = MockUsernameLinkManager()

        validationManager = UsernameValidationManagerImpl(context: .init(
            accountServiceClient: mockAccountServiceClient,
            database: mockDB,
            localUsernameManager: mockLocalUsernameManager,
            messageProcessor: mockMessageProcessor,
            schedulers: TestSchedulers(scheduler: mockScheduler),
            storageServiceManager: mockStorageServiceManager,
            usernameLinkManager: mockUsernameLinkManager
        ))
    }

    override func tearDown() {
        mockAccountServiceClient.whoamiResponse.ensureUnset()
        mockMessageProcessor.processingResult.ensureUnset()
        mockStorageServiceManager.pendingRestoreResult.ensureUnset()
        mockUsernameLinkManager.decryptLinkResult.ensureUnset()
    }

    private func runRunRun() {
        mockDB.read { tx in
            validationManager.validateUsernameIfNecessary(tx)
        }

        mockScheduler.runUntilIdle()
    }

    func testUnsetValidationSuccessful() {
        mockLocalUsernameManager.startingUsernameState = .unset
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.noRemoteUsername)

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testUnsetValidationFailsIfWhoamiFails() {
        mockLocalUsernameManager.startingUsernameState = .unset
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .error()

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testUnsetValidationFailsIfRemoteUsernamePresent() {
        mockLocalUsernameManager.startingUsernameState = .unset
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.42"))

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertTrue(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testAvailableValidationSuccessful() {
        mockLocalUsernameManager.startingUsernameState = .available(
            username: "boba_fett.42",
            usernameLink: .mocked
        )
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.42"))
        mockUsernameLinkManager.decryptLinkResult = .value("boba_fett.42")

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testAvailableValidationFailsIfWhoamiFails() {
        mockLocalUsernameManager.startingUsernameState = .available(
            username: "boba_fett.42",
            usernameLink: .mocked
        )
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .error()

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testAvailableValidationFailsIfRemoteUsernameMismatch() {
        mockLocalUsernameManager.startingUsernameState = .available(
            username: "boba_fett.42",
            usernameLink: .mocked
        )
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.43"))

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertTrue(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testAvailableValidationFailsIfLinkDecryptFails() {
        mockLocalUsernameManager.startingUsernameState = .available(
            username: "boba_fett.42",
            usernameLink: .mocked
        )
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.42"))
        mockUsernameLinkManager.decryptLinkResult = .error()

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testAvailableValidationFailsIfUsernameLinkMismatch() {
        mockLocalUsernameManager.startingUsernameState = .available(
            username: "boba_fett.42",
            usernameLink: .mocked
        )
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.42"))
        mockUsernameLinkManager.decryptLinkResult = .value("boba_fett.43")

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertTrue(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testLinkCorruptedValidationSuccessful() {
        mockLocalUsernameManager.startingUsernameState = .linkCorrupted(username: "boba_fett.42")
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.42"))

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testLinkCorruptedValidationFailsIfWhoamiFails() {
        mockLocalUsernameManager.startingUsernameState = .linkCorrupted(username: "boba_fett.42")
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .error()

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testLinkCorruptedValidationFailsIfRemoteUsernameMismatch() {
        mockLocalUsernameManager.startingUsernameState = .linkCorrupted(username: "boba_fett.42")
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())
        mockAccountServiceClient.whoamiResponse = .value(.withRemoteUsername("boba_fett.43"))

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertTrue(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testUsernameCorruptedValidationSuccessful() {
        mockLocalUsernameManager.startingUsernameState = .usernameAndLinkCorrupted
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testValidationFailsIfStorageServiceRestoreFails() {
        mockLocalUsernameManager.startingUsernameState = .usernameAndLinkCorrupted
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .error()

        runRunRun()

        mockDB.read { tx in
            XCTAssertNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testValidationSkippedIfValidatedRecently() {
        mockDB.write { tx in
            validationManager.setLastValidation(
                date: Date().addingTimeInterval(-100),
                tx
            )
        }

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }

    func testValidationFiresIfValidatedAWhileAgo() {
        mockDB.write { tx in
            validationManager.setLastValidation(
                date: Date().addingTimeInterval(-kDayInterval).addingTimeInterval(-1),
                tx
            )
        }

        mockLocalUsernameManager.startingUsernameState = .usernameAndLinkCorrupted
        mockMessageProcessor.processingResult = .value(())
        mockStorageServiceManager.pendingRestoreResult = .value(())

        runRunRun()

        mockDB.read { tx in
            XCTAssertNotNil(validationManager.lastValidationDate(tx))
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedUsername)
            XCTAssertFalse(mockLocalUsernameManager.didSetCorruptedLink)
        }
    }
}

private extension WhoAmIRequestFactory.Responses.WhoAmI {
    static let noRemoteUsername: Self = .init(
        aci: Aci.randomForTesting(),
        pni: Pni.randomForTesting(),
        e164: E164("+16125550101")!,
        usernameHash: nil
    )

    static func withRemoteUsername(_ remoteUsername: String) -> Self {
        return .init(
            aci: Aci.randomForTesting(),
            pni: Pni.randomForTesting(),
            e164: E164("+16125550101")!,
            usernameHash: try! Usernames.HashedUsername(forUsername: remoteUsername).hashString
        )
    }
}

private extension Usernames.UsernameLink {
    static var mocked: Usernames.UsernameLink {
        return Usernames.UsernameLink(
            handle: UUID(),
            entropy: Data(repeating: 5, count: 32)
        )!
    }
}

// MARK: - Mocks

extension UsernameValidationManagerTest {
    private class MockStorageServiceManager: Usernames.Validation.Shims.StorageServiceManager {
        var pendingRestoreResult: ConsumableMockPromise<Void> = .unset

        public func waitForPendingRestores() -> Promise<Void> {
            return pendingRestoreResult.consumeIntoPromise()
        }
    }

    private class MockMessageProcessor: Usernames.Validation.Shims.MessageProcessor {
        var processingResult: ConsumableMockGuarantee<Void> = .unset

        public func waitForFetchingAndProcessing() -> Guarantee<Void> {
            return processingResult.consumeIntoGuarantee()
        }
    }

    private class MockAccountServiceClient: Usernames.Validation.Shims.AccountServiceClient {
        var whoamiResponse: ConsumableMockPromise<WhoAmIRequestFactory.Responses.WhoAmI> = .unset

        func getAccountWhoAmI() -> Promise<WhoAmIRequestFactory.Responses.WhoAmI> {
            return whoamiResponse.consumeIntoPromise()
        }
    }
}
