//
//  DLABFrameMetadata.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/15.
//  Copyright © 2020-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <DLABridging/DLABConstants.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLABFrameMetadata : NSObject

- (instancetype) init NS_UNAVAILABLE;

/* ================================================================================== */
// MARK: - Public Utility
/* ================================================================================== */

/**
 For input/output: Perform bulk extraction of metadata from input or output frame
 @result YES if no error. NO if unsupported.
 */
- (BOOL)readMetadataFromFrame;

/**
 For output: Apply metadata in bulk to output frame
 @result YES if no error. NO if unsupported.
 */
- (BOOL)writeMetadataToFrame;

/**
 For output: Update TransferFunction metadata
 @param transferFunctionKey kCVImageBufferTransferFunction_*
 @result YES if no error. NO if unsupported.
 */
- (BOOL)applyTransferFunction:(CFStringRef) transferFunctionKey;

/**
 For output: Update ColorPrimaries metadata
 @param colorPrimariesKey kCVImageBufferColorPrimaries_*
 @result YES if no error. NO if unsupported.
 */
- (BOOL)applyColorPrimaries:(CFStringRef) colorPrimariesKey;

/* ================================================================================== */
// MARK: - Public Accessor
/* ================================================================================== */

/// Colorspace of video frame (see DLABColorspace)
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) int64_t colorspace;
/// EOTF in range 0-7 as per CEA 861.3
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) int64_t hdrElectroOpticalTransferFunc;

/// Dolby Vision Metadata
/// @discussion For input: Readonly. nil if not available.
@property (nonatomic, copy, readwrite, nullable) NSData* dolbyVision;

/// Red display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesRedX;
/// Red display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesRedY;
/// Green display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesGreenX;
/// Green display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesGreenY;
/// Blue display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesBlueX;
/// Blue display primaries in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrDisplayPrimariesBlueY;
/// White point in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrWhitePointX;
/// White point in range 0.0 - 1.0
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrWhitePointY;
/// Max display mastering luminance in range 1 cd/ m2 - 65535 cd/m2
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrMaxDisplayMasteringLuminance;
/// Min display mastering luminance in range 0.0001 cd/m2 - 6.5535 cd/m2
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrMinDisplayMasteringLuminance;
/// Maximum Content Light Level in range 1 cd/m2 - 65535 cd/m2
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrMaximumContentLightLevel;
/// Maximum Frame Average Light Level in range 1 cd/m2 - 65535 cd/m2
/// @discussion For input: Readonly. -1 if not available.
@property (nonatomic, assign, readwrite) double hdrMaximumFrameAverageLightLevel;

@end

NS_ASSUME_NONNULL_END
