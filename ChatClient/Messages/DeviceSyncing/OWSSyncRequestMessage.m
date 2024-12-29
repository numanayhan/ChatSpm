//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "OWSSyncRequestMessage.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSSyncRequestMessage ()
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;


/// This property represents a ``SSKProtoSyncMessageRequestType`` case.
///
/// Since that enum has had cases removed that may have been persisted - which
/// will crash when we try to unwrap the raw value into an actual enum case - we
/// store the weakly-typed raw value and manually convert it to an enum case
/// when we use it.
@property (nonatomic, readonly) int32_t requestType;

@end

@implementation OWSSyncRequestMessage

- (instancetype)initWithThread:(TSThread *)thread
                   requestType:(int32_t)requestType
                   transaction:(SDSAnyReadTransaction *)transaction
{
    self = [super initWithThread:thread transaction:transaction];

    _requestType = requestType;

    return self;
}

- (nullable SSKProtoSyncMessageBuilder *)syncMessageBuilderWithTransaction:(SDSAnyReadTransaction *)transaction
{
    SSKProtoSyncMessageRequestBuilder *requestBuilder = [SSKProtoSyncMessageRequest builder];

    SSKProtoSyncMessageRequestType requestType = [self requestTypeWithRawValue:self.requestType];

    switch (requestType) {
        case SSKProtoSyncMessageRequestTypeUnknown:
            OWSLogWarn(@"Found unexpectedly unknown request type %d - bailing.", requestType);
            return nil;
        default:
            requestBuilder.type = requestType;
    }

    SSKProtoSyncMessageBuilder *builder = [SSKProtoSyncMessage builder];
    builder.request = [requestBuilder buildInfallibly];
    return builder;
}

- (SealedSenderContentHint)contentHint
{
    return SealedSenderContentHintImplicit;
}

@end

NS_ASSUME_NONNULL_END
