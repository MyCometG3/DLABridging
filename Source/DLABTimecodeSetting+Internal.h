//
//  DLABTimecodeSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABTimecodeSetting.h"
#import "DeckLinkAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABTimecodeSetting ()

/**
 Create DLABTimecode instance from IDeckLinkTimecode object.

 @param format Specify value of either RP188 family or VITC family.
 @param timecodeObj IDeckLinkTimecode Object.
 @param userBits Extra userBits(uint32_t) for timecode.
 @return Instance of DLABTimecode.
 */
- (nullable instancetype) initWithTimecodeFormat:(BMDTimecodeFormat)format
                                     timecodeObj:(IDeckLinkTimecode*)timecodeObj
                                        userBits:(BMDTimecodeUserBits)userBits;

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
// MARK: (Private) - Conversion
/* =================================================================================== */

/**
 Utility method to create SMPTETime blockBuffer from SVSMPTETime (ref: TN2310)

 @param smpteTime A source CVSMPTETime (kCMTimeCodeFormatType_TimeCode32 or TimeCode64)
 @param sizes blockBuffer size, either sizeof(int32_t) or sizeof(int64_t)
 @param quanta temporal count per second of a picture (ceil up to int value)
 @param tcType kCMTimeCodeFlag_... value.
 @return timecode BlockBuffer from a CVSMPTETime, NULL if failed
 */
- (nullable CMBlockBufferRef) createBlockBufferOfSMPTETime:(CVSMPTETime)smpteTime
                                            sizes:(size_t)sizes
                                           quanta:(uint32_t)quanta
                                           tcType:(uint32_t)tcType CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
