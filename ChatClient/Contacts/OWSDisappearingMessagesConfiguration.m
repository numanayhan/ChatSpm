//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "OWSDisappearingMessagesConfiguration.h"
#import <SignalServiceKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSDisappearingMessagesConfiguration ()

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) uint32_t durationSeconds;
@property (nonatomic) uint32_t timerVersion;

@end

#pragma mark -

@implementation OWSDisappearingMessagesConfiguration

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    return self;
}

- (instancetype)initWithThreadId:(NSString *)threadId
                         enabled:(BOOL)isEnabled
                 durationSeconds:(uint32_t)seconds
                    timerVersion:(uint32_t)timerVersion
{
    OWSAssertDebug(threadId.length > 0);

    // Thread id == configuration id.
    self = [super initWithUniqueId:threadId];
    if (!self) {
        return self;
    }

    _enabled = isEnabled;
    _durationSeconds = seconds;
    _timerVersion = timerVersion;

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
                 durationSeconds:(unsigned int)durationSeconds
                         enabled:(BOOL)enabled
                    timerVersion:(unsigned int)timerVersion
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _durationSeconds = durationSeconds;
    _enabled = enabled;
    _timerVersion = timerVersion;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

+ (NSArray<NSNumber *> *)presetDurationsSeconds
{
    return @[
        @(30 * kSecondInterval),
        @(5 * kMinuteInterval),
        @(1 * kHourInterval),
        @(8 * kHourInterval),
        @(24 * kHourInterval),
        @(1 * kWeekInterval),
        @(4 * kWeekInterval)
    ];
}

+ (uint32_t)maxDurationSeconds
{
    return (uint32_t)kYearInterval;
}

- (NSString *)durationString
{
    return [NSString formatDurationLosslessWithDurationSeconds:self.durationSeconds];
}

- (instancetype)copyWithIsEnabled:(BOOL)isEnabled timerVersion:(uint32_t)timerVersion
{
    OWSDisappearingMessagesConfiguration *newInstance = [self copy];
    newInstance.enabled = isEnabled;
    newInstance.timerVersion = timerVersion;
    if (!isEnabled) {
        newInstance.durationSeconds = 0;
    }
    return newInstance;
}

- (instancetype)copyWithDurationSeconds:(uint32_t)durationSeconds timerVersion:(uint32_t)timerVersion
{
    OWSDisappearingMessagesConfiguration *newInstance = [self copy];
    newInstance.durationSeconds = durationSeconds;
    newInstance.timerVersion = timerVersion;
    return newInstance;
}

- (instancetype)copyAsEnabledWithDurationSeconds:(uint32_t)durationSeconds timerVersion:(uint32_t)timerVersion
{
    OWSDisappearingMessagesConfiguration *newInstance = [self copy];
    newInstance.enabled = YES;
    newInstance.durationSeconds = durationSeconds;
    newInstance.timerVersion = timerVersion;
    return newInstance;
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass:[OWSDisappearingMessagesConfiguration class]]) {
        return NO;
    }

    OWSDisappearingMessagesConfiguration *otherConfiguration = (OWSDisappearingMessagesConfiguration *)other;
    if (otherConfiguration.isEnabled != self.isEnabled) {
        return NO;
    }
    if (!self.isEnabled) {
        // Don't bother comparing durationSeconds if not enabled.
        return YES;
    }
    return otherConfiguration.durationSeconds == self.durationSeconds
        && otherConfiguration.timerVersion == self.timerVersion;
}

@end

NS_ASSUME_NONNULL_END
