//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "OWSSyncMessageRequestResponseMessage.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSSyncMessageRequestResponseMessage ()

@property (nonatomic, readonly) OWSSyncMessageRequestResponseType responseType;

@end

#pragma mark -

@implementation OWSSyncMessageRequestResponseMessage

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (instancetype)initWithThread:(TSThread *)thread
                  responseType:(OWSSyncMessageRequestResponseType)responseType
                   transaction:(SDSAnyReadTransaction *)transaction
{
    self = [super initWithThread:thread transaction:transaction];

    _responseType = responseType;

    return self;
}

- (SSKProtoSyncMessageMessageRequestResponseType)protoResponseType
{
    switch (self.responseType) {
        case OWSSyncMessageRequestResponseType_Accept:
            return SSKProtoSyncMessageMessageRequestResponseTypeAccept;
        case OWSSyncMessageRequestResponseType_Delete:
            return SSKProtoSyncMessageMessageRequestResponseTypeDelete;
        case OWSSyncMessageRequestResponseType_Block:
            return SSKProtoSyncMessageMessageRequestResponseTypeBlock;
        case OWSSyncMessageRequestResponseType_BlockAndDelete:
            return SSKProtoSyncMessageMessageRequestResponseTypeBlockAndDelete;
        case OWSSyncMessageRequestResponseType_Spam:
            return SSKProtoSyncMessageMessageRequestResponseTypeSpam;
        case OWSSyncMessageRequestResponseType_BlockAndSpam:
            return SSKProtoSyncMessageMessageRequestResponseTypeBlockAndSpam;
    }
}

- (nullable SSKProtoSyncMessageBuilder *)syncMessageBuilderWithTransaction:(SDSAnyReadTransaction *)transaction
{
    SSKProtoSyncMessageMessageRequestResponseBuilder *messageRequestResponseBuilder =
        [SSKProtoSyncMessageMessageRequestResponse builder];
    messageRequestResponseBuilder.type = self.protoResponseType;

    TSThread *_Nullable thread = [self threadWithTx:transaction];
    if (!thread) {
        OWSFailDebug(@"Missing thread for message request response");
        return nil;
    }

    if (thread.isGroupThread) {
        OWSAssertDebug([thread isKindOfClass:[TSGroupThread class]]);
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        messageRequestResponseBuilder.groupID = groupThread.groupModel.groupId;
    } else {
        OWSAssertDebug([thread isKindOfClass:[TSContactThread class]]);
        TSContactThread *contactThread = (TSContactThread *)thread;
        messageRequestResponseBuilder.threadAci = contactThread.contactAddress.aciString;
    }

    SSKProtoSyncMessageBuilder *builder = [SSKProtoSyncMessage builder];
    builder.messageRequestResponse = [messageRequestResponseBuilder buildInfallibly];
    return builder;
}

- (BOOL)isUrgent
{
    return NO;
}

@end

NS_ASSUME_NONNULL_END
