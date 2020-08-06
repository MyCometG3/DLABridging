//
//  DLABVideoSetting.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "DLABConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 DLABVideoSetting is a container related to Video Input/Output settings.
 
 You have to ask DLABDevice to create new videoSetting object using:
 - createOutputVideoSettingOfDisplayMode:pixelFormat:outputFlag:supportedAs:error:
 - createInputVideoSettingOfDisplayMode:pixelFormat:inputFlag:supportedAs:error:
 
 # CoreVideo compatible without conversion:
 DLABPixelFormat(8BitYUV/10BitYUV/8BitARGB/8BitBGRA)
 # Corevideo compatible with conversion: (experimental)
 DLABPixelFormat(10BitRGB/10BitRGBXLE/10BitRGBX)
 # Unsupported:
 DLABPixelFormat(12BitRGB/12BitRGBLE) and others
 
 */
@interface DLABVideoSetting : NSObject <NSCopying>

- (instancetype) init NS_UNAVAILABLE;

/* =================================================================================== */
// MARK: - Public Properties
/* =================================================================================== */

// NSString*

/**
 IDeckLinkDisplayMode::GetName
 */
@property (nonatomic, copy, readonly) NSString* name;

// int64_t

/**
 Duration value of one sample in timeScale.
 */
@property (nonatomic, assign, readonly) DLABTimeValue duration;

/**
 Resolution value of one sample between one second.
 */
@property (nonatomic, assign, readonly) DLABTimeScale timeScale;

// uint32_t

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

/**
 BytesPerRow for CVPixelFormat. Calculated by buildVideoFormatDescription.
 */
@property (nonatomic, assign, readonly) size_t cvRowBytes;

// BOOL

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

/**
 Additional flag of video input (i.e. DLABVideoInputFlagEnableFormatDetection)
 */
@property (nonatomic, assign, readonly) DLABVideoInputFlag inputFlag;

/**
 Additional flag of video output (i.e. DLABVideoOutputFlagVANC)
 */
@property (nonatomic, assign, readonly) DLABVideoOutputFlag outputFlag;

/* =================================================================================== */
// MARK: - Public Properties (Private ReadWrite)
/* =================================================================================== */

// long

/**
 Rectangle horizontal size in pixel.
 */
@property (nonatomic, assign, readonly) long width;
/**
 Rectangle vertical size in pixel.
 */
@property (nonatomic, assign, readonly) long height;

/**
 Length of row buffer in bytes.
 */
@property (nonatomic, assign, readonly) long rowBytes;

// uint32_t

/**
 Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 */
@property (nonatomic, assign, readonly) DLABPixelFormat pixelFormat;

// populate by buildVideoFormatDescription

/**
 Video FormatDescription CFObject. Call -(BOOL)buildVideoFormatDescription to populate this.
 */
@property (nonatomic, assign, readonly, nullable) CMVideoFormatDescriptionRef videoFormatDescription;

/**
 CMVideoFormatDescriptionExtension
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary* extensions;

/**
 CMVideoFormatDescriptionExtension without clap (for AVSampleBufferDisplayLayer)
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary* extensionsNoClap;

/* =================================================================================== */
// MARK: - Public properties
/* =================================================================================== */

/**
 Preferred CVPixelFormatType for CVPixelBuffer. Use buildVideoFormatDescription again after update.
 */
@property (nonatomic, assign) OSType cvPixelFormatType;


/* =================================================================================== */
// MARK: - Public methods
/* =================================================================================== */

/**
 Dictionary from IDeckLinkDisplayMode object.
 
 @return NSDictionary with parameters from IDeckLinkDisplayMode Object.
 */
- (NSDictionary*) dictionaryOfDisplayModeObj;

/**
 Prepare Video FormatDescription CFObject from current parameters.
 
 @param error Error description if failed.
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) buildVideoFormatDescriptionWithError:(NSError * _Nullable * _Nullable)error;

/**
 Add clean aperture (clap) VideoFormatDescriptionExtension to CVPixelBuffer.
 See kCMFormatDescriptionExtension_CleanAperture.
 
 @param clapWidthN Numerator of kCMFormatDescriptionKey_CleanApertureWidthRational
 @param clapWidthD Denominator of kCMFormatDescriptionKey_CleanApertureWidthRational
 @param clapHeightN Numerator of kCMFormatDescriptionKey_CleanApertureHeightRational
 @param clapHeightD Denominator of kCMFormatDescriptionKey_CleanApertureHeightRational
 @param clapHOffsetN Numerator of kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational
 @param clapHOffsetD Denominator of kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational
 @param clapVOffsetN Numerator of kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational
 @param clapVOffsetD Denominator of kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational
 @param error Error description if failed.
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) addClapExtOfWidthN:(int32_t)clapWidthN
                     widthD:(int32_t)clapWidthD
                    heightN:(int32_t)clapHeightN
                    heightD:(int32_t)clapHeightD
                   hOffsetN:(int32_t)clapHOffsetN
                   hOffsetD:(int32_t)clapHOffsetD
                   vOffsetN:(int32_t)clapVOffsetN
                   vOffsetD:(int32_t)clapVOffsetD
                      error:(NSError * _Nullable * _Nullable)error;

/**
 Add pixel aspect ratio (pasp) VideoFormatDescriptionExtension to CVPixelBuffer.
 See kCMFormatDescriptionExtension_PixelAspectRatio.
 
 @param paspHSpacing Value of kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing
 @param paspVSpacing Value of kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing
 @param error Error description if failed.
 @return YES if successfully populated. NO if failed with supplied parameters.
 */
- (BOOL) addPaspExtOfHSpacing:(uint32_t)paspHSpacing
                     vSpacing:(uint32_t)paspVSpacing
                        error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
