//
//  DLABVideoConverter.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/04/07.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Accelerate/Accelerate.h>
#import "DeckLinkAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABVideoConverter : NSObject

/*
This converter supports RGBtoRGB conversion between DeckLink VideoFrame
and CoreVideo PixelBuffer. (No yuv support)
BMDPixelFormat12BitRGB/BMDPixelFormat12BitRGBLE are not supported yet.
*/

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
/// @discussion For example: CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020)
@property (nonatomic, assign, readonly, nullable) CGColorSpaceRef dlColorSpace;

/// CGColorspaceRef for CVPixelBuffer in kCGColorSpaceModelRGB
/// @discussion For example: CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020)
@property (nonatomic, assign, readonly, nullable) CGColorSpaceRef cvColorSpace;

/// Control strict color space conversion or suppose both ColorSpace are same.
/// @discussion use both cvColorSpace and dlColorSpace for colorSpace conversion
@property (nonatomic, assign) BOOL useDLColorSpace;

/// For Debugging purpose only; Set this before prepare.
@property (nonatomic, assign) BOOL useGammaSubstitute;

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
