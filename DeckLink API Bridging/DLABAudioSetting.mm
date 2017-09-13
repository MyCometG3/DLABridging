//
//  DLABAudioSetting.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
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
        _sampleSizeW = (sampleType / 8) * channelCount;
        _sampleTypeW = sampleType;
        _channelCountW = channelCount;
        _sampleRateW = sampleRate;
    }
    return self;
}

- (void) dealloc
{
    if (_audioFormatDescriptionW) {
        CFRelease(_audioFormatDescriptionW);
        _audioFormatDescriptionW = NULL;
    }
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
    
    if (!( self.sampleSizeW == object.sampleSizeW )) return NO;
    if (!( self.channelCountW == object.channelCountW )) return NO;
    if (!( self.sampleTypeW == object.sampleTypeW )) return NO;
    if (!( self.sampleRateW == object.sampleRateW )) return NO;
    
    if (!CFEqual(self.audioFormatDescriptionW, object.audioFormatDescriptionW)) return NO;
    
    return YES;
}

// NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone
{
    DLABAudioSetting* obj = [[DLABAudioSetting alloc] initWithSampleType:self.sampleTypeW
                                                            channelCount:self.channelCountW
                                                              sampleRate:self.sampleRateW];
    if (obj && _audioFormatDescriptionW != nil) {
        [obj buildAudioFormatDescription];
    }
    return obj;
}

/* =================================================================================== */
// MARK: - synthesized accessors
/* =================================================================================== */

// private synthesize
@synthesize sampleSizeW = _sampleSizeW;
@synthesize channelCountW = _channelCountW;
@synthesize sampleTypeW = _sampleTypeW;
@synthesize sampleRateW = _sampleRateW;
@synthesize audioFormatDescriptionW = _audioFormatDescriptionW;

/* =================================================================================== */
// MARK: - accessors
/* =================================================================================== */

// public readonly accessors
- (uint32_t) sampleSize { return _sampleSizeW; }
- (uint32_t) channelCount { return _channelCountW; }
- (DLABAudioSampleType) sampleType { return _sampleTypeW; }
- (DLABAudioSampleRate) sampleRate { return _sampleRateW; }
- (CMAudioFormatDescriptionRef) audioFormatDescription { return _audioFormatDescriptionW; }

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
// MARK: - Public methods
/* =================================================================================== */

- (BOOL) buildAudioFormatDescription
{
    CMAudioFormatDescriptionRef formatDescription = NULL;
    {
        // check parameters
        uint32_t sampleSize = self.sampleSize;
        uint32_t channelCount = self.channelCount;
        DLABAudioSampleType sampleType = self.sampleType;
        DLABAudioSampleRate sampleRate = self.sampleRate;
        
        BOOL ready = false;
        if (sampleSize && sampleType && channelCount && sampleRate) {
            ready = true;
        } else {
            NSLog(@"ERROR: Unsupported setting detected.");
        }
        
        if (ready) {
            // ASBD
            AudioStreamBasicDescription streamBasicDescription = {
                sampleRate,                         //mSampleRate
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
            if (!err) {
                self.audioFormatDescriptionW = formatDescription;
            }
        }
    }
    if (formatDescription) {
        CFRelease(formatDescription);
        return YES;
    } else {
        return FALSE;    // TODO handle err
    }
}

@end
