//
//  DLABAudioSetting.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import "DLABConstants.h"
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/**
 DLABAudioSetting is a container related to Audio Input/Output settings.
 
 You have to ask DLABDevice to create new audioSetting object using either
 - createInputAudioSettingOfSampleType:channelCount:sampleRate:error: or,
 - createOutputAudioSettingOfSampleType:channelCount:sampleRate:error:
 
 sampleSize : Should be same value as AudioStreamBasicDescription.mBytesPerFrame
 
 | 16bit | 2channel |  4bytes |
 
 | 16bit | 8channel | 16bytes |
 
 | 16bit |16channel | 32bytes |
 
 | 32bit | 2channel |  8bytes |
 
 | 32bit | 8channel | 32bytes |
 
 | 32bit |16channel | 64bytes |
 */
@interface DLABAudioSetting : NSObject <NSCopying>

- (instancetype) init NS_UNAVAILABLE;

/* =================================================================================== */
// MARK: Property - Ready on init
/* =================================================================================== */

// uint32_t - Ready on init

/**
 Length of one Sample frame in bytes.
 */
@property (nonatomic, assign, readonly) uint32_t sampleSize;

/**
 Number of audio channel. 1 for Mono, 2 for Stereo. 16 max for discrete.
 */
@property (nonatomic, assign, readonly) uint32_t channelCount;

/**
 BitsPerSample. Either 16 or 32 are supported.
 */
@property (nonatomic, assign, readonly) DLABAudioSampleType sampleType;

/**
 Sample frame rate. Only 48000 Hz is supported.
 */
@property (nonatomic, assign, readonly) DLABAudioSampleRate sampleRate;

/* =================================================================================== */
// MARK: Property - populate by buildAudioFormatDescription
/* =================================================================================== */

/**
 Audio FormatDescription CFObject. Call -(BOOL)buildAudioFormatDescription to populate this.
 */
@property (nonatomic, assign, readonly, nullable) CMAudioFormatDescriptionRef audioFormatDescription;

/* =================================================================================== */
// MARK: Public methods
/* =================================================================================== */

/**
 Prepare Audio FormatDescription CFObject from current parameters.

 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildAudioFormatDescription;

@end

NS_ASSUME_NONNULL_END

