//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import <SignalServiceKit/BaseModel.h>

NS_ASSUME_NONNULL_BEGIN

@class GRDBReadTransaction;
@class MessageBody;
@class MessageBodyRanges;
@class OWSDisappearingMessagesConfiguration;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class SignalServiceAddress;
@class TSInteraction;
@class TSInvalidIdentityKeyReceivingErrorMessage;
@class ThreadReplyInfoObjC;

typedef NS_CLOSED_ENUM(NSUInteger, TSThreadMentionNotificationMode) {
    TSThreadMentionNotificationMode_Default = 0,
    TSThreadMentionNotificationMode_Always,
    TSThreadMentionNotificationMode_Never
};

typedef NS_CLOSED_ENUM(NSUInteger, TSThreadStoryViewMode) {
    TSThreadStoryViewMode_Default = 0,
    TSThreadStoryViewMode_Explicit,
    TSThreadStoryViewMode_BlockList,
    TSThreadStoryViewMode_Disabled
};

/**
 *  TSThread is the superclass of TSContactThread, TSGroupThread, and TSPrivateStoryThread
 */
@interface TSThread : BaseModel

@property (nonatomic) TSThreadStoryViewMode storyViewMode;
@property (nonatomic, nullable) NSNumber *lastSentStoryTimestamp;

@property (nonatomic) BOOL shouldThreadBeVisible;
@property (nonatomic, readonly, nullable) NSDate *creationDate;
@property (nonatomic, readonly) BOOL isArchivedByLegacyTimestampForSorting DEPRECATED_MSG_ATTRIBUTE(
    "this property is only to be used in the sortId migration");
@property (nonatomic, readonly) BOOL isArchivedObsolete;
@property (nonatomic, readonly) BOOL isMarkedUnreadObsolete;

// This maintains the row Id that was at the bottom of the conversation
// the last time the user viewed this thread so we can restore their
// scroll position.
//
// If the referenced message is deleted, this value is
// updated to point to the previous message in the conversation.
//
// If a new message is inserted into the conversation, this value
// is cleared. We only restore this state if there are no unread messages.
@property (nonatomic, readonly) uint64_t lastVisibleSortIdObsolete;
@property (nonatomic, readonly) double lastVisibleSortIdOnScreenPercentageObsolete;

@property (nonatomic, copy, nullable) NSString *messageDraft;
@property (nonatomic, nullable) MessageBodyRanges *messageDraftBodyRanges;

// zero if thread has never had an interaction.
// The corresponding interaction may have been deleted.
@property (nonatomic) uint64_t lastInteractionRowId;

@property (nonatomic, nullable) NSNumber *editTargetTimestamp;

@property (atomic, readonly) uint64_t mutedUntilTimestampObsolete;
@property (nonatomic, readonly, nullable) NSDate *mutedUntilDateObsolete;

@property (nonatomic) TSThreadMentionNotificationMode mentionNotificationMode;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithUniqueId:(NSString *)uniqueId NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithGrdbId:(int64_t)grdbId uniqueId:(NSString *)uniqueId NS_UNAVAILABLE;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
   conversationColorNameObsolete:(NSString *)conversationColorNameObsolete
                    creationDate:(nullable NSDate *)creationDate
             editTargetTimestamp:(nullable NSNumber *)editTargetTimestamp
              isArchivedObsolete:(BOOL)isArchivedObsolete
          isMarkedUnreadObsolete:(BOOL)isMarkedUnreadObsolete
            lastInteractionRowId:(uint64_t)lastInteractionRowId
          lastSentStoryTimestamp:(nullable NSNumber *)lastSentStoryTimestamp
       lastVisibleSortIdObsolete:(uint64_t)lastVisibleSortIdObsolete
lastVisibleSortIdOnScreenPercentageObsolete:(double)lastVisibleSortIdOnScreenPercentageObsolete
         mentionNotificationMode:(TSThreadMentionNotificationMode)mentionNotificationMode
                    messageDraft:(nullable NSString *)messageDraft
          messageDraftBodyRanges:(nullable MessageBodyRanges *)messageDraftBodyRanges
          mutedUntilDateObsolete:(nullable NSDate *)mutedUntilDateObsolete
     mutedUntilTimestampObsolete:(uint64_t)mutedUntilTimestampObsolete
           shouldThreadBeVisible:(BOOL)shouldThreadBeVisible
                   storyViewMode:(TSThreadStoryViewMode)storyViewMode
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:conversationColorNameObsolete:creationDate:editTargetTimestamp:isArchivedObsolete:isMarkedUnreadObsolete:lastInteractionRowId:lastSentStoryTimestamp:lastVisibleSortIdObsolete:lastVisibleSortIdOnScreenPercentageObsolete:mentionNotificationMode:messageDraft:messageDraftBodyRanges:mutedUntilDateObsolete:mutedUntilTimestampObsolete:shouldThreadBeVisible:storyViewMode:));

// clang-format on

// --- CODE GENERATION MARKER

@property (nonatomic, readonly) NSString *conversationColorNameObsolete;

/**
 * @returns recipientId for each recipient in the thread
 */

@property (nonatomic, readonly) NSArray<SignalServiceAddress *> *recipientAddressesWithSneakyTransaction;
- (NSArray<SignalServiceAddress *> *)recipientAddressesWithTransaction:(SDSAnyReadTransaction *)transaction;

@property (nonatomic, readonly) BOOL isNoteToSelf;

#pragma mark Interactions

/**
 * Get all messages in the thread we weren't able to decrypt
 */
- (NSArray<TSInvalidIdentityKeyReceivingErrorMessage *> *)receivedMessagesForInvalidKey:(NSData *)key
                                                                                     tx:(SDSAnyReadTransaction *)tx;

- (BOOL)hasSafetyNumbers;

- (nullable TSInteraction *)lastInteractionForInboxWithTransaction:(SDSAnyReadTransaction *)transaction
    NS_SWIFT_NAME(lastInteractionForInbox(transaction:));

- (nullable TSInteraction *)firstInteractionAtOrAroundSortId:(uint64_t)sortId
                                                 transaction:(SDSAnyReadTransaction *)transaction
    NS_SWIFT_NAME(firstInteraction(atOrAroundSortId:transaction:));

/**
 *  Updates the thread's caches of the latest interaction.
 *
 *  @param message Latest Interaction to take into consideration.
 *  @param transaction Database transaction.
 */
- (void)updateWithInsertedMessage:(TSInteraction *)message transaction:(SDSAnyWriteTransaction *)transaction;
- (void)updateWithUpdatedMessage:(TSInteraction *)message transaction:(SDSAnyWriteTransaction *)transaction;
- (void)updateWithRemovedMessage:(TSInteraction *)message transaction:(SDSAnyWriteTransaction *)transaction;

- (void)updateOnInteractionsRemovedWithNeedsToUpdateLastInteractionRowId:(BOOL)needsToUpdateLastInteractionRowId
                                          needsToUpdateLastVisibleSortId:(BOOL)needsToUpdateLastVisibleSortId
                                                             transaction:(SDSAnyWriteTransaction *)transaction
    NS_SWIFT_NAME(updateOnInteractionsRemoved(needsToUpdateLastInteractionRowId:needsToUpdateLastVisibleSortId:transaction:));

#pragma mark - Merging

- (void)mergeFrom:(TSThread *)otherThread;

@end

NS_ASSUME_NONNULL_END
