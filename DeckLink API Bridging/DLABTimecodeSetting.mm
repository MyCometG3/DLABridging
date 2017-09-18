//
//  DLABTimecodeSetting.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
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
        timecodeObj->AddRef();
        result = timecodeObj->GetComponents(&hour, &minute, &second, &frame);
        flag = (DLABTimecodeFlag) timecodeObj->GetFlags();
        timecodeObj->Release();
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
                break;
        }
    }
}

- (uint32_t) smpteTimeType
{
    uint32_t type = _smpteTime.type;
    return type;
}

- (void) setSmpteTimeType:(uint32_t) newSmpteType
{
    // Create new CVSMPTETime struct
    CVSMPTETime newSMPTETime = _smpteTime;
    newSMPTETime.type = newSmpteType;

    // Force update as is DropFrame or not
    [self setSmpteTime:newSMPTETime];
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

@end
