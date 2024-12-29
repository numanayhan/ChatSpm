//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "OWSPaymentActivationRequestMessage.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSPaymentActivationRequestMessage

- (instancetype)initWithThread:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction
{
    TSOutgoingMessageBuilder *messageBuilder = [TSOutgoingMessageBuilder outgoingMessageBuilderWithThread:thread];
    return [super initOutgoingMessageWithBuilder:messageBuilder
                            additionalRecipients:@[]
                              explicitRecipients:@[]
                               skippedRecipients:@[]
                                     transaction:transaction];
}

- (nullable SSKProtoDataMessageBuilder *)dataMessageBuilderWithThread:(TSThread *)thread
                                                          transaction:(SDSAnyReadTransaction *)transaction
{
    SSKProtoDataMessageBuilder *builder = [super dataMessageBuilderWithThread:thread transaction:transaction];

    SSKProtoDataMessagePaymentActivationBuilder *activationBuilder = [SSKProtoDataMessagePaymentActivation builder];
    [activationBuilder setType:SSKProtoDataMessagePaymentActivationTypeRequest];
    SSKProtoDataMessagePaymentActivation *activation = [activationBuilder buildInfallibly];

    SSKProtoDataMessagePaymentBuilder *paymentBuilder = [SSKProtoDataMessagePayment builder];
    [paymentBuilder setActivation:activation];
    NSError *error;
    SSKProtoDataMessagePayment *payment = [paymentBuilder buildAndReturnError:&error];
    if (error || !payment) {
        OWSFailDebug(@"could not build protobuf: %@", error);
        return nil;
    }

    [builder setPayment:payment];

    [builder setRequiredProtocolVersion:(uint32_t)SSKProtoDataMessageProtocolVersionPayments];
    return builder;
}

- (SealedSenderContentHint)contentHint
{
    return SealedSenderContentHintImplicit;
}

- (BOOL)hasRenderableContent
{
    return NO;
}

- (BOOL)shouldBeSaved
{
    return NO;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.


// --- CODE GENERATION MARKER

@end

NS_ASSUME_NONNULL_END