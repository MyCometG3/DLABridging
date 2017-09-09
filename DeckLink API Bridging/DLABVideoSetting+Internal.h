//
//  DLABVideoSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABVideoSetting.h"
#import "DLABDevice+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABVideoSetting ()

- (nullable instancetype) init NS_UNAVAILABLE;

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
                              displayModeSupport:(BMDDisplayModeSupport)displayModeSupport;

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
                              displayModeSupport:(BMDDisplayModeSupport)displayModeSupport;

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
@property (nonatomic, assign) DLABDisplayModeSupportFlag displayModeSupportW;

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
