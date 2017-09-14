//
//  DLABVideoSetting.h
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
 DLABVideoSetting is a container related to Video Input/Output settings.
 
 You have to ask DLABDevice to create new videoSetting object using:
 - createOutputVideoSettingOfDisplayMode:pixelFormat:outputFlag:supportedAs:error:
 - createInputVideoSettingOfDisplayMode:pixelFormat:inputFlag:supportedAs:error:
 
 // pixel format
 //   CoreVideo compatible pixelformats are limited to following:
 //     bmdFormat8BitYUV, bmdFormat10BitYUV,
 //     bmdFormat8BitARGB, bmdFormat8BitBGRA
 //   10bit/12Bit RGB formats are not compatible - manual conversion is required
 */
@interface DLABVideoSetting : NSObject <NSCopying>

- (instancetype) init NS_UNAVAILABLE;

/* =================================================================================== */
// MARK: Property - Ready on init
/* =================================================================================== */

// long - Ready on init

/**
 Rectangle horizontal size in pixel.
 */
@property (nonatomic, assign, readonly) long width;
/**
 Rectangle vertical size in pixel.
 */
@property (nonatomic, assign, readonly) long height;

// NSString - Ready on init

/**
 IDeckLinkDisplayMode::GetName
 */
@property (nonatomic, copy, readonly) NSString* name;

// int64_t - Ready on init

/**
 Duration value of one sample in timeScale.
 */
@property (nonatomic, assign, readonly) DLABTimeValue duration;

/**
 Resolution value of one sample between one second.
 */
@property (nonatomic, assign, readonly) DLABTimeScale timeScale;

// uint32_t - Ready on init

/**
 Video stream categoly (i.e. DLABDisplayModeNTSC, DLABDisplayModeHD1080i5994)
 
 * This parameter represents visual resolution, interlace/progressive, and frame rate.
 */
@property (nonatomic, assign, readonly) DLABDisplayMode displayMode;

/**
 Field dominance value (i.e. DLABFieldDominanceLowerFieldFirst)
 */
@property (nonatomic, assign, readonly) DLABFieldDominance fieldDominance;

/**
 Additional flag of displayMode (i.e. DLABDisplayModeFlagColorspaceRec709)
 */
@property (nonatomic, assign, readonly) DLABDisplayModeFlag displayModeFlag;

// BOOL - Ready on init

/**
 Convenience property if it represents HD resolution.
 */
@property (nonatomic, assign, readonly) BOOL isHD;

/**
 Convenience property if preferred timecode type is VITC.
 */
@property (nonatomic, assign, readonly) BOOL useVITC;

/**
 Convenience property if preferred timecode type is RP188.
 */
@property (nonatomic, assign, readonly) BOOL useRP188;

/* =================================================================================== */
// MARK: Property - Ready on enabled
/* =================================================================================== */

// uint32_t - Ready on enabled

/**
 Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 */
@property (nonatomic, assign, readonly) DLABPixelFormat pixelFormat;

/**
 Additional flag of video input (i.e. DLABVideoInputFlagEnableFormatDetection)
 */
@property (nonatomic, assign, readonly) DLABVideoInputFlag inputFlag;

/**
 Additional flag of video output (i.e. DLABVideoOutputFlagVANC)
 */
@property (nonatomic, assign, readonly) DLABVideoOutputFlag outputFlag;

/**
 Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 */
@property (nonatomic, assign, readonly) DLABDisplayModeSupportFlag displayModeSupport;

/* =================================================================================== */
// MARK: Property - Ready on streaming
/* =================================================================================== */

// long - ready on streaming

/**
 Length of row buffer in bytes.
 */
@property (nonatomic, assign, readonly) long rowBytes;

/* =================================================================================== */
// MARK: Property - populate by buildVideoFormatDescription
/* =================================================================================== */

/**
 Video FormatDescription CFObject. Call -(BOOL)buildVideoFormatDescription to populate this.
 */
@property (nonatomic, assign, readonly, nullable) CMVideoFormatDescriptionRef videoFormatDescription;

/* =================================================================================== */
// MARK: Public methods
/* =================================================================================== */

/**
 Dictionary from IDeckLinkDisplayMode object.

 @return NSDictionary with parameters from IDeckLinkDisplayMode Object.
 */
- (NSDictionary*) dictionaryOfDisplayModeObj;

/**
 Prepare Video FormatDescription CFObject from current parameters.

 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildVideoFormatDescription;

@end

NS_ASSUME_NONNULL_END
