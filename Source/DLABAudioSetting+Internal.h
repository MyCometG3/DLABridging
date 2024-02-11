//
//  DLABAudioSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABAudioSetting.h>
#import <DLABDevice+Internal.h>

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
// MARK: - (Private) - error helper
/* =================================================================================== */

/**
 Utility method to fill (NSError * _Nullable * _Nullable)
 
 @param description string for NSLocalizedDescriptionKey
 @param failureReason string for NSLocalizedFailureReasonErrorKey
 @param result error code
 @param error pointer to (NSError*)
 @return YES if no error, NO if failed
 */
- (BOOL) post:(nullable NSString*)description
       reason:(nullable NSString*)failureReason
         code:(NSInteger)result
           to:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Property - populate by buildAudioFormatDescription
/* =================================================================================== */

/**
 Audio FormatDescription CFObject. Call -(BOOL)buildAudioFormatDescription to populate this.
 */
@property (nonatomic, assign, nullable) CMAudioFormatDescriptionRef audioFormatDescriptionW;

/* =================================================================================== */
// MARK: - Private methods
/* =================================================================================== */

/**
 Utility to fill AudioStreamBasicDescription and CMAudioFormatDescription.

 @param aclData NSData* of AudioChannelLayout
 @param asbdData NSMutableData* of AudioStreamBasicDescription to fill
 @param channelCount mChannelsPerFrame for AudioStreamBasicDescription
 @param sampleSize mBytesPerFrame for AudioStreamBasicDescription
 @param error pointer to (NSError*)
 @return YES if no error, No if failed
 */
- (BOOL)fillAudioFormatDescriptionAndAsbdData:(NSMutableData*)asbdData
                            usingChannelCount:(uint32_t)channelCount
                                   sampleSize:(uint32_t)sampleSize
                                      aclData:(NSData*)aclData
                                        error:(NSError * _Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
