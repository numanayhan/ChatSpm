//
// Copyright 2018 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import <SignalServiceKit/OWSReadTracking.h>
#import <SignalServiceKit/TSInteraction.h>

NS_ASSUME_NONNULL_BEGIN

@class AciObjC;
@class TSGroupThread;

/// Represents a group call-related update that lives in chat history.
///
/// Not to be confused with an ``OutgoingGroupCallUpdateMessage``.
@interface OWSGroupCallMessage : TSInteraction

/// The ACI-string of the creator of the call.
/// - Note
/// May be `nil` if we were unable to peek the call.
/// - Note
/// The name contains `Uuid` for SDS compatibility, but this is an ACI.
@property (nonatomic, nullable) NSString *creatorUuid;
@property (nonatomic, readonly, nullable) AciObjC *creatorAci;

/// The ACI-strings of the members of the call.
/// - Note
/// May be empty if we were unable to peek the call.
/// - Note
/// The name contains `Uuid` for SDS compatibility, but these are ACIs.
@property (nonatomic, nullable) NSArray<NSString *> *joinedMemberUuids;
@property (nonatomic, readonly) NSArray<AciObjC *> *joinedMemberAcis;

/// Whether the call has been ended, or is still in-progress.
@property (nonatomic) BOOL hasEnded;

/// Whether this call has been read, or is "unread".
/// - SeeAlso ``OWSReadTracking``
@property (nonatomic, getter=wasRead) BOOL read;

/// This property is deprecated, but remains here to preserve compatibility with
/// legacy data. Specifically, it will only be populated on old messages -
/// recent messages will instead have a corresponding ``CallRecord`` storing a
/// "call ID".
@property (nonatomic, readonly, nullable) NSString *eraId;

- (instancetype)initWithCustomUniqueId:(NSString *)uniqueId
                             timestamp:(uint64_t)timestamp
                   receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                                thread:(TSThread *)thread NS_UNAVAILABLE;
- (instancetype)initWithTimestamp:(uint64_t)timestamp
              receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                           thread:(TSThread *)thread NS_UNAVAILABLE;
- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
           receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                        sortId:(uint64_t)sortId
                     timestamp:(uint64_t)timestamp
                uniqueThreadId:(NSString *)uniqueThreadId NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithJoinedMemberAcis:(NSArray<AciObjC *> *)joinedMemberAcis
                              creatorAci:(nullable AciObjC *)creatorAci
                                  thread:(TSGroupThread *)thread
                         sentAtTimestamp:(uint64_t)sentAtTimestamp NS_DESIGNATED_INITIALIZER;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          sortId:(uint64_t)sortId
                       timestamp:(uint64_t)timestamp
                  uniqueThreadId:(NSString *)uniqueThreadId
                     creatorUuid:(nullable NSString *)creatorUuid
                           eraId:(nullable NSString *)eraId
                        hasEnded:(BOOL)hasEnded
               joinedMemberUuids:(nullable NSArray<NSString *> *)joinedMemberUuids
                            read:(BOOL)read
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:receivedAtTimestamp:sortId:timestamp:uniqueThreadId:creatorUuid:eraId:hasEnded:joinedMemberUuids:read:));

// clang-format on

// --- CODE GENERATION MARKER

@end

NS_ASSUME_NONNULL_END
