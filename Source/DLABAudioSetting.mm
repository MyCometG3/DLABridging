//
//  DLABAudioSetting.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABAudioSetting+Internal.h>
#import <AudioToolbox/AudioToolbox.h>

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
@synthesize sampleSizeInUse = _sampleSizeInUse;
@synthesize channelCountInUse = _channelCountInUse;

// implementation
- (CMAudioFormatDescriptionRef) audioFormatDescription { return _audioFormatDescriptionW; }

/* =================================================================================== */
// MARK: - Public methods
/* =================================================================================== */

- (BOOL) buildAudioFormatDescriptionWithError:(NSError**)error
{
    BOOL result = FALSE;
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
        } else {
            AudioChannelLayoutTag tag = kAudioChannelLayoutTag_Unknown;
            switch (channelCount) {
                case 1:
                    tag = kAudioChannelLayoutTag_Mono;
                    break;
                case 2:
                    tag = kAudioChannelLayoutTag_Stereo;
                    break;
                default:
                    tag = (kAudioChannelLayoutTag_DiscreteInOrder | channelCount);
                    break;
            }
            result = [self buildAudioFormatDescriptionForTag:tag
                                                       error:error];
        }
    }
    return result;
}

- (BOOL) buildAudioFormatDescriptionForTag:(AudioChannelLayoutTag)tag
                                     error:(NSError**)error
{
    BOOL result = FALSE;
    {
        // check parameters
        uint32_t sampleSize = self.sampleSize;
        uint32_t channelCount = self.channelCount;
        DLABAudioSampleType sampleType = self.sampleType;
        DLABAudioSampleRate sampleRate = self.sampleRate;
        
        uint32_t validChannelCount = AudioChannelLayoutTag_GetNumberOfChannels(tag);
        validChannelCount = (validChannelCount > 0 ? validChannelCount : 99); // detect bad AudioChannelLayoutTag
        uint32_t validSampleSize = validChannelCount * (sampleType / 8);
        
        BOOL ready = (sampleSize && sampleType && channelCount && sampleRate && channelCount >= validChannelCount);
        if (!ready) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported settings detected."
                  code:E_INVALIDARG
                    to:error];
        } else {
            if (channelCount != validChannelCount) {
                NSLog(@"NOTICE: Unbalanced audio channel configuration detected. It requires ");
                NSLog(@"        instant audio buffer reassembling (Inefficient operation).");
            }
            
            // Prepare backing store
            uint32_t asbdSize = sizeof(AudioStreamBasicDescription);
            NSMutableData* asbdData = [[NSMutableData alloc] initWithLength:asbdSize];
            uint32_t aclSize = sizeof(AudioChannelLayout);
            NSMutableData* aclData = [[NSMutableData alloc] initWithLength:aclSize];
            
            // Configure AudioChannelLayout
            AudioChannelLayout* aclPtr = (AudioChannelLayout*)(aclData.mutableBytes);
            aclPtr->mChannelLayoutTag = tag;

            // NOTE: validChannelCount <= channelCount, validSampleSize <= sampleSize
            result = [self fillAudioFormatDescriptionAndAsbdData:asbdData
                                               usingChannelCount:validChannelCount
                                                      sampleSize:validSampleSize
                                                         aclData:aclData
                                                           error:error];
        }
    }
    return result;
}

- (BOOL) buildAudioFormatDescriptionForHDMIAudioChannels:(uint32_t)hdmiChannels
                                           swap3chAnd4ch:(BOOL)swapChOrder
                                                   error:(NSError**)error
{
    BOOL result = FALSE;
    {
        // check parameters
        uint32_t sampleSize = self.sampleSize;
        uint32_t channelCount = self.channelCount;
        DLABAudioSampleType sampleType = self.sampleType;
        DLABAudioSampleRate sampleRate = self.sampleRate;
        
        uint32_t validChannelCount = (hdmiChannels && hdmiChannels <= 8  ? hdmiChannels : 99); // HDMI 2ch/5.1ch/7.1ch
        // uint32_t validSampleSize = validChannelCount * (sampleType / 8);
        
        BOOL ready = (sampleSize && sampleType && channelCount && sampleRate && channelCount >= validChannelCount);
        if (!ready) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported settings detected."
                  code:E_INVALIDARG
                    to:error];
        } else {
            // Prepare backing store
            uint32_t asbdSize = sizeof(AudioStreamBasicDescription);
            NSMutableData* asbdData = [[NSMutableData alloc] initWithLength:asbdSize];
            uint32_t aclSize = sizeof(AudioChannelLayout) + (channelCount - 1) * sizeof(AudioChannelDescription);
            NSMutableData* aclData = [[NSMutableData alloc] initWithLength:aclSize];
            
            // Configure AudioChannelLayout w/ AudioChannelDescription(s)
            AudioChannelLayout* aclPtr = (AudioChannelLayout*)(aclData.mutableBytes);
            aclPtr->mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
            aclPtr->mNumberChannelDescriptions = channelCount;
            
            size_t offsetOfDesc = offsetof(struct AudioChannelLayout, mChannelDescriptions);
            AudioChannelDescription* descPtr = (AudioChannelDescription*)((char*)aclPtr + offsetOfDesc);
            if (validChannelCount == 1) {
                descPtr[0].mChannelLabel = kAudioChannelLabel_Unused;
                descPtr[1].mChannelLabel = kAudioChannelLabel_Unused;
                descPtr[2].mChannelLabel = (swapChOrder ? kAudioChannelLabel_Unused : kAudioChannelLabel_Center);
                descPtr[3].mChannelLabel = (swapChOrder ? kAudioChannelLabel_Center : kAudioChannelLabel_Unused);
            } else if (validChannelCount == 3) {
                descPtr[0].mChannelLabel = kAudioChannelLabel_Left;
                descPtr[1].mChannelLabel = kAudioChannelLabel_Right;
                descPtr[2].mChannelLabel = (swapChOrder ? kAudioChannelLabel_Unused : kAudioChannelLabel_Center);
                descPtr[3].mChannelLabel = (swapChOrder ? kAudioChannelLabel_Center : kAudioChannelLabel_Unused);
            } else {
                uint32_t hdmiChannelOrder[8] = {
                    kAudioChannelLabel_Left,            // = 1 : ch[0]
                    kAudioChannelLabel_Right,           // = 2 : ch[1]
                    kAudioChannelLabel_Center,          // = 3 : ch[2]
                    kAudioChannelLabel_LFEScreen,       // = 4 : ch[3]
                    kAudioChannelLabel_LeftSurround,    // = 5 : ch[4]
                    kAudioChannelLabel_RightSurround,   // = 6 : ch[5]
                    kAudioChannelLabel_LeftCenter,      // = 7 : ch[6]
                    kAudioChannelLabel_RightCenter,     // = 8 : ch[7]
                };
                if (swapChOrder) {
                    // For DeckLink device where HDMI Center Channel is at 4th cnannel
                    hdmiChannelOrder[2] = kAudioChannelLabel_LFEScreen;       // = 4 : ch[2]
                    hdmiChannelOrder[3] = kAudioChannelLabel_Center;          // = 3 : ch[3]
                }
                for (size_t chNum = 0; chNum < validChannelCount; chNum++) {
                    descPtr[chNum].mChannelLabel = hdmiChannelOrder[chNum];
                }
            }
            
            // NOTE: validChannelCount <= channelCount, validSampleSize <= sampleSize
            result = [self fillAudioFormatDescriptionAndAsbdData:asbdData
                                               usingChannelCount:channelCount
                                                      sampleSize:sampleSize
                                                         aclData:aclData
                                                           error:error];
        }
    }
    return result;
}

/* =================================================================================== */
// MARK: - Private methods
/* =================================================================================== */

- (BOOL)fillAudioFormatDescriptionAndAsbdData:(NSMutableData*)asbdData
                            usingChannelCount:(uint32_t)channelCount
                                   sampleSize:(uint32_t)sampleSize
                                      aclData:(NSData*)aclData
                                        error:(NSError**)error
{
    DLABAudioSampleType sampleType = self.sampleType;
    DLABAudioSampleRate sampleRate = self.sampleRate;
    
    AudioChannelLayout* aclPtr = (AudioChannelLayout*)(aclData.bytes);
    uint32_t aclSize = (uint32_t)aclData.length;
    AudioStreamBasicDescription* asbdPtr = (AudioStreamBasicDescription*)(asbdData.mutableBytes);
    
    // Create layout string
    OSStatus err = noErr;
    NSDictionary *extensions = nil;
    {
        uint32_t ioPropertyDataSize = sizeof(CFStringRef);
        CFStringRef outPropertyData = nil;
        err = AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutName,
                                     aclSize,
                                     aclPtr,
                                     &ioPropertyDataSize,
                                     &outPropertyData);
        if (outPropertyData) {
            NSString* layoutString = [NSString stringWithString:(__bridge NSString*)outPropertyData];
            CFRelease(outPropertyData);
            
            // format name
            NSString* keyName = (__bridge NSString*)kCMFormatDescriptionExtension_FormatName;
            NSString* rateString = (sampleRate == DLABAudioSampleRate48kHz ? @"48,000" : @"??.???");
            NSString* name = [NSString stringWithFormat:@"%@ Hz, %d-bit, %@",
                              rateString, sampleType, layoutString];
            extensions = @{keyName : name};
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Failed to AudioFormatGetProperty()."
                  code:E_INVALIDARG
                    to:error];
        }
    }
    
    if (!err) {
        // Fill ASBD
        asbdPtr->mSampleRate =          (Float64)sampleRate;
        asbdPtr->mFormatID =            kAudioFormatLinearPCM;
        asbdPtr->mFormatFlags =         kAudioFormatFlagIsSignedInteger;
        asbdPtr->mBytesPerPacket =      sampleSize;
        asbdPtr->mFramesPerPacket =     1;
        asbdPtr->mBytesPerFrame =       sampleSize;
        asbdPtr->mChannelsPerFrame =    channelCount;
        asbdPtr->mBitsPerChannel =      sampleType;
        
        // create format description
        CMAudioFormatDescriptionRef formatDescription = NULL;
        err = CMAudioFormatDescriptionCreate(NULL,          //allocator
                                             asbdPtr,
                                             (size_t)aclSize,
                                             aclPtr,
                                             0,             //magicCookieSize
                                             NULL,          //magicCookie
                                             (__bridge CFDictionaryRef)extensions,
                                             &formatDescription);
        if (!err && formatDescription) {
            // Update properties
            self.audioFormatDescriptionW = formatDescription;
            CFRelease(formatDescription);
            _sampleSizeInUse = asbdPtr->mBytesPerFrame;
            _channelCountInUse = asbdPtr->mChannelsPerFrame;
            return TRUE;
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Failed to create CMAudioFormatDescription."
                  code:E_INVALIDARG
                    to:error];
        }
    }
    
    return FALSE;
}

@end
