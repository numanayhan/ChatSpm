//
// Copyright 2022 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import GRDB
import LibSignalClient
import XCTest

@testable import SignalServiceKit

class OWSRecipientIdentityTest: SSKBaseTest {
    private lazy var localAci = Aci.randomForTesting()
    private lazy var aliceAci = Aci.randomForTesting()
    private lazy var bobAci = Aci.randomForTesting()
    private lazy var charlieAci = Aci.randomForTesting()
    private var recipients: [ServiceId] {
        [aliceAci, bobAci, charlieAci, localAci]
    }
    private var groupThread: TSGroupThread!
    private var identityKeys = [ServiceId: Data]()

    private func identityKey(_ serviceId: ServiceId) -> Data {
        if let value = identityKeys[serviceId] {
            return value
        }
        let data = ECKeyPair.generateKeyPair().publicKey
        identityKeys[serviceId] = data
        return data
    }

    private func createFakeGroup() throws {
        // Create local account.
        SSKEnvironment.shared.databaseStorageRef.write { tx in
            (DependenciesBridge.shared.registrationStateChangeManager as! RegistrationStateChangeManagerImpl).registerForTests(
                localIdentifiers: .init(
                    aci: localAci,
                    pni: Pni.randomForTesting(),
                    e164: E164("+16505550100")!
                ),
                tx: tx.asV2Write
            )
        }
        // Create recipients & identities for them.
        write { tx in
            let recipientFetcher = DependenciesBridge.shared.recipientFetcher
            let recipientManager = DependenciesBridge.shared.recipientManager
            for serviceId in recipients {
                let recipient = recipientFetcher.fetchOrCreate(serviceId: serviceId, tx: tx.asV2Write)
                recipientManager.markAsRegisteredAndSave(recipient, shouldUpdateStorageService: false, tx: tx.asV2Write)
                identityManager.saveIdentityKey(identityKey(serviceId), for: serviceId, tx: tx.asV2Write)
            }

            // Create a group with our recipients plus us.
            self.groupThread = try! GroupManager.createGroupForTests(
                members: recipients.map { SignalServiceAddress($0) },
                name: "Test Group",
                avatarData: nil,
                transaction: tx
            )
        }
    }

    private var identityManager: OWSIdentityManager { DependenciesBridge.shared.identityManager }

    override func setUp() {
        super.setUp()
        try! createFakeGroup()
    }

    func testNoneVerified() throws {
        read { tx in
            XCTAssertTrue(identityManager.groupContainsUnverifiedMember(groupThread.uniqueId, tx: tx.asV2Read))
        }
    }

    func testAllVerified() throws {
        for recipient in recipients {
            write { tx in
                _ = identityManager.setVerificationState(
                    .verified,
                    of: identityKey(recipient),
                    for: SignalServiceAddress(recipient),
                    isUserInitiatedChange: true,
                    tx: tx.asV2Write
                )
            }
        }
        read { tx in
            XCTAssertFalse(identityManager.groupContainsUnverifiedMember(groupThread.uniqueId, tx: tx.asV2Read))
        }
    }

    func testSomeVerified() throws {
        let recipient = recipients[0]
        write { tx in
            _ = identityManager.setVerificationState(
                .verified,
                of: identityKey(recipient),
                for: SignalServiceAddress(recipient),
                isUserInitiatedChange: true,
                tx: tx.asV2Write
            )
        }
        read { tx in
            XCTAssertTrue(identityManager.groupContainsUnverifiedMember(groupThread.uniqueId, tx: tx.asV2Read))
        }
    }

    func testSomeNoLongerVerified() throws {
        // Verify everyone
        for recipient in recipients {
            write { tx in
                _ = identityManager.setVerificationState(
                    .verified,
                    of: identityKey(recipient),
                    for: SignalServiceAddress(recipient),
                    isUserInitiatedChange: true,
                    tx: tx.asV2Write
                )
            }
        }
        // Make Alice and Bob no-longer-verified.
        let deverifiedAcis = [aliceAci, bobAci]
        for recipient in deverifiedAcis {
            write { tx in
                _ = identityManager.setVerificationState(
                    .noLongerVerified,
                    of: identityKey(recipient),
                    for: SignalServiceAddress(recipient),
                    isUserInitiatedChange: false,
                    tx: tx.asV2Write
                )
            }
        }
        read { tx in
            XCTAssertTrue(identityManager.groupContainsUnverifiedMember(groupThread.uniqueId, tx: tx.asV2Read))
        }

        // Check that the list of no-longer-verified addresses is just Alice and Bob.
        read { transaction in
            let noLongerVerifiedIdentityKeys = OWSRecipientIdentity.noLongerVerifiedIdentityKeys(
                in: self.groupThread.uniqueId,
                tx: transaction
            )
            XCTAssertEqual(Set(noLongerVerifiedIdentityKeys.keys), Set(deverifiedAcis.map { SignalServiceAddress($0) }))
        }
    }

    func testLocalAddressIgnoredForVerifiedCheck() {
        // Verify everyone except me.
        for recipient in recipients {
            if recipient == localAci {
                continue
            }
            write { tx in
                _ = identityManager.setVerificationState(
                    .verified,
                    of: identityKey(recipient),
                    for: SignalServiceAddress(recipient),
                    isUserInitiatedChange: true,
                    tx: tx.asV2Write
                )
            }
        }
        read { tx in
            XCTAssertFalse(identityManager.groupContainsUnverifiedMember(groupThread.uniqueId, tx: tx.asV2Read))
        }
    }
}
