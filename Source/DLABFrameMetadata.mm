//
//  DLABFrameMetadata.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/15.
//  Copyright © 2020-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABFrameMetadata+Internal.h>

@implementation DLABFrameMetadata

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithOutputFrame:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
    return nil;
}

- (instancetype) initWithOutputFrame:(IDeckLinkMutableVideoFrame*) frame
{
    NSParameterAssert(frame);
    
    self = [super init];
    if (self) {
        // reset metadata
        [self applyDefault];
        
        // Create metaFrame
        DLABMetaFrame* outMetaframe = new DLABMetaFrame(frame, metadata);
        if (outMetaframe) {
            _outputFrame = frame;
            _outputFrame->AddRef();
            
            _metaframe = outMetaframe;
        } else {
            self = nil;
        }
    }
    return self;
}

- (instancetype) initWithInputFrame:(IDeckLinkVideoFrame *) frame
{
    NSParameterAssert(frame);
    
    self = [super init];
    if (self) {
        // Verify input frame has HDRMetadata
        BMDFrameFlags inFlags = frame->GetFlags();
        bool hasHDRMetadata = (inFlags & bmdFrameContainsHDRMetadata);
        if (!hasHDRMetadata) return nil;
        
        // Get MetadataExtensions of input frame
        IDeckLinkVideoFrameMetadataExtensions* ext = NULL;
        HRESULT result = frame->QueryInterface(IID_IDeckLinkVideoFrameMetadataExtensions, (void **)&ext);
        // _v11_5.h
        if (result != S_OK) {
            result = frame->QueryInterface(IID_IDeckLinkVideoFrameMetadataExtensions_v11_5, (void **)&ext);
        }
        if (result == S_OK && ext) {
            _inputFrame = frame;
            _inputFrame->AddRef();
            
            // Query and fill HDRMetadata struct
            [self fillMetadataUsingExtensions:ext];
            ext->Release();
        } else {
            //
            if (ext) ext->Release();
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_metaframe) {
        _metaframe->Release();
    }
    if (_outputFrame) {
        _outputFrame->Release();
    }
    if (_inputFrame) {
        _inputFrame->Release();
    }
}

// public comparison - NSObject
- (BOOL) isEqual:(id)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    return [self isEqualToFrameMetadata:(DLABFrameMetadata*)object];
}

// private comparison - DLABAudioSetting
- (BOOL) isEqualToFrameMetadata:(DLABFrameMetadata*)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    // For output
    if (!( self.outputFrame == object.outputFrame )) return NO;
    // ignore: metaframe
    
    // For input
    if (!( self.inputFrame == object.inputFrame )) return NO;
    
    // HDRMetadata
    HDRMetadata src = self.metadata;
    HDRMetadata tgt = object.metadata;
    if (!( src.hdrElectroOpticalTransferFunc == tgt.hdrElectroOpticalTransferFunc )) return NO;
    if (!( src.hdrDisplayPrimariesRedX == tgt.hdrDisplayPrimariesRedX )) return NO;
    if (!( src.hdrDisplayPrimariesRedY == tgt.hdrDisplayPrimariesRedY )) return NO;
    if (!( src.hdrDisplayPrimariesGreenX == tgt.hdrDisplayPrimariesGreenX )) return NO;
    if (!( src.hdrDisplayPrimariesGreenY == tgt.hdrDisplayPrimariesGreenY )) return NO;
    if (!( src.hdrDisplayPrimariesBlueX == tgt.hdrDisplayPrimariesBlueX )) return NO;
    if (!( src.hdrDisplayPrimariesBlueY == tgt.hdrDisplayPrimariesBlueY )) return NO;
    if (!( src.hdrWhitePointX == tgt.hdrWhitePointX )) return NO;
    if (!( src.hdrWhitePointY == tgt.hdrWhitePointY )) return NO;
    if (!( src.hdrMaxDisplayMasteringLuminance == tgt.hdrMaxDisplayMasteringLuminance )) return NO;
    if (!( src.hdrMinDisplayMasteringLuminance == tgt.hdrMinDisplayMasteringLuminance )) return NO;
    if (!( src.hdrMaximumContentLightLevel == tgt.hdrMaximumContentLightLevel )) return NO;
    if (!( src.hdrMaximumFrameAverageLightLevel == tgt.hdrMaximumFrameAverageLightLevel )) return NO;
    
    return YES;
}

/* ================================================================================== */
// MARK: - Public accessor
/* ================================================================================== */

@dynamic hdrElectroOpticalTransferFunc;
@dynamic hdrDisplayPrimariesRedX;
@dynamic hdrDisplayPrimariesRedY;
@dynamic hdrDisplayPrimariesGreenX;
@dynamic hdrDisplayPrimariesGreenY;
@dynamic hdrDisplayPrimariesBlueX;
@dynamic hdrDisplayPrimariesBlueY;
@dynamic hdrWhitePointX;
@dynamic hdrWhitePointY;
@dynamic hdrMaxDisplayMasteringLuminance;
@dynamic hdrMinDisplayMasteringLuminance;
@dynamic hdrMaximumContentLightLevel;
@dynamic hdrMaximumFrameAverageLightLevel;
@dynamic colorspace;

/* ================================================================================== */
// MARK: - Private accessor
/* ================================================================================== */

@synthesize outputFrame = _outputFrame;
@synthesize metaframe = _metaframe;
@synthesize inputFrame = _inputFrame;
@synthesize metadata = metadata;

/* ================================================================================== */
// MARK: - Private Utility
/* ================================================================================== */

/// For input: fill metadata struct
/// @param ext MetadataExtensions from input video frame
- (void)fillMetadataUsingExtensions:(IDeckLinkVideoFrameMetadataExtensions *)ext {
    NSParameterAssert(ext);
    
    HRESULT result = S_OK;
    int64_t* pInt64 = NULL;
    double* pDouble = NULL;
    
    pInt64 = &metadata.hdrElectroOpticalTransferFunc;
    result = ext->GetInt(bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc, pInt64);
    if (result != S_OK) *pInt64 = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesRedX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesRedY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesGreenX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesGreenY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesBlueX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrDisplayPrimariesBlueY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrWhitePointX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRWhitePointX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrWhitePointY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRWhitePointY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrMaxDisplayMasteringLuminance;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrMinDisplayMasteringLuminance;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrMaximumContentLightLevel;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &metadata.hdrMaximumFrameAverageLightLevel;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel, pDouble);
    if (result != S_OK) *pDouble = -1;
}

/* ================================================================================== */
// MARK: - Private Accessor
/* ================================================================================== */

- (DLABMetaFrame*)metaframe {
    if (_metaframe) {
        _metaframe->UpdateHDRMetadata(metadata);
    }
    return _metaframe;
}

/* ================================================================================== */
// MARK: - Public Utility
/* ================================================================================== */

- (BOOL)applyDefault
{
    if (!_metaframe) return FALSE;
    
    [self applyTransferFunction:kCVImageBufferTransferFunction_ITU_R_709_2];
    [self applyColorPrimaries:kCVImageBufferColorPrimaries_ITU_R_2020];
    metadata.hdrMaxDisplayMasteringLuminance    = 1000.0;
    metadata.hdrMinDisplayMasteringLuminance    = 0.0001;
    metadata.hdrMaximumContentLightLevel        = 1000.0;
    metadata.hdrMaximumFrameAverageLightLevel   = 50.0;
    return TRUE;
}

/*
 kCVImageBufferTransferFunction_ITU_R_2100_HLG      // HLG
 kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ    // PQ
 kCVImageBufferTransferFunction_ITU_R_709_2         // HDR
 kCVImageBufferTransferFunction_ITU_R_2020          // HDR
 */

- (BOOL)applyTransferFunction:(CFStringRef) transferFunctionKey
{
    NSParameterAssert(transferFunctionKey);
    
    if (!_metaframe) return FALSE;
    
    if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG)) {
        metadata.hdrElectroOpticalTransferFunc = 3;
        return YES;
    }
    else if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)) {
        metadata.hdrElectroOpticalTransferFunc = 2;
        return YES;
    }
    else if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2) ||
             CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2020)) {
        metadata.hdrElectroOpticalTransferFunc = 1;
        return YES;
    }
    return NO;
}

/*
 kCVImageBufferColorPrimaries_ITU_R_2020    // HD-HDR
 kCVImageBufferColorPrimaries_P3_D65
 kCVImageBufferColorPrimaries_DCI_P3
 kCVImageBufferColorPrimaries_ITU_R_709_2   // HD
 */
- (BOOL)applyColorPrimaries:(CFStringRef) colorPrimariesKey
{
    NSParameterAssert(colorPrimariesKey);
    
    if (!_metaframe) return FALSE;
    
    if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020)) {
        // UHDTV, D65, Wide
        metadata.hdrDisplayPrimariesRedX    = 0.708;
        metadata.hdrDisplayPrimariesRedY    = 0.292;
        metadata.hdrDisplayPrimariesGreenX  = 0.170;
        metadata.hdrDisplayPrimariesGreenY  = 0.797;
        metadata.hdrDisplayPrimariesBlueX   = 0.131;
        metadata.hdrDisplayPrimariesBlueY   = 0.046;
        metadata.hdrWhitePointX             = 0.3127;
        metadata.hdrWhitePointY             = 0.3290;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_P3_D65)) {
        // P3-D65 (Display), Wide
        metadata.hdrDisplayPrimariesRedX    = 0.680;
        metadata.hdrDisplayPrimariesRedY    = 0.320;
        metadata.hdrDisplayPrimariesGreenX  = 0.265;
        metadata.hdrDisplayPrimariesGreenY  = 0.690;
        metadata.hdrDisplayPrimariesBlueX   = 0.150;
        metadata.hdrDisplayPrimariesBlueY   = 0.060;
        metadata.hdrWhitePointX             = 0.3127;
        metadata.hdrWhitePointY             = 0.3290;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_DCI_P3)) {
        //P3-DCI (Theater), Wide
        metadata.hdrDisplayPrimariesRedX    = 0.680;
        metadata.hdrDisplayPrimariesRedY    = 0.320;
        metadata.hdrDisplayPrimariesGreenX  = 0.265;
        metadata.hdrDisplayPrimariesGreenY  = 0.690;
        metadata.hdrDisplayPrimariesBlueX   = 0.150;
        metadata.hdrDisplayPrimariesBlueY   = 0.060;
        metadata.hdrWhitePointX             = 0.3140;
        metadata.hdrWhitePointY             = 0.3510;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2)) {
        // HDTV, D65, CRT
        metadata.hdrDisplayPrimariesRedX    = 0.640;
        metadata.hdrDisplayPrimariesRedY    = 0.330;
        metadata.hdrDisplayPrimariesGreenX  = 0.300;
        metadata.hdrDisplayPrimariesGreenY  = 0.600;
        metadata.hdrDisplayPrimariesBlueX   = 0.150;
        metadata.hdrDisplayPrimariesBlueY   = 0.060;
        metadata.hdrWhitePointX             = 0.3127;
        metadata.hdrWhitePointY             = 0.3290;
        return YES;
    }
    return NO;
}

/* ================================================================================== */
// MARK: - Public Accessor
/* ================================================================================== */

// readwrite - hdrElectroOpticalTransferFunc
- (int64_t)hdrElectroOpticalTransferFunc {
    return metadata.hdrElectroOpticalTransferFunc;
}
- (void)setHdrElectroOpticalTransferFunc:(int64_t)value {
    if (!_metaframe) return;
    metadata.hdrElectroOpticalTransferFunc = MIN(MAX(value, 0), 7);
}

// readwrite - hdrDisplayPrimariesRedX
- (double)hdrDisplayPrimariesRedX {
    return metadata.hdrDisplayPrimariesRedX;
}
- (void)setHdrDisplayPrimariesRedX:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesRedX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesRedY
- (double)hdrDisplayPrimariesRedY {
    return metadata.hdrDisplayPrimariesRedY;
}
- (void)setHdrDisplayPrimariesRedY:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesRedY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesGreenX
- (double)hdrDisplayPrimariesGreenX {
    return metadata.hdrDisplayPrimariesGreenX;
}
- (void)setHdrDisplayPrimariesGreenX:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesGreenX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesGreenY
- (double)hdrDisplayPrimariesGreenY {
    return metadata.hdrDisplayPrimariesGreenY;
}
- (void)setHdrDisplayPrimariesGreenY:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesGreenY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesBlueX
- (double)hdrDisplayPrimariesBlueX {
    return metadata.hdrDisplayPrimariesBlueX;
}
- (void)setHdrDisplayPrimariesBlueX:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesBlueX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesBlueY
- (double)hdrDisplayPrimariesBlueY {
    return metadata.hdrDisplayPrimariesBlueY;
}
- (void)setHdrDisplayPrimariesBlueY:(double)value {
    if (!_metaframe) return;
    metadata.hdrDisplayPrimariesBlueY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrWhitePointX
- (double)hdrWhitePointX {
    return metadata.hdrWhitePointX;
}
- (void)setHdrWhitePointX:(double)value {
    if (!_metaframe) return;
    metadata.hdrWhitePointX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrWhitePointY
- (double)hdrWhitePointY {
    return metadata.hdrWhitePointY;
}
- (void)setHdrWhitePointY:(double)value {
    if (!_metaframe) return;
    metadata.hdrWhitePointY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrMaxDisplayMasteringLuminance
- (double)hdrMaxDisplayMasteringLuminance {
    return metadata.hdrMaxDisplayMasteringLuminance;
}
- (void)setHdrMaxDisplayMasteringLuminance:(double)value {
    if (!_metaframe) return;
    metadata.hdrMaxDisplayMasteringLuminance = MIN(MAX(value, 1.0), 65535.0);
}

// readwrite - hdrMinDisplayMasteringLuminance
- (double)hdrMinDisplayMasteringLuminance {
    return metadata.hdrMinDisplayMasteringLuminance;
}
- (void)setHdrMinDisplayMasteringLuminance:(double)value {
    if (!_metaframe) return;
    metadata.hdrMinDisplayMasteringLuminance = MIN(MAX(value, 0.0001), 6.5535);
}

// readwrite - hdrMaximumContentLightLevel
- (double)hdrMaximumContentLightLevel {
    return metadata.hdrMaximumContentLightLevel;
}
- (void)setHdrMaximumContentLightLevel:(double)value {
    if (!_metaframe) return;
    metadata.hdrMaximumContentLightLevel = MIN(MAX(value, 1.0), 65535.0);
}

// readwrite - hdrMaximumFrameAverageLightLevel
- (double)hdrMaximumFrameAverageLightLevel {
    return metadata.hdrMaximumFrameAverageLightLevel;
}
- (void)setHdrMaximumFrameAverageLightLevel:(double)value {
    if (!_metaframe) return;
    metadata.hdrMaximumFrameAverageLightLevel = MIN(MAX(value, 1.0), 65535.0);
}

// readonly - colorspace
- (int64_t)colorspace
{
    // HDR required Rec2020 (fixed value)
    return (int64_t)bmdColorspaceRec2020;
}

@end
