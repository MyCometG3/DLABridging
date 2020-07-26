//
//  DLABAudioSetting.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABAudioSetting+Internal.h"

@implementation DLABAudioSetting

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithSampleType:channelCount:sampleRate:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
    return nil;
}

- (instancetype) initWithSampleType:(DLABAudioSampleType)sampleType
                       channelCount:(uint32_t)channelCount
                         sampleRate:(DLABAudioSampleRate)sampleRate
{
    NSParameterAssert(sampleType && channelCount && sampleRate);
    
    self = [super init];
    if (self) {
        _sampleSize = (sampleType / 8) * channelCount;
        _sampleType = sampleType;
        _channelCount = channelCount;
        _sampleRate = sampleRate;
    }
    return self;
}

- (void) dealloc
{
    if (_audioFormatDescriptionW) {
        CFRelease(_audioFormatDescriptionW);
    }
}

// public hash - NSObject
- (NSUInteger) hash
{
    NSUInteger value = (NSUInteger)(_sampleSize^_channelCount^_sampleType^_sampleRate);
    return value;
}

// public comparison - NSObject
- (BOOL) isEqual:(id)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    return [self isEqualToAudioSetting:(DLABAudioSetting*)object];
}

// private comparison - DLABAudioSetting
- (BOOL) isEqualToAudioSetting:(DLABAudioSetting*)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    if (!( self.sampleSize == object.sampleSize )) return NO;
    if (!( self.channelCount == object.channelCount )) return NO;
    if (!( self.sampleType == object.sampleType )) return NO;
    if (!( self.sampleRate == object.sampleRate )) return NO;
    
    // ignore: audioFormatDescription
    
    return YES;
}

// NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone
{
    DLABAudioSetting* obj = [[DLABAudioSetting alloc] initWithSampleType:self.sampleType
                                                            channelCount:self.channelCount
                                                              sampleRate:self.sampleRate];
    if (obj && self.audioFormatDescription != nil) {
        [obj buildAudioFormatDescriptionWithError:nil];
    }
    return obj;
}

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

- (BOOL) post:(NSString*)description
       reason:(NSString*)failureReason
         code:(NSInteger)result
           to:(NSError**)error;
{
    if (error) {
        if (!description) description = @"unknown description";
        if (!failureReason) failureReason = @"unknown failureReason";
        
        NSString *domain = @"com.MyCometG3.DLABridging.ErrorDomain";
        NSInteger code = (NSInteger)result;
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description,
                                   NSLocalizedFailureReasonErrorKey : failureReason,};
        *error = [NSError errorWithDomain:domain code:code userInfo:userInfo];
        return YES;
    }
    return NO;
}

/* =================================================================================== */
// MARK: - private accessors
/* =================================================================================== */

@synthesize audioFormatDescriptionW = _audioFormatDescriptionW;

// private setter for audioFormatDescription
- (void)setAudioFormatDescriptionW:(CMAudioFormatDescriptionRef)newFormatDescription
{
    if (_audioFormatDescriptionW == newFormatDescription) return;
    if (_audioFormatDescriptionW) {
        CFRelease(_audioFormatDescriptionW);
        _audioFormatDescriptionW = NULL;
    }
    if (newFormatDescription) {
        CFRetain(newFormatDescription);
        _audioFormatDescriptionW = newFormatDescription;
    }
}

/* =================================================================================== */
// MARK: - public accessors
/* =================================================================================== */

@synthesize sampleSize = _sampleSize;
@synthesize channelCount = _channelCount;
@synthesize sampleType = _sampleType;
@synthesize sampleRate = _sampleRate;
@dynamic audioFormatDescription;

// implementation
- (CMAudioFormatDescriptionRef) audioFormatDescription { return _audioFormatDescriptionW; }

/* =================================================================================== */
// MARK: - Public methods
/* =================================================================================== */

- (BOOL) buildAudioFormatDescriptionWithError:(NSError**)error
{
    CMAudioFormatDescriptionRef formatDescription = NULL;
    {
        // check parameters
        uint32_t sampleSize = self.sampleSize;
        uint32_t channelCount = self.channelCount;
        DLABAudioSampleType sampleType = self.sampleType;
        DLABAudioSampleRate sampleRate = self.sampleRate;
        
        BOOL ready = (sampleSize && sampleType && channelCount && sampleRate);
        if (!ready) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported settings detected."
                  code:E_INVALIDARG
                    to:error];
        }
        
        if (ready) {
            // ASBD
            AudioStreamBasicDescription streamBasicDescription = {
                static_cast<Float64>(sampleRate),   //mSampleRate
                kAudioFormatLinearPCM,              //mFormatID
                kAudioFormatFlagIsSignedInteger,    //mFormatFlags
                sampleSize,                         //mBytesPerPacket
                1,                                  //mFramesPerPacket
                sampleSize,                         //mBytesPerFrame
                channelCount,                       //mChannelsPerFrame
                sampleType,                         //mBitsPerChannel
                0                                   //mReserved
            };
            
            // channel layout
            AudioChannelLayout channelLayout = { 0 };
            NSString* layoutString = nil;
            if (channelCount == 1) {
                channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
                layoutString = @"Monaural";
            } else if (channelCount == 2) {
                channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
                layoutString = @"Stereo";
            } else {
                // 8 ch or 16 ch audio is tagged as discrete
                uint32_t audioChannelLayoutTag = (kAudioChannelLayoutTag_DiscreteInOrder | channelCount);
                channelLayout = { audioChannelLayoutTag, 0 };
                layoutString = [NSString stringWithFormat:@"Discrete-%dch", channelCount];
            }
            
            // format name
            NSString* keyName = (__bridge NSString*)kCMFormatDescriptionExtension_FormatName;
            NSString* rateString = (sampleRate == DLABAudioSampleRate48kHz ? @"48,000" : @"??.???");
            NSString* name = [NSString stringWithFormat:@"%@ Hz, %d-bit, %@",
                              rateString, sampleType, layoutString];
            NSDictionary *extensions = @{keyName : name};
            
            // create format description
            OSStatus err = noErr;
            err = CMAudioFormatDescriptionCreate(NULL,          //allocator
                                                 &streamBasicDescription,
                                                 sizeof(channelLayout),
                                                 &channelLayout,
                                                 0,             //magicCookieSize
                                                 NULL,          //magicCookie
                                                 (__bridge CFDictionaryRef)extensions,
                                                 &formatDescription);
            if (!err && formatDescription) {
                self.audioFormatDescriptionW = formatDescription;
                CFRelease(formatDescription);
                return TRUE;
            } else {
                [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                    reason:@"Failed to create CMAudioFormatDescription."
                      code:E_INVALIDARG
                        to:error];
            }
        }
    }
    return FALSE;
}

@end
