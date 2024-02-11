//
//  DLABVideoSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABVideoSetting.h>
#import <DLABDevice+Internal.h>

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
 @return Input Video Setting Object.
 */
- (nullable instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                                     pixelFormat:(BMDPixelFormat)pixelFormat
                                  videoInputFlag:(BMDVideoInputFlags)inputFlag;

/**
 Create DLABVideoSetting(Output) instance from IDeckLinkDisplayMode Object and required details.
 
 @param newDisplayModeObj IDeckLinkDisplayMode Object.
 @param pixelFormat Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 @param outputFlag Additional flag of video (i.e. DLABVideoOutputFlagVANC)
 @return Output Video Setting Object.
 */
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
// MARK: - Private properties
/* =================================================================================== */

/**
 IDeckLinkDisplayMode object.
 */
@property (nonatomic, assign, readonly) IDeckLinkDisplayMode* displayModeObj;

/* =================================================================================== */
// MARK: - Private Properties (Public Readonly)
/* =================================================================================== */

// long

/**
 Rectangle horizontal size in pixel.
 */
@property (nonatomic, assign) long widthW;

/**
 Rectangle vertical size in pixel.
 */
@property (nonatomic, assign) long heightW;

/**
 Length of row buffer in bytes.
 */
@property (nonatomic, assign) long rowBytesW;

// uint32_t

/**
 Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 */
@property (nonatomic, assign) DLABPixelFormat pixelFormatW;

// populated by buildVideoFormatDescriptionWithError:

/**
 Video FormatDescription CFObject. Call -(BOOL)buildVideoFormatDescription to populate this.
 */
@property (nonatomic, assign, nullable) CMVideoFormatDescriptionRef videoFormatDescriptionW;

/**
 CMVideoFormatDescriptionExtension
 */
@property (nonatomic, strong, nullable) NSDictionary* extensionsW;

/**
 CMVideoFormatDescriptionExtension without clap (for AVSampleBufferDisplayLayer)
 */
@property (nonatomic, strong, nullable) NSDictionary* extensionsNoClapW;


/* =================================================================================== */
// MARK: - Private properties
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
// MARK: - Private methods
/* =================================================================================== */

/**
 Refresh input VideoSetting/VideoFormatDescription using first input VideoFrame
 
 @param videoFrame input VideoFrame as source
 @return YES if no error, NO if failed
 */
- (BOOL) updateInputVideoFormatDescriptionUsingVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame;

@end

NS_ASSUME_NONNULL_END
