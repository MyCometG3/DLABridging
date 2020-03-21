//
//  DLABTimecodeSetting.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABTimecodeSetting+Internal.h"

@implementation DLABTimecodeSetting

- (instancetype) init
{
    return [self initWithTimecodeFormat:DLABTimecodeFormatRP188Any
                                   hour:0
                                 minute:0
                                 second:0
                                  frame:0
                                  flags:DLABTimecodeFlagDefault
                               userBits:0];
}

- (instancetype) initWithTimecodeFormat:(DLABTimecodeFormat)format
                                            hour:(uint8_t)hour
                                          minute:(uint8_t)minute
                                          second:(uint8_t)second
                                           frame:(uint8_t)frame
                                           flags:(DLABTimecodeFlag)flags
                                        userBits:(DLABTimecodeUserBits)userBits
{
    NSParameterAssert(format);
    
    self = [super init];
    if (self) {
        _hour = hour;
        _minute = minute;
        _second = second;
        _frame = frame;
        
        _format = (DLABTimecodeFormat)format;
        _flags = (DLABTimecodeFlag)flags;
        _userBits = userBits;
        
        _smpteTime = {0};
        _smpteTime.hours = (SInt16)_hour;
        _smpteTime.minutes = (SInt16)_minute;
        _smpteTime.seconds = (SInt16)_second;
        _smpteTime.frames = (SInt16)_frame;
    }
    return self;
}

- (instancetype) initWithTimecodeFormat:(BMDTimecodeFormat)format
                                     timecodeObj:(IDeckLinkTimecode*)timecodeObj
                                        userBits:(BMDTimecodeUserBits)userBits
{
    NSParameterAssert(format && timecodeObj);
    
    HRESULT result = E_FAIL;
    uint8_t hour = 0, minute = 0, second = 0, frame = 0;
    DLABTimecodeFlag flag = DLABTimecodeFlagDefault;
    if (timecodeObj) {
        result = timecodeObj->GetComponents(&hour, &minute, &second, &frame);
        flag = (DLABTimecodeFlag) timecodeObj->GetFlags();
    }
    if (result) return nil;
    
    return [self initWithTimecodeFormat:(DLABTimecodeFormat)format
                                   hour:hour
                                 minute:minute
                                 second:second
                                  frame:frame
                                  flags:flag
                               userBits:userBits];
}

- (instancetype) initWithTimecodeFormat:(DLABTimecodeFormat)format
                            cvSMPTETime:(CVSMPTETime)smpte
                               userBits:(DLABTimecodeUserBits)userBits
{
    NSParameterAssert(format);
    
    // Check negative value in CVSMPTETime components
    if (smpte.hours < 0 || smpte.minutes <0 || smpte.seconds < 0 || smpte.frames < 0)
        return nil;
    
    uint8_t hour = (uint8_t) smpte.hours;
    uint8_t minute = (uint8_t) smpte.minutes;
    uint8_t second = (uint8_t) smpte.seconds;
    uint8_t frame = (uint8_t) smpte.frames;
    
    DLABTimecodeFlag flag = DLABTimecodeFlagDefault;
    switch (smpte.type) {
        case 2: // kSMPTETimeType30Drop, kCVSMPTETimeType30Drop
        case 5: // kSMPTETimeType2997Drop, kCVSMPTETimeType2997Drop
        case 8: // kSMPTETimeType60Drop
        case 9: // kSMPTETimeType5994Drop
            flag = DLABTimecodeFlagIsDropFrame;
            break;
        default:
            flag = DLABTimecodeFlagDefault;
            break;
    }
    
    return [self initWithTimecodeFormat:(DLABTimecodeFormat)format
                                   hour:hour
                                 minute:minute
                                 second:second
                                  frame:frame
                                  flags:flag
                               userBits:userBits];
}

// public hash - NSObject
- (NSUInteger) hash
{
    NSUInteger value = (NSUInteger)(_format^_flags) ^ (NSUInteger)(_hour^_minute^_second^_frame);
    return value;
}

// public comparison - NSObject
- (BOOL) isEqual:(id)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    return [self isEqualToTimecodeSetting:(DLABTimecodeSetting*)object];
}

// private comparison - DLABTimecodeSetting
- (BOOL) isEqualToTimecodeSetting:(DLABTimecodeSetting*)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    if (!( self.hour == object.hour )) return NO;
    if (!( self.minute == object.minute )) return NO;
    if (!( self.second == object.second )) return NO;
    if (!( self.frame == object.frame )) return NO;
    
    if (!( self.format == object.format )) return NO;
    if (!( self.flags == object.flags )) return NO;
    if (!( self.userBits == object.userBits )) return NO;
    
    return YES;
}

// NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone
{
    DLABTimecodeSetting* obj = [[DLABTimecodeSetting alloc] initWithTimecodeFormat:self.format
                                                                              hour:self.hour
                                                                            minute:self.minute
                                                                            second:self.second
                                                                             frame:self.frame
                                                                             flags:self.flags
                                                                          userBits:self.userBits];
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
// MARK: - Property - Timecode components
/* =================================================================================== */

- (void) setHour:(uint8_t)hour
{
    _hour = hour;
    _smpteTime.hours = (SInt16) hour;
}

- (void) setMinute:(uint8_t)minute
{
    _minute = minute;
    _smpteTime.minutes = (SInt16) minute;
}

- (void) setSecond:(uint8_t)second
{
    _second = second;
    _smpteTime.seconds = (SInt16) second;
}

- (void) setFrame:(uint8_t)frame
{
    _frame = frame;
    _smpteTime.frames = (SInt16) frame;
}

- (void) setFlags:(DLABTimecodeFlag)flags
{
    _flags = flags;
    
    // Force update as is DropFrame or not
    [self setDropFrame:(_flags & DLABTimecodeFlagIsDropFrame)];
}

/* =================================================================================== */
// MARK: - Property - Conversion
/* =================================================================================== */

// CVSMPTETime struct
- (void) setSmpteTime:(CVSMPTETime)smpte
{
    // negative component values are not supported
    if (smpte.hours < 0 || smpte.minutes <0 || smpte.seconds < 0 || smpte.frames < 0)
        return;
    
    _hour = (uint8_t) smpte.hours;
    _minute = (uint8_t) smpte.minutes;
    _second = (uint8_t) smpte.seconds;
    _frame = (uint8_t) smpte.frames;
    
    _smpteTime = smpte;
    
    // update DLABTimecodeFlag with Drop or non-Drop timecode
    // Some types are only defined in CoreAudio SMPTETime only = (**)
    switch (_smpteTime.type) {
        case 2: // kSMPTETimeType30Drop, kCVSMPTETimeType30Drop
        case 5: // kSMPTETimeType2997Drop, kCVSMPTETimeType2997Drop
        case 8: // kSMPTETimeType60Drop (**)
        case 9: // kSMPTETimeType5994Drop (**)
            [self setDropFrame:YES];
            break;
        default:
            [self setDropFrame:NO];
            break;
    }
}

// DLABTimecodeBCD support

- (DLABTimecodeBCD) timecodeBCD
{
    uint8_t h1 = _hour / 10;
    uint8_t h2 = _hour % 10;
    uint8_t m1 = _minute / 10;
    uint8_t m2 = _minute % 10;
    uint8_t s1 = _second / 10;
    uint8_t s2 = _second % 10;
    uint8_t f1 = _frame / 10;
    uint8_t f2 = _frame % 10;
    
    DLABTimecodeBCD bcdValue= 0;
    bcdValue = ((((uint32_t) h1) << 28) +\
                (((uint32_t) h2) << 24) +\
                (((uint32_t) m1) << 20) +\
                (((uint32_t) m2) << 16) +\
                (((uint32_t) s1) << 12) +\
                (((uint32_t) s2) <<  8) +\
                (((uint32_t) f1) <<  4) +\
                (((uint32_t) f2)      )
                );
    return bcdValue;
}

- (void) setTimecodeBCD:(DLABTimecodeBCD)bcdValue
{
    uint8_t h1 = (uint8_t) ((bcdValue >> 28) & 0xF);
    uint8_t h2 = (uint8_t) ((bcdValue >> 24) & 0xF);
    uint8_t m1 = (uint8_t) ((bcdValue >> 20) & 0xF);
    uint8_t m2 = (uint8_t) ((bcdValue >> 16) & 0xF);
    uint8_t s1 = (uint8_t) ((bcdValue >> 12) & 0xF);
    uint8_t s2 = (uint8_t) ((bcdValue >>  8) & 0xF);
    uint8_t f1 = (uint8_t) ((bcdValue >>  4) & 0xF);
    uint8_t f2 = (uint8_t) ((bcdValue      ) & 0xF);
    
    _hour = h1 * 10 + h2 % 10;
    _minute = m1 * 10 + m2 % 10;
    _second = s1 * 10 + s2 % 10;
    _frame = f1 * 10 + f2 % 10;
    
    _smpteTime.hours = (SInt16)_hour;
    _smpteTime.minutes = (SInt16)_minute;
    _smpteTime.seconds = (SInt16)_second;
    _smpteTime.frames = (SInt16)_frame;
}

- (BOOL) dropFrame
{
    BOOL useDropFrame = (_flags & DLABTimecodeFlagIsDropFrame) ? YES : NO;
    return useDropFrame;
}

- (void) setDropFrame:(BOOL)useDropFrame
{
    // Some types are only defined in CoreAudio SMPTETime only = (**)
    if (useDropFrame) {
        // update DLABTimecodeFlag as Drop timecode
        _flags |= DLABTimecodeFlagIsDropFrame;
        
        // update CVSMPTETimeType as DropFrame timecode
        switch (_smpteTime.type) {
            case 2:
            case 5:
            case 8:
            case 9:
                // OK
                break;
            case 3:                     // kSMPTETimeType30, kCVSMPTETimeType30
                _smpteTime.type = 2;    // kSMPTETimeType30Drop, kCVSMPTETimeType30Drop
                break;
            case 4:                     // kSMPTETimeType2997, kCVSMPTETimeType2997
                _smpteTime.type = 5;    // kSMPTETimeType2997Drop, kCVSMPTETimeType2997Drop
                break;
            case 6:                     // kSMPTETimeType60, kCVSMPTETimeType60
                _smpteTime.type = 8;    // kSMPTETimeType60Drop (**)
                break;
            case 7:                     // kSMPTETimeType5994 (**)
                _smpteTime.type = 9;    // kSMPTETimeType5994Drop (**)
                break;
            default:
                // TODO: invalid combination detected
                _smpteTime.type = 5;    // Reset CVSMPTETimeType
                break;
        }
    } else {
        // update DLABTimecodeFlag as non-Drop timecode
        _flags &= (~DLABTimecodeFlagIsDropFrame);
        
        // update CVSMPTETimeType as non-DropFrame timecode
        switch (_smpteTime.type) {
            case 2:                     // kSMPTETimeType30Drop, kCVSMPTETimeType30Drop
                _smpteTime.type = 3;    // kSMPTETimeType30, kCVSMPTETimeType30
                break;
            case 5:                     // kSMPTETimeType2997Drop, kCVSMPTETimeType2997Drop
                _smpteTime.type = 4;    // kSMPTETimeType2997, kCVSMPTETimeType2997
                break;
            case 8:                     // kSMPTETimeType60Drop (**)
                _smpteTime.type = 6;    // kSMPTETimeType60, kCVSMPTETimeType60
                break;
            case 9:                     // kSMPTETimeType5994Drop (**)
                _smpteTime.type = 7;    // kSMPTETimeType5994 (**)
                break;
            default:
                // OK
                break;
        }
    }
}

/* =================================================================================== */
// MARK: Public method - Conversion
/* =================================================================================== */

// Timecode String in "HH:MM:SS:FF"

- (NSString*)timecodeString
{
    NSString* string = [NSString stringWithFormat:@"%02d:%02d:%02d:%02d",
                        (uint32_t)_hour,
                        (uint32_t)_minute,
                        (uint32_t)_second,
                        (uint32_t)_frame];
    return string;
}

// Update CVSMPTETimeType using DLABDisplayMode.

- (BOOL) updateCVSMPTETimeTypeUsing:(DLABDisplayMode)displayMode
                              error:(NSError * _Nullable * _Nullable)error
{
    // Update CVSMPTETimeType according to DLABDisplayMode.
    // Some types are only defined in CoreAudio SMPTETime only = (**)
    uint32_t type = 0;
    {
        BOOL err = NO;
        switch (displayMode) {
            case DLABDisplayModeHD1080p24:
            case DLABDisplayMode2k24:
            case DLABDisplayMode2kDCI24:
            case DLABDisplayMode4K2160p24:
            case DLABDisplayMode4kDCI24:
                type = 0; break;    // kSMPTETimeType24, kCVSMPTETimeType24
            case DLABDisplayModePAL:
            case DLABDisplayModeHD1080p25:
            case DLABDisplayModeHD1080i50:
            case DLABDisplayMode2k25:
            case DLABDisplayMode2kDCI25:
            case DLABDisplayMode4K2160p25:
            case DLABDisplayMode4kDCI25:
                type = 1; break;    // kSMPTETimeType25, kCVSMPTETimeType25
            case DLABDisplayModeHD1080p30:
            case DLABDisplayModeHD1080i6000:
            case DLABDisplayMode4K2160p30:
                type = 3; break;    // kSMPTETimeType30, kCVSMPTETimeType30
            case DLABDisplayModeNTSC:
            case DLABDisplayModeNTSC2398:
            case DLABDisplayModeHD1080p2997:
            case DLABDisplayModeHD1080i5994:
            case DLABDisplayMode4K2160p2997:
                type = 4; break;    // kSMPTETimeType2997, kCVSMPTETimeType2997
            case DLABDisplayModeHD720p60:
            case DLABDisplayModeHD1080p6000:
            case DLABDisplayMode4K2160p60:
                type = 6; break;    // kSMPTETimeType60, kCVSMPTETimeType60
            case DLABDisplayModeNTSCp:
            case DLABDisplayModeHD720p5994:
            case DLABDisplayModeHD1080p5994:
            case DLABDisplayMode4K2160p5994:
                type = 7; break;    // kSMPTETimeType5994, kCVSMPTETimeType5994
            case DLABDisplayModePALp:
            case DLABDisplayModeHD720p50:
            case DLABDisplayModeHD1080p50:
            case DLABDisplayMode4K2160p50:
                type = 10; break;   // kSMPTETimeType50 (**)
            case DLABDisplayModeHD1080p2398:
            case DLABDisplayMode2k2398:
            case DLABDisplayMode2kDCI2398:
            case DLABDisplayMode4K2160p2398:
            case DLABDisplayMode4kDCI2398:
                type = 11; break;   // kSMPTETimeType2398 (**)
            default:
                err = YES; break;
        }
        if (err) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported displayMode setting detected."
                  code:E_INVALIDARG
                    to:error];
            return NO;
        }
    }
    
    // update CVSMPTETimeType if DropFrame timecode is used
    if (self.dropFrame) {
        switch (type) {
            case 3:                 // kSMPTETimeType30, kCVSMPTETimeType30
                type = 2; break;    // kSMPTETimeType30Drop, kCVSMPTETimeType30Drop
            case 4:                 // kSMPTETimeType2997, kCVSMPTETimeType2997
                type = 5; break;    // kSMPTETimeType2997Drop, kCVSMPTETimeType2997Drop
            case 6:                 // kSMPTETimeType60, kCVSMPTETimeType60
                type = 8; break;    // kSMPTETimeType60Drop (**)
            case 7:                 // kSMPTETimeType5994, kCVSMPTETimeType5994
                type = 9; break;    // kSMPTETimeType5994Drop (**)
            default:
                // This displayMode is incompatible with dropFrame (2398/2400/2500/5000)
                // DropFrame support will be turned off in [self setSmpteTime:newValue]
                break;
        }
    }
    
    // Update with proper CVSMPTETimeType
    // Create new CVSMPTETime struct
    CVSMPTETime newSMPTETime = self.smpteTime;
    newSMPTETime.type = type;
    
    // Force update as is DropFrame or not
    [self setSmpteTime:newSMPTETime];
    return YES;
}

- (CMSampleBufferRef) createTimecodeSampleIn:(CMTimeCodeFormatType)formatType
                                 videoSample:(CMSampleBufferRef)videoSampleBuffer
{
    NSParameterAssert(formatType && videoSampleBuffer);
    
    CVSMPTETime smpte = self.smpteTime;
    
    // Check CMTimeCodeFormatType
    size_t sizes = 0;
    switch (formatType) {
        case kCMTimeCodeFormatType_TimeCode32:
            sizes = sizeof(int32_t); break;
        case kCMTimeCodeFormatType_TimeCode64:
            sizes = sizeof(int64_t); break;
        default:
            // Unsupported : kCMTimeCodeFormatType_Counter32/kCMTimeCodeFormatType_Counter64
            return NULL; break;
    }
    
    // Evaluate TimeCode Quanta
    uint32_t quanta = 30;
    switch (smpte.type) {
        case  0:
            quanta = 24; break;
        case  1:
            quanta = 25; break;
        case  2:
        case  3:
        case  4:
        case  5:
            quanta = 30; break;
        case  6:
        case  7:
        case  8:
        case  9:
            quanta = 60; break;
        case  10:
            quanta = 50; break;
        case  11:
            quanta = 25; break;
        default:
            break;
    }
    
    // Evaluate TimeCode type
    uint32_t tcType =  kCMTimeCodeFlag_24HourMax; // | kCMTimeCodeFlag_NegTimesOK
    switch (smpte.type) {
        case  2:
        case  5:
        case  8:
        case  9:
            tcType |= kCMTimeCodeFlag_DropFrame;
            break;
        default:
            break;
    }
    
    // Prepare Data Buffer for new SampleBuffer
    CMBlockBufferRef dataBuffer = [self createBlockBufferOfSMPTETime:smpte
                                                               sizes:sizes
                                                              quanta:quanta
                                                              tcType:tcType];
    if (!dataBuffer)
        return NULL;
    
    /* ============================================ */
    
    // Prepare TimeCode SampleBuffer
    CMSampleBufferRef sampleBuffer = NULL;
    if (dataBuffer && formatType) {
        OSStatus status = noErr;
        
        // Extract duration from video sample
        CMTime duration = CMSampleBufferGetDuration(videoSampleBuffer);
        
        // Extract timeingInfo from videoSample
        CMSampleTimingInfo timingInfo = {0};
        CMSampleBufferGetSampleTimingInfo(videoSampleBuffer, 0, &timingInfo);
        
        // Prepare CMTimeCodeFormatDescription
        CMTimeCodeFormatDescriptionRef description = NULL;
        status = CMTimeCodeFormatDescriptionCreate(kCFAllocatorDefault,
                                                   formatType,
                                                   duration,
                                                   quanta,
                                                   tcType,
                                                   NULL,
                                                   &description);
        if (status != noErr || description == NULL) {
            NSLog(@"ERROR: Could not create format description.");
            CFRelease(dataBuffer);
            return NULL;
        }
        
        // Create new sampleBuffer
        CMSampleTimingInfo timingInfoTMP = {0};
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      dataBuffer,
                                      true,
                                      NULL,
                                      NULL,
                                      description,
                                      1,
                                      1,
                                      &timingInfoTMP,
                                      1,
                                      &sizes,
                                      &sampleBuffer);
        CFRelease(description);
        CFRelease(dataBuffer);
        
        if (status != noErr || sampleBuffer == NULL) {
            NSLog(@"ERROR: Could not create sample buffer.");
            return NULL;
        }
    }
    
    return sampleBuffer;
}

- (CMBlockBufferRef) createBlockBufferOfSMPTETime:(CVSMPTETime)smpteTime
                                            sizes:(size_t)sizes
                                           quanta:(uint32_t)quanta
                                           tcType:(uint32_t)tcType
{
    // Calculate frameNumber for specific SMPTETime
    int64_t frameNumber64 = 0;
    int16_t tcNegativeFlag = (int16_t)0x80;
    frameNumber64 = (int64_t)(smpteTime.frames);
    frameNumber64 += (int64_t)(smpteTime.seconds) * (int64_t)(quanta);
    frameNumber64 += (int64_t)(smpteTime.minutes & ~tcNegativeFlag) * (int64_t)(quanta) * 60;
    frameNumber64 += (int64_t)(smpteTime.hours) * (int64_t)(quanta) * 60 * 60;
    
    int64_t fpm = (int64_t)(quanta) * 60;
    if ((tcType & kCMTimeCodeFlag_DropFrame) != 0) {
        int64_t fpm10 = fpm * 10;
        int64_t num10s = frameNumber64 / fpm10;
        int64_t frameAdjust = -num10s * (9*2);
        int64_t numFramesLeft = frameNumber64 % fpm10;
        
        if (numFramesLeft > 1) {
            int64_t num1s = numFramesLeft / fpm;
            if (num1s > 0) {
                frameAdjust -= (num1s - 1 ) * 2;
                numFramesLeft = numFramesLeft % fpm;
                if (numFramesLeft > 1 ) {
                    frameAdjust -= 2;
                } else {
                    frameAdjust -= (numFramesLeft + 1);
                }
            }
        }
        frameNumber64 += frameAdjust;
    }
    
    if ((smpteTime.minutes & tcNegativeFlag) != 0) {
        frameNumber64 = -frameNumber64;
    }
    
    // TODO
    int32_t frameNumber32 = (int32_t)frameNumber64;
    
    /* ============================================ */
    
    // Allocate BlockBuffer
    CMBlockBufferRef dataBuffer = NULL;
    OSStatus status = noErr;
    status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                NULL,
                                                sizes,
                                                kCFAllocatorDefault,
                                                NULL,
                                                0,
                                                sizes,
                                                kCMBlockBufferAssureMemoryNowFlag,
                                                &dataBuffer);
    if (status != noErr || dataBuffer == NULL) {
        NSLog(@"ERROR: Could not create block buffer.");
        return NULL;
    }
    
    // Write FrameNumber into BlockBuffer
    if (dataBuffer) {
        if (sizes == sizeof(int32_t)){
            int32_t frameNumber32BE = EndianS32_NtoB(frameNumber32);
            status = CMBlockBufferReplaceDataBytes(&frameNumber32BE,
                                                   dataBuffer,
                                                   0,
                                                   sizes);
        } else if (sizes == sizeof(int64_t)) {
            int64_t frameNumber64BE = EndianS64_NtoB(frameNumber64);
            status = CMBlockBufferReplaceDataBytes(&frameNumber64BE,
                                                   dataBuffer,
                                                   0,
                                                   sizes);
        } else {
            status = -1;
        }
        if (status != kCMBlockBufferNoErr) {
            NSLog(@"ERROR: Could not write into block buffer.");
            CFRelease(dataBuffer);
            return NULL;
        }
    }

    return dataBuffer;
}

@end
