//
//  DLABFrameMetadata+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/15.
//  Copyright © 2020-2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABFrameMetadata.h>
#import <DeckLinkAPI.h>

#import <DeckLinkAPI_v11_5.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLABFrameMetadata ()
{
    int64_t _colorspace;                        // bmdDeckLinkFrameMetadataColorspace
    int64_t _hdrElectroOpticalTransferFunc;     // bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc
    NSData* _dolbyVision;                       // bmdDeckLinkFrameMetadataDolbyVision
    double _hdrDisplayPrimariesRedX;            // bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX
    double _hdrDisplayPrimariesRedY;            // bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY
    double _hdrDisplayPrimariesGreenX;          // bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX
    double _hdrDisplayPrimariesGreenY;          // bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY
    double _hdrDisplayPrimariesBlueX;           // bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX
    double _hdrDisplayPrimariesBlueY;           // bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY
    double _hdrWhitePointX;                     // bmdDeckLinkFrameMetadataHDRWhitePointX
    double _hdrWhitePointY;                     // bmdDeckLinkFrameMetadataHDRWhitePointY
    double _hdrMaxDisplayMasteringLuminance;    // bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance
    double _hdrMinDisplayMasteringLuminance;    // bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance
    double _hdrMaximumContentLightLevel;        // bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel
    double _hdrMaximumFrameAverageLightLevel;   // bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel
}

- (nullable instancetype) initWithOutputFrame:(IDeckLinkMutableVideoFrame*) frame NS_DESIGNATED_INITIALIZER;
- (nullable instancetype) initWithInputFrame:(IDeckLinkVideoFrame*) frame NS_DESIGNATED_INITIALIZER;

// For Output (mutable)
@property (nonatomic, assign, nullable, readonly) IDeckLinkMutableVideoFrame* outputFrame;

// For Input (immutable)
@property (nonatomic, assign, nullable, readonly) IDeckLinkVideoFrame* inputFrame;

/* =================================================================================== */

/// Check if the input/output frame contains HDR metadata
- (BOOL)frameContainsHDRMetadataFlag;

/// Update HDR metadata presence flag of output frame
/// @param containsFlag YES if HDR metadata is present
- (BOOL)setFrameContainsHDRMetadataFlag:(BOOL)containsFlag;

/// Invalidate all cached metadata
- (void)resetMetadata;

/// Apply metadata cache to output frame
/// @param ext IDeckLinkVideoFrameMutableMetadataExtensions for output video frame
/// @return YES if succeeded
- (BOOL)writeMetadataUsingExtensions:(IDeckLinkVideoFrameMutableMetadataExtensions *)ext;

/// Query and cache metadata
/// @param ext IDeckLinkVideoFrameMetadataExtensions from input/output video frame
- (void)readMetadataUsingExtensions:(IDeckLinkVideoFrameMetadataExtensions *)ext;

@end

NS_ASSUME_NONNULL_END
