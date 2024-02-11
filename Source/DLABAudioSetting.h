//
//  DLABAudioSetting.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <DLABridging/DLABConstants.h>

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
 Number of audio channel. 2 for Stereo. 8 or 16 for discrete or special channel layout.
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
 Audio FormatDescription CFObject. Call buildAudioFormatDescription* to populate this.
 */
@property (nonatomic, assign, readonly, nullable) CMAudioFormatDescriptionRef audioFormatDescription;

/**
 Number of valid bytes in sample frame. e.g. HDMI 5.1ch on 16bit 8ch = 12 bytes from 16 bytes in use.
 */
@property (nonatomic, assign, readonly) uint32_t sampleSizeInUse;

/**
 Number of valid channels in sample frame. e.g. HDMI 5.1ch on 16bit 8ch = 6ch from 8ch in use.
 */
@property (nonatomic, assign, readonly) uint32_t channelCountInUse;

/* =================================================================================== */
// MARK: Public methods
/* =================================================================================== */

/**
 Prepare Audio FormatDescription CFObject from current parameters.
 
 @param error pointer to (NSError*)
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildAudioFormatDescriptionWithError:(NSError * _Nullable * _Nullable)error;

/**
 Prepare AudioFormatDescription CFObject using specified AudioChannelLayoutTag.
 
 @param tag Set specific AudioChannelLayoutTag.
 @param error pointer to (NSError*)
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildAudioFormatDescriptionForTag:(AudioChannelLayoutTag)tag
                                     error:(NSError * _Nullable __autoreleasing *)error;

/**
 Prepare AudioFormatDescription CFObject in HDMI Surround Channel order (L R C LFE Ls Rs Rls Rrs).
 
 @param validChannels Specify the number of valid channel count (up to 8ch)
 @param swapChOrder Set True for the device where center is at 4th channel
 @param error pointer to (NSError*)
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildAudioFormatDescriptionForHDMIAudioChannels:(uint32_t)validChannels
                                           swap3chAnd4ch:(BOOL)swapChOrder
                                                   error:(NSError * _Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END

