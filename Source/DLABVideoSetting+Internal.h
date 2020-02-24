//
//  DLABVideoSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABVideoSetting.h"
#import "DLABDevice+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABVideoSetting ()

/**
 Create DLABVideoSetting reference instance from IDeckLinkDisplayMode Object.

 @param newDisplayModeObj IDeckLinkDisplayMode Object.
 @return Instance of DLABVideoSetting.
 */
- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj NS_DESIGNATED_INITIALIZER;

/**
 Create DLABVideoSetting(Input) instance from IDeckLinkDisplayMode Object and required details.

 @param newDisplayModeObj IDeckLinkDisplayMode Object.
 @param pixelFormat Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 @param inputFlag Additional flag of video input (i.e. DLABVideoInputFlagEnableFormatDetection)
 @param displayModeSupport Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 @return Input Video Setting Object.
 */
- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                                     pixelFormat:(BMDPixelFormat)pixelFormat
                                  videoInputFlag:(BMDVideoInputFlags)inputFlag
                              displayModeSupport:(BMDDisplayModeSupport_v10_11)displayModeSupport __attribute__((deprecated));

- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                                     pixelFormat:(BMDPixelFormat)pixelFormat
                                  videoInputFlag:(BMDVideoInputFlags)inputFlag;

/**
 Create DLABVideoSetting(Output) instance from IDeckLinkDisplayMode Object and required details.

 @param newDisplayModeObj IDeckLinkDisplayMode Object.
 @param pixelFormat Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 @param outputFlag Additional flag of video (i.e. DLABVideoOutputFlagVANC)
 @param displayModeSupport Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 @return Output Video Setting Object.
 */
- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                                     pixelFormat:(BMDPixelFormat)pixelFormat
                                 videoOutputFlag:(BMDVideoOutputFlags)outputFlag
                              displayModeSupport:(BMDDisplayModeSupport_v10_11)displayModeSupport __attribute__((deprecated));

- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                                     pixelFormat:(BMDPixelFormat)pixelFormat
                                 videoOutputFlag:(BMDVideoOutputFlags)outputFlag;

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
// MARK: Property - Ready on init
/* =================================================================================== */

//  - Ready on init

/**
 IDeckLinkDisplayMode object.
 */
@property (nonatomic, assign, nullable) IDeckLinkDisplayMode* displayModeObj;

// long - Ready on init

/**
 Rectangle horizontal size in pixel.
 */
@property (nonatomic, assign) long widthW;

/**
 Rectangle vertical size in pixel.
 */
@property (nonatomic, assign) long heightW;

/**
 IDeckLinkDisplayMode::GetName
 */
@property (nonatomic, copy) NSString* nameW;

// int64_t - Ready on init

/**
 Duration value of one sample in timeScale.
 */
@property (nonatomic, assign) DLABTimeValue durationW;

/**
 Resolution value of one sample between one second.
 */
@property (nonatomic, assign) DLABTimeScale timeScaleW;

// uint32_t - Ready on init

/**
 Video stream categoly (i.e. DLABDisplayModeNTSC, DLABDisplayModeHD1080i5994)
 
 * This parameter represents visual resolution, interlace/progressive, and frame rate.
 */
@property (nonatomic, assign) DLABDisplayMode displayModeW;

/**
 Field dominance value (i.e. DLABFieldDominanceLowerFieldFirst)
 */
@property (nonatomic, assign) DLABFieldDominance fieldDominanceW;

/**
 Additional flag of displayMode (i.e. DLABDisplayModeFlagColorspaceRec709)
 */
@property (nonatomic, assign) DLABDisplayModeFlag displayModeFlagW;


// BOOL - Ready on init

/**
 Convenience property if it represents HD resolution.
 */
@property (nonatomic, assign) BOOL isHDW;

/**
 Convenience property if preferred timecode type is VITC.
 */
@property (nonatomic, assign) BOOL useVITCW;

/**
 Convenience property if preferred timecode type is RP188.
 */
@property (nonatomic, assign) BOOL useRP188W;

/* =================================================================================== */
// MARK: Property - Ready when added
/* =================================================================================== */

// clap extension

/**
 Yes if clean aperture (clap) is ready.
 */
@property (nonatomic, assign) BOOL clapReady;
/**
 Numerator of kCMFormatDescriptionKey_CleanApertureWidthRational.
 */
@property (nonatomic, assign) int32_t clapWidthN;
/**
 Denominator of kCMFormatDescriptionKey_CleanApertureWidthRational.
 */
@property (nonatomic, assign) int32_t clapWidthD;
/**
 Numerator of kCMFormatDescriptionKey_CleanApertureHeightRational.
 */
@property (nonatomic, assign) int32_t clapHeightN;
/**
 Denominator of kCMFormatDescriptionKey_CleanApertureHeightRational.
 */
@property (nonatomic, assign) int32_t clapHeightD;
/**
 Numerator of kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational.
 */
@property (nonatomic, assign) int32_t clapHOffsetN;
/**
 Denominator of kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational.
 */
@property (nonatomic, assign) int32_t clapHOffsetD;
/**
 Numerator of kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational.
 */
@property (nonatomic, assign) int32_t clapVOffsetN;
/**
 Denominator of kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational.
 */
@property (nonatomic, assign) int32_t clapVOffsetD;

// pasp extension

/**
 Yes if pixel aspect ratio (pasp) is ready.
 */
@property (nonatomic, assign) BOOL paspReady;
/**
 Value of kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing
 */
@property (nonatomic, assign) uint32_t paspHSpacing;
/**
 Value of kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing
 */
@property (nonatomic, assign) uint32_t paspVSpacing;

/* =================================================================================== */
// MARK: Property - Ready on enabled
/* =================================================================================== */

// uint32_t - Ready on enabled

/**
 Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 */
@property (nonatomic, assign) DLABPixelFormat pixelFormatW;

/**
 Additional flag of video input (i.e. DLABVideoInputFlagEnableFormatDetection)
 */
@property (nonatomic, assign) DLABVideoInputFlag inputFlagW;

/**
 Additional flag of video output (i.e. DLABVideoOutputFlagVANC)
 */
@property (nonatomic, assign) DLABVideoOutputFlag outputFlagW;

/**
 Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 */
@property (nonatomic, assign) DLABDisplayModeSupportFlag1011 displayModeSupportW __attribute__((deprecated));

/* =================================================================================== */
// MARK: Property - Ready on streaming
/* =================================================================================== */

// long - ready on streaming

/**
 Length of row buffer in bytes.
 */
@property (nonatomic, assign) long rowBytesW;

/* =================================================================================== */
// MARK: Property - populate by buildVideoFormatDescription
/* =================================================================================== */

/**
 Video FormatDescription CFObject. Call -(BOOL)buildVideoFormatDescription to populate this.
 */
@property (nonatomic, assign, nullable) CMVideoFormatDescriptionRef videoFormatDescriptionW;

/* =================================================================================== */
// MARK: Private methods
/* =================================================================================== */

/**
 Refresh input VideoSetting/VideoFormatDescription using first input VideoFrame

 @param videoFrame input VideoFrame as source
 @return YES if no error, NO if failed
 */
- (BOOL) updateInputVideoFormatDescriptionUsingVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame;

@end

NS_ASSUME_NONNULL_END
