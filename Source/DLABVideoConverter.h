//
//  DLABVideoConverter.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/04/07.
//  Copyright © 2020-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Accelerate/Accelerate.h>
#import <DeckLinkAPI.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This converter supports colorspace conversion between DeckLink VideoFrame
 and CoreVideo PixelBuffer.
 
 @discussion
 - Supported: DLABPixelFormat(10BitRGB/10BitRGBXLE/10BitRGBX)
 
 - Experimental: DLABPixelFormat(12BitRGB/12BitRGBLE)
 */
@interface DLABVideoConverter : NSObject

/// init + prepare videoConverter for capture
/// @param videoFrame IDeckLinkVideoFrame
/// @param pixelBuffer CVPixelBuffer
- (nullable instancetype) initWithDL:(IDeckLinkVideoFrame*)videoFrame
                                toCV:(CVPixelBufferRef)pixelBuffer;
/// init + prepare videoConverter for playback
/// @param pixelBuffer CVPixelBuffer
/// @param videoFrame IDeckLinkVideoFrame
- (nullable instancetype) initWithCV:(CVPixelBufferRef)pixelBuffer
                                toDL:(IDeckLinkMutableVideoFrame*)videoFrame;

/* ================================================================ */
// MARK: - Properties
/* ================================================================ */

/// CGColorspaceRef for IDeckLinkVideoFrame in kCGColorSpaceModelRGB
/// @discussion To use default colorspace, set null before prepare.
/// @discussion To override default colorspace, set this before prepare.
@property (nonatomic, assign, nullable) CGColorSpaceRef dlColorSpace;

/// CGColorspaceRef for CVPixelBuffer in kCGColorSpaceModelRGB
/// @discussion To use default colorspace, set null before prepare.
/// @discussion To override default colorspace, set this before prepare.
@property (nonatomic, assign, nullable) CGColorSpaceRef cvColorSpace;

/// Allow colorspace conversion
/// @discussion Set true to respect both cvColorSpace and dlColorSpace
/// @discussion Set false to suppose both in same colorspace.
@property (nonatomic, assign) BOOL useDLColorSpace;

/// For Debugging purpose only; Set this before prepare.
@property (nonatomic, assign) BOOL useGammaSubstitute;

/// For Debugging purpose only; Use XRGB16U interimBuffer.
@property (nonatomic, assign) BOOL useXRGB16U;

/* ================================================================ */
// MARK: - Validate VideoFrame and CVPixelBuffer (optional)
/* ================================================================ */

/// Release all resources. Return to unprepared state.
- (void)cleanup;

/// Verify format compatibility with input/output frames. (optional)
/// @discussion This method always fail before prepared.
/// @param videoFrame IDeckLinkVideoFrame
/// @param pixelBuffer CVPixelBuffer
- (BOOL)compatibleWithDL:(IDeckLinkVideoFrame*)videoFrame
                   andCV:(CVPixelBufferRef)pixelBuffer;

/* ================================================================ */
// MARK: - VideoFrame (permute) dlHostBuffer (xfer) XRGB16U (convCGtoCV) CVPixelBuffer
/* ================================================================ */

/// Prepare interimBuffer and converter object
/// @discussion Call this method once at beginning
/// @param videoFrame IDeckLinkVideoFrame
/// @param pixelBuffer CVPixelBuffer
- (BOOL)prepareDL:(IDeckLinkVideoFrame*)videoFrame
             toCV:(CVPixelBufferRef)pixelBuffer;

/// Convert videoFrame into pixelBuffer
/// @discussion Call this method for every frame
/// @param videoFrame IDeckLinkVideoFrame
/// @param pixelBuffer CVPixelBuffer
- (BOOL)convertDL:(IDeckLinkVideoFrame*)videoFrame
             toCV:(CVPixelBufferRef)pixelBuffer;

/* ================================================================ */
// MARK: - CVPixelBuffer (convCVtoCG) XRGB16U (xfer) dlHostBuffer (permute) VideoFrame
/* ================================================================ */

/// Prepare interimBuffer and converter object
/// @discussion Call this method once at beginning
/// @param pixelBuffer CVPixelBuffer
/// @param videoFrame IDeckLinkVideoFrame
- (BOOL)prepareCV:(CVPixelBufferRef)pixelBuffer
             toDL:(IDeckLinkMutableVideoFrame*)videoFrame;

/// Convert pixelBuffer to videoFrame
/// @discussion Call this method for every frame
/// @param pixelBuffer CVPixelBuffer
/// @param videoFrame IDeckLinkVideoFrame
- (BOOL)convertCV:(CVPixelBufferRef)pixelBuffer
             toDL:(IDeckLinkMutableVideoFrame*)videoFrame;

@end

NS_ASSUME_NONNULL_END
