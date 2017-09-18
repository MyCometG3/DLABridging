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
#import <CoreMedia/CoreMedia.h>
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

 @param timecodeFormat Specify value of either RP188 family or VITC family.
 @param cvSMPTETime CVSMPTETime stuct for each timecode value fields.
 @param userBits Extra userBits(uint32_t) for timecode.
 @return Instance of DLABTimecode.
 */
- (nullable instancetype) initWithTimecodeFormat:(DLABTimecodeFormat)timecodeFormat
                                     cvSMPTETime:(CVSMPTETime)cvSMPTETime
                                        userBits:(DLABTimecodeUserBits)userBits;

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
 Updating this will adjust dropFrame value.
 
 NOTE: negative component values are not supported
 */
@property (nonatomic, assign) CVSMPTETime smpteTime;

/**
 DLABTimecodeBCD support
 
 BCD representation in uint32_t.
 */
@property (nonatomic, assign) DLABTimecodeBCD timecodeBCD;

/**
 Convenience property to access if dropframe timecode is used
 Updating this will adjust CVSMPTETimeType value.
 */
@property (nonatomic, assign) BOOL dropFrame;

/* =================================================================================== */
// MARK: Public method - Conversion
/* =================================================================================== */

/**
 Timecode String in "HH:MM:SS:FF"

 @return NSString representation of timecode
 */
- (NSString*)timecodeString;

/**
 Update CVSMPTETimeType according to DLABDisplayMode.
 If you use either 2398/2400/2500/5000 modes, dropFrame will be turned off.

 @param displayMode DLABDisplayMode to define proper CVSMPTETimeType value
 @param error Error description if failed.
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) updateCVSMPTETimeTypeUsing:(DLABDisplayMode)displayMode
                              error:(NSError * _Nullable * _Nullable)error;


/**
 Create CMSampleBuffer for Timecode with timingInfo from videoSampleBuffer.
 Supports kCMTimeCodeFormatType_TimeCode32 or kCMTimeCodeFormatType_TimeCode64.

 @param formatType Choose either TimeCode32 or TimeCode64.
 @param videoSampleBuffer Reference as CMTimingInfo source.
 @return Result CMSampleBuffer for Timecode.
 */
- (nullable CMSampleBufferRef) createTimecodeSampleOfFormatType:(CMTimeCodeFormatType)formatType
                                     videoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer;

@end

NS_ASSUME_NONNULL_END
