//
//  DLABTimecodeSetting.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <CoreVideo/Corevideo.h>
#import "DLABConstants.h"

NS_ASSUME_NONNULL_BEGIN


/**
 DLABTimecodeSetting is a container related to Timecode settings.
 
 This also interacts with DLABTiecodeBCD(RW), CVSMPTETime(RW) and Timecode String(RO).
 */
@interface DLABTimecodeSetting : NSObject <NSCopying>

/**
 Create DLABTimecode instance.

 @param timecodeFormat Specify value of either RP188 family or VITC family.
 @param hour Timecode Value field.
 @param minute Timecode Value field.
 @param second Timecode Value field.
 @param frame Timecode Value field.
 @param flags Bitfield of timecode flags.
 @param userBits Extra userBits(uint32_t) for timecode.
 @return Instance of DLABTimecode.
 */
- (nullable instancetype) initWithTimecodeFormat:(DLABTimecodeFormat)timecodeFormat
                                            hour:(uint8_t)hour
                                          minute:(uint8_t)minute
                                          second:(uint8_t)second
                                           frame:(uint8_t)frame
                                           flags:(DLABTimecodeFlag)flags
                                        userBits:(DLABTimecodeUserBits)userBits NS_DESIGNATED_INITIALIZER;
/**
 Create DLABTimecode instance from CVSMPTETime struct.

 @param format Specify value of either RP188 family or VITC family.
 @param smpte CVSMPTETime stuct for each timecode value fields.
 @return Instance of DLABTimecode.
 */
- (nullable instancetype) initWithTimecodeFormat:(DLABTimecodeFormat)format
                                     CVSMPTETime:(CVSMPTETime)smpte;

/* =================================================================================== */
// MARK: Property - Timecode components
/* =================================================================================== */

/**
 Timecode component of hour.
 */
@property (nonatomic, assign) uint8_t hour;
/**
 Timecode component of minute.
 */
@property (nonatomic, assign) uint8_t minute;
/**
 Timecode component of second.
 */
@property (nonatomic, assign) uint8_t second;
/**
 Timecode component of frame.
 */
@property (nonatomic, assign) uint8_t frame;

/* =================================================================================== */
// MARK: Property - Parameters from BMDTimecode object
/* =================================================================================== */

/**
 Specify value of either RP188 family or VITC family..
 */
@property (nonatomic, assign) DLABTimecodeFormat format;
/**
 Bitfield of timecode flags.
 */
@property (nonatomic, assign) DLABTimecodeFlag flags;
/**
 Extra userBits(uint32_t) for timecode.
 */
@property (nonatomic, assign) DLABTimecodeUserBits userBits;

/* =================================================================================== */
// MARK: Property - Conversion
/* =================================================================================== */

/**
 CVSMPTETime struct support
 
 NOTE: negative component values are not supported
 */
@property (nonatomic, assign) CVSMPTETime smpteTime;

/**
 DLABTimecodeBCD support
 
 BCD representation in uint32_t.
 */
@property (nonatomic, assign) DLABTimecodeBCD timecodeBCD;

/* =================================================================================== */
// MARK: Public method - Conversion
/* =================================================================================== */

/**
 Timecode String in "HH:MM:SS:FF"

 @return NSString representation of timecode
 */
- (NSString*)timecodeString;

@end

NS_ASSUME_NONNULL_END
