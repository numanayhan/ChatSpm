//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient

public struct TSGroupModelBuilder {

    public var groupId: Data?
    public var name: String?
    public var descriptionText: String?
    public var avatarData: Data?
    public var groupMembership = GroupMembership()
    public var groupAccess: GroupAccess?
    public var groupsVersion: GroupsVersion?
    public var groupV2Revision: UInt32 = 0
    public var groupSecretParamsData: Data?
    public var newGroupSeed: NewGroupSeed?
    public var avatarUrlPath: String?
    public var inviteLinkPassword: Data?
    public var isAnnouncementsOnly: Bool = false

    public var isJoinRequestPlaceholder: Bool = false
    public var addedByAddress: SignalServiceAddress?
    public var wasJustMigrated: Bool = false
    public var didJustAddSelfViaGroupLink: Bool = false
    public var droppedMembers = [SignalServiceAddress]()

    public init() {}

    // Convert a group state proto received from the service
    // into a group model.
    private init(groupV2Snapshot: GroupV2Snapshot) throws {
        self.groupId = try groupV2Snapshot.groupSecretParams.getPublicParams().getGroupIdentifier().serialize().asData
        self.name = groupV2Snapshot.title
        self.descriptionText = groupV2Snapshot.descriptionText
        self.avatarData = groupV2Snapshot.avatarData
        self.groupMembership = groupV2Snapshot.groupMembership
        self.groupAccess = groupV2Snapshot.groupAccess
        self.groupsVersion = GroupsVersion.V2
        self.groupV2Revision = groupV2Snapshot.revision
        self.groupSecretParamsData = groupV2Snapshot.groupSecretParams.serialize().asData
        self.avatarUrlPath = groupV2Snapshot.avatarUrlPath
        self.inviteLinkPassword = groupV2Snapshot.inviteLinkPassword
        self.isAnnouncementsOnly = groupV2Snapshot.isAnnouncementsOnly
        self.isJoinRequestPlaceholder = false
        self.wasJustMigrated = false
        self.didJustAddSelfViaGroupLink = false
    }

    static func builderForSnapshot(groupV2Snapshot: GroupV2Snapshot, transaction: SDSAnyWriteTransaction) throws -> TSGroupModelBuilder {
        var builder = try TSGroupModelBuilder(groupV2Snapshot: groupV2Snapshot)

        guard let groupId = builder.groupId else {
            owsFailDebug("Missing groupId.")
            return builder
        }
        guard let oldGroupThread = TSGroupThread.fetch(groupId: groupId, transaction: transaction) else {
            // Group not yet in db.
            return builder
        }
        let oldGroupModel = oldGroupThread.groupModel
        builder.droppedMembers = oldGroupModel.asBuilder.droppedMembers
        return builder
    }

    public mutating func apply(options: TSGroupModelOptions) {
        if options.contains(.didJustAddSelfViaGroupLink) {
            didJustAddSelfViaGroupLink = true
        }
    }

    private func checkUsers() throws {
        let allUsers = groupMembership.allMembersOfAnyKind
        for recipientAddress in allUsers {
            guard recipientAddress.isValid else {
                throw OWSAssertionError("Invalid address.")
            }
        }
    }

    public func buildForMinorChanges() throws -> TSGroupModel {

        try checkUsers()

        guard let groupsVersion = self.groupsVersion else {
            throw OWSAssertionError("Missing groupsVersion.")
        }
        guard let groupId = self.groupId else {
            throw OWSAssertionError("Missing groupId.")
        }

        var groupSecretParams: GroupSecretParams?
        if groupsVersion == .V2 {
            guard let groupSecretParamsData = self.groupSecretParamsData else {
                throw OWSAssertionError("Missing groupSecretParamsData.")
            }
            groupSecretParams = try GroupSecretParams(contents: [UInt8](groupSecretParamsData))
        }

        return try build(
            groupsVersion: groupsVersion,
            groupId: groupId,
            groupSecretParams: groupSecretParams
        )
    }

    public func build() throws -> TSGroupModel {
        try checkUsers()

        let groupsVersion = self.groupsVersion ?? .V2
        let newGroupSeed = self.newGroupSeed ?? NewGroupSeed()

        let groupId: Data
        if let builderValue = self.groupId {
            groupId = builderValue
        } else {
            switch groupsVersion {
            case .V1:
                groupId = newGroupSeed.groupIdV1
            case .V2:
                groupId = newGroupSeed.groupIdV2
            }
        }

        let groupSecretParams: GroupSecretParams?
        switch groupsVersion {
        case .V1:
            groupSecretParams = nil
        case .V2:
            if let builderValue = groupSecretParamsData {
                groupSecretParams = try GroupSecretParams(contents: [UInt8](builderValue))
            } else {
                groupSecretParams = newGroupSeed.groupSecretParams
            }
        }

        return try build(
            groupsVersion: groupsVersion,
            groupId: groupId,
            groupSecretParams: groupSecretParams
        )
    }

    private func build(
        groupsVersion: GroupsVersion,
        groupId: Data,
        groupSecretParams: GroupSecretParams?
    ) throws -> TSGroupModel {

        let allUsers = groupMembership.allMembersOfAnyKind
        for recipientAddress in allUsers {
            guard recipientAddress.isValid else {
                throw OWSAssertionError("Invalid address.")
            }
        }

        var name: String?
        if let strippedName = self.name?.stripped.nilIfEmpty {
            name = strippedName
        }

        guard GroupManager.isValidGroupId(groupId, groupsVersion: groupsVersion) else {
            throw OWSAssertionError("Invalid groupId.")
        }

        switch groupsVersion {
        case .V1:
            if !groupMembership.invitedMembers.isEmpty {
                owsFailDebug("v1 group has pending profile key members.")
            }
            if !groupMembership.requestingMembers.isEmpty {
                owsFailDebug("v1 group has pending request members.")
            }
            owsAssertDebug(!isJoinRequestPlaceholder)
            return TSGroupModel(groupId: groupId,
                                name: name,
                                avatarData: avatarData,
                                members: Array(groupMembership.fullMembers),
                                addedBy: addedByAddress)
        case .V2:
            owsAssertDebug(addedByAddress == nil)

            var descriptionText: String?
            if let strippedDescriptionText = self.descriptionText?.stripped.nilIfEmpty {
                descriptionText = strippedDescriptionText
            }

            let groupAccess = buildGroupAccess(groupsVersion: groupsVersion)
            guard let groupSecretParams = groupSecretParams else {
                throw OWSAssertionError("Missing groupSecretParamsData.")
            }
            // Don't set avatarUrlPath unless we have avatarData.
            let avatarUrlPath = avatarData != nil ? self.avatarUrlPath : nil

            // Update droppedMembers, removing any current members.
            let droppedMembers = Array(Set(self.droppedMembers).subtracting(groupMembership.allMembersOfAnyKind))
            return TSGroupModelV2(
                groupId: groupId,
                name: name,
                descriptionText: descriptionText,
                avatarData: avatarData,
                groupMembership: groupMembership,
                groupAccess: groupAccess,
                revision: groupV2Revision,
                secretParamsData: groupSecretParams.serialize().asData,
                avatarUrlPath: avatarUrlPath,
                inviteLinkPassword: inviteLinkPassword,
                isAnnouncementsOnly: isAnnouncementsOnly,
                isJoinRequestPlaceholder: isJoinRequestPlaceholder,
                wasJustMigrated: wasJustMigrated,
                didJustAddSelfViaGroupLink: didJustAddSelfViaGroupLink,
                addedByAddress: addedByAddress,
                droppedMembers: droppedMembers
            )
        }
    }

    public func buildAsV2() throws -> TSGroupModelV2 {
        guard let model = try build() as? TSGroupModelV2 else {
            throw OWSAssertionError("[GV1] Should be impossible to create a V1 group!")
        }
        return model
    }

    private func buildGroupAccess(groupsVersion: GroupsVersion) -> GroupAccess {
        if let value = groupAccess {
            return value
        }

        switch groupsVersion {
        case .V1:
            return GroupAccess.defaultForV1
        case .V2:
            return GroupAccess.defaultForV2
        }
    }
}

// MARK: -

public extension TSGroupModel {
    var asBuilder: TSGroupModelBuilder {
        var builder = TSGroupModelBuilder()
        builder.groupId = self.groupId
        builder.name = self.groupName
        builder.avatarData = self.avatarData
        builder.groupMembership = self.groupMembership
        builder.groupsVersion = self.groupsVersion
        builder.addedByAddress = self.addedByAddress

        if let v2 = self as? TSGroupModelV2 {
            builder.groupAccess = v2.access
            builder.groupV2Revision = v2.revision
            builder.groupSecretParamsData = v2.secretParamsData
            builder.avatarUrlPath = v2.avatarUrlPath
            builder.inviteLinkPassword = v2.inviteLinkPassword
            builder.isAnnouncementsOnly = v2.isAnnouncementsOnly
            builder.droppedMembers = v2.droppedMembers
            builder.descriptionText = v2.descriptionText

            // Do not copy transient properties:
            //
            // * isJoinRequestPlaceholder
            // * wasJustMigrated
            // * didJustAddSelfViaGroupLink
            //
            // We want to discard these values when updating group models.
        }

        return builder
    }
}

// MARK: -

public struct TSGroupModelOptions: OptionSet {
    public let rawValue: Int
    public static let didJustAddSelfViaGroupLink  = TSGroupModelOptions(rawValue: 1 << 0)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
