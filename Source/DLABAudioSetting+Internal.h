//
//  DLABAudioSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABAudioSetting.h"
#import "DLABDevice+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABAudioSetting ()

/**
 Create DLABAudioSetting instance.

 @param sampleType BitsPerSample. Either 16 or 32 are supported.
 @param channelCount Number of audio channel. 1 for Mono, 2 for Stereo. 16 max for discrete.
 @param sampleRate Sample frame rate. Only 48000 Hz is supported.
 @return Output Audio Setting object.
 */
- (nullable instancetype) initWithSampleType:(DLABAudioSampleType)sampleType
                                channelCount:(uint32_t)channelCount
                                  sampleRate:(DLABAudioSampleRate)sampleRate;

/* =================================================================================== */
// MARK: Property - populate by buildAudioFormatDescription
/* =================================================================================== */

/**
 Audio FormatDescription CFObject. Call -(BOOL)buildAudioFormatDescription to populate this.
 */
@property (nonatomic, assign, nullable) CMAudioFormatDescriptionRef audioFormatDescriptionW;

@end

NS_ASSUME_NONNULL_END
