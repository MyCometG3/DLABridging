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
        // Reset HDRMetadata cache to undefined state
        [self resetMetadata];
        
        // Get mutable MetadataExtensions of output frame
        IDeckLinkVideoFrameMutableMetadataExtensions* ext = NULL;
        HRESULT result = frame->QueryInterface(IID_IDeckLinkVideoFrameMutableMetadataExtensions, (void **)&ext);
        if (result != S_OK || !ext) {
            if (ext) ext->Release();
            return nil;
        }
        // Query and cache HDRMetadata
        [self fillMetadataUsingExtensions:ext];
        ext->Release();
        
        //
        _outputFrame = frame;
        _outputFrame->AddRef();
    }
    return self;
}

- (instancetype) initWithInputFrame:(IDeckLinkVideoFrame *) frame
{
    NSParameterAssert(frame);
    
    self = [super init];
    if (self) {
        // Reset HDRMetadata cache to undefined state
        [self resetMetadata];
        
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
        if (result != S_OK) {
            if (ext) ext->Release();
            return nil;
        }
        
        // Query and cache HDRMetadata
        [self fillMetadataUsingExtensions:ext];
        ext->Release();
        
        //
        _inputFrame = frame;
        _inputFrame->AddRef();
    }
    return self;
}

- (void)dealloc
{
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
    if (!( self.colorspace == object.colorspace )) return NO;
    if (!( self.hdrElectroOpticalTransferFunc == object.hdrElectroOpticalTransferFunc )) return NO;
    
    if (!( [self.dolbyVision isEqualToData:object.dolbyVision] )) return NO;
    
    if (!( self.hdrDisplayPrimariesRedX == object.hdrDisplayPrimariesRedX )) return NO;
    if (!( self.hdrDisplayPrimariesRedY == object.hdrDisplayPrimariesRedY )) return NO;
    if (!( self.hdrDisplayPrimariesGreenX == object.hdrDisplayPrimariesGreenX )) return NO;
    if (!( self.hdrDisplayPrimariesGreenY == object.hdrDisplayPrimariesGreenY )) return NO;
    if (!( self.hdrDisplayPrimariesBlueX == object.hdrDisplayPrimariesBlueX )) return NO;
    if (!( self.hdrDisplayPrimariesBlueY == object.hdrDisplayPrimariesBlueY )) return NO;
    if (!( self.hdrWhitePointX == object.hdrWhitePointX )) return NO;
    if (!( self.hdrWhitePointY == object.hdrWhitePointY )) return NO;
    if (!( self.hdrMaxDisplayMasteringLuminance == object.hdrMaxDisplayMasteringLuminance )) return NO;
    if (!( self.hdrMinDisplayMasteringLuminance == object.hdrMinDisplayMasteringLuminance )) return NO;
    if (!( self.hdrMaximumContentLightLevel == object.hdrMaximumContentLightLevel )) return NO;
    if (!( self.hdrMaximumFrameAverageLightLevel == object.hdrMaximumFrameAverageLightLevel )) return NO;
    
    return YES;
}

/* ================================================================================== */
// MARK: - Public accessor
/* ================================================================================== */

@dynamic colorspace;
@dynamic hdrElectroOpticalTransferFunc;

@dynamic dolbyVision;

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

/* ================================================================================== */
// MARK: - Private accessor
/* ================================================================================== */

@synthesize outputFrame = _outputFrame;
@synthesize inputFrame = _inputFrame;

/* ================================================================================== */
// MARK: - Private Utility
/* ================================================================================== */

/// Check if the input/output frame contains HDR metadata
- (BOOL)hasHDRMetadataFlag {
    IDeckLinkVideoFrame* targetFrame = self.outputFrame ? self.outputFrame : self.inputFrame;
    if (!targetFrame) return NO;
    
    uint32_t flags = targetFrame->GetFlags();
    bool hasFlag = (flags & bmdFrameContainsHDRMetadata);
    return hasFlag ? YES : NO;
}

/// Update HDR metadata presence flag of output frame
- (BOOL)applyFrameContainsHDRMetadataFlag:(BOOL)containsFlag {
    if (!self.outputFrame) return NO;
    
    HRESULT result = S_OK;
    uint32_t flags = self.outputFrame->GetFlags();
    if (containsFlag) {
        result = self.outputFrame->SetFlags(flags | bmdFrameContainsHDRMetadata);
    } else {
        result = self.outputFrame->SetFlags(flags & ~bmdFrameContainsHDRMetadata);
    }
    
    return result == S_OK ? YES : NO;
}

/// Invalidate all cached metadata
- (void)resetMetadata
{
    // Reset HDRMetadata cache
    _colorspace = -1;
    _hdrElectroOpticalTransferFunc = -1;
    _dolbyVision = nil;
    _hdrDisplayPrimariesRedX = -1.0;
    _hdrDisplayPrimariesRedY = -1.0;
    _hdrDisplayPrimariesGreenX = -1.0;
    _hdrDisplayPrimariesGreenY = -1.0;
    _hdrDisplayPrimariesBlueX = -1.0;
    _hdrDisplayPrimariesBlueY = -1.0;
    _hdrWhitePointX = -1.0;
    _hdrWhitePointY = -1.0;
    _hdrMaxDisplayMasteringLuminance = -1.0;
    _hdrMinDisplayMasteringLuminance = -1.0;
    _hdrMaximumContentLightLevel = -1.0;
    _hdrMaximumFrameAverageLightLevel = -1.0;
}

/// Apply metadata cache to output frame
- (BOOL)applyMetadataUsingExtensions:(IDeckLinkVideoFrameMutableMetadataExtensions *)ext {
    NSParameterAssert(ext);
    
    HRESULT result = S_OK;
    
    int64_t int64Value = 0;
    double doubleValue = 0.0;
    NSData* dataValue = nil;
    
    int64Value = _colorspace;
    if (int64Value >= 0) {
        result = ext->SetInt(bmdDeckLinkFrameMetadataColorspace, int64Value);
        if (result != S_OK) return NO;
    }
    
    int64Value = _hdrElectroOpticalTransferFunc;
    if (int64Value >= 0) {
        result = ext->SetInt(bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc, int64Value);
        if (result != S_OK) return NO;
    }
    
    dataValue = _dolbyVision;
    if (dataValue && dataValue.length > 0) {
        result = ext->SetBytes(bmdDeckLinkFrameMetadataDolbyVision,
                               (void *)dataValue.bytes,
                               (uint32_t)dataValue.length);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesRedX;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesRedY;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesGreenX;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesGreenY;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesBlueX;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrDisplayPrimariesBlueY;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrWhitePointX;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRWhitePointX, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrWhitePointY;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRWhitePointY, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrMaxDisplayMasteringLuminance;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrMinDisplayMasteringLuminance;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrMaximumContentLightLevel;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel, doubleValue);
        if (result != S_OK) return NO;
    }
    
    doubleValue = _hdrMaximumFrameAverageLightLevel;
    if (doubleValue >= 0.0) {
        result = ext->SetFloat(bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel, doubleValue);
        if (result != S_OK) return NO;
    }
    
    // Ensure output frame has bmdFrameContainsHDRMetadata flag
    HRESULT hr = [self applyFrameContainsHDRMetadataFlag:YES];
    
    return hr == S_OK ? YES : NO;
}

/// Query and cache metadata
- (void)fillMetadataUsingExtensions:(IDeckLinkVideoFrameMetadataExtensions *)ext {
    NSParameterAssert(ext);
    
    if (![self hasHDRMetadataFlag]) {
        return;
    }
    
    HRESULT result = S_OK;
    int64_t* pInt64 = NULL;
    double* pDouble = NULL;
    
    pInt64 = &_colorspace;
    result = ext->GetInt(bmdDeckLinkFrameMetadataColorspace, pInt64);
    if (result != S_OK) *pInt64 = -1;
    
    pInt64 = &_hdrElectroOpticalTransferFunc;
    result = ext->GetInt(bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc, pInt64);
    if (result != S_OK) *pInt64 = -1;
    
    uint32_t bufferSize = 0;
    result = ext->GetBytes(bmdDeckLinkFrameMetadataDolbyVision, nullptr, &bufferSize);
    if (SUCCEEDED(result) && bufferSize > 0) {
        NSMutableData *mutableData = [NSMutableData dataWithLength:bufferSize];
        if (mutableData) {
            result = ext->GetBytes(bmdDeckLinkFrameMetadataDolbyVision,
                                   mutableData.mutableBytes, &bufferSize);
            if (SUCCEEDED(result)) {
                _dolbyVision = [NSData dataWithData:mutableData];
            } else {
                _dolbyVision = nil;
            }
        } else {
            _dolbyVision = nil;
        }
    } else {
        _dolbyVision = nil;
    }
    
    pDouble = &_hdrDisplayPrimariesRedX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrDisplayPrimariesRedY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrDisplayPrimariesGreenX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrDisplayPrimariesGreenY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrDisplayPrimariesBlueX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrDisplayPrimariesBlueY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrWhitePointX;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRWhitePointX, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrWhitePointY;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRWhitePointY, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrMaxDisplayMasteringLuminance;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrMinDisplayMasteringLuminance;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrMaximumContentLightLevel;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel, pDouble);
    if (result != S_OK) *pDouble = -1;
    
    pDouble = &_hdrMaximumFrameAverageLightLevel;
    result = ext->GetFloat(bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel, pDouble);
    if (result != S_OK) *pDouble = -1;
}

/* ================================================================================== */
// MARK: - Public Utility
/* ================================================================================== */

// For input/output: Perform bulk extraction of metadata from input or output frame
- (BOOL)readMetadataFromFrame
{
    // Get MetadataExtensions of input or output frame
    IDeckLinkVideoFrameMetadataExtensions* ext = NULL;
    {
        IDeckLinkVideoFrame* targetFrame = self.outputFrame ? self.outputFrame : self.inputFrame;
        if (!targetFrame) return NO;
        
        HRESULT result = targetFrame->QueryInterface(IID_IDeckLinkVideoFrameMetadataExtensions, (void **)&ext);
        // _v11_5.h
        if (result != S_OK) {
            result = targetFrame->QueryInterface(IID_IDeckLinkVideoFrameMetadataExtensions_v11_5, (void **)&ext);
        }
        
        if (result != S_OK || !ext) {
            if (ext) ext->Release();
            return NO;
        }
    }
    
    // Query and cache HDRMetadata
    [self fillMetadataUsingExtensions:ext];
    ext->Release();
    
    return YES;
}

// For output: Apply metadata in bulk to output frame
- (BOOL)writeMetadataToFrame
{
    // Get Mutable MetadataExtensions of output frame
    IDeckLinkVideoFrameMutableMetadataExtensions* ext = NULL;
    {
        IDeckLinkMutableVideoFrame* targetFrame = self.outputFrame;
        if (!targetFrame) return NO;
        
        HRESULT result = targetFrame->QueryInterface(IID_IDeckLinkVideoFrameMutableMetadataExtensions, (void **)&ext);
        if (result != S_OK || !ext) {
            if (ext) ext->Release();
            return NO;
        }
    }
    
    // Apply HDRMetadata cache to output frame
    BOOL result = [self applyMetadataUsingExtensions:ext];
    ext->Release();
    
    return result;
}

/*
 kCVImageBufferTransferFunction_ITU_R_2100_HLG      // HLG
 kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ    // PQ
 kCVImageBufferTransferFunction_ITU_R_709_2         // HDR
 kCVImageBufferTransferFunction_ITU_R_2020          // HDR
 */

// For output: Update TransferFunction metadata
- (BOOL)applyTransferFunction:(CFStringRef) transferFunctionKey
{
    NSParameterAssert(transferFunctionKey);
    
    if (!_outputFrame) return NO;
    
    if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG)) {
        _hdrElectroOpticalTransferFunc = 3;
        return YES;
    }
    else if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)) {
        _hdrElectroOpticalTransferFunc = 2;
        return YES;
    }
    else if (CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2) ||
             CFEqual(transferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2020)) {
        _hdrElectroOpticalTransferFunc = 1;
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

// For output: Update ColorPrimaries metadata
- (BOOL)applyColorPrimaries:(CFStringRef) colorPrimariesKey
{
    NSParameterAssert(colorPrimariesKey);
    
    if (!_outputFrame) return NO;
    
    if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020)) {
        // UHDTV, D65, Wide
        _hdrDisplayPrimariesRedX    = 0.708;
        _hdrDisplayPrimariesRedY    = 0.292;
        _hdrDisplayPrimariesGreenX  = 0.170;
        _hdrDisplayPrimariesGreenY  = 0.797;
        _hdrDisplayPrimariesBlueX   = 0.131;
        _hdrDisplayPrimariesBlueY   = 0.046;
        _hdrWhitePointX             = 0.3127;
        _hdrWhitePointY             = 0.3290;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_P3_D65)) {
        // P3-D65 (Display), Wide
        _hdrDisplayPrimariesRedX    = 0.680;
        _hdrDisplayPrimariesRedY    = 0.320;
        _hdrDisplayPrimariesGreenX  = 0.265;
        _hdrDisplayPrimariesGreenY  = 0.690;
        _hdrDisplayPrimariesBlueX   = 0.150;
        _hdrDisplayPrimariesBlueY   = 0.060;
        _hdrWhitePointX             = 0.3127;
        _hdrWhitePointY             = 0.3290;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_DCI_P3)) {
        //P3-DCI (Theater), Wide
        _hdrDisplayPrimariesRedX    = 0.680;
        _hdrDisplayPrimariesRedY    = 0.320;
        _hdrDisplayPrimariesGreenX  = 0.265;
        _hdrDisplayPrimariesGreenY  = 0.690;
        _hdrDisplayPrimariesBlueX   = 0.150;
        _hdrDisplayPrimariesBlueY   = 0.060;
        _hdrWhitePointX             = 0.3140;
        _hdrWhitePointY             = 0.3510;
        return YES;
    }
    else if (CFEqual(colorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2)) {
        // HDTV, D65, CRT
        _hdrDisplayPrimariesRedX    = 0.640;
        _hdrDisplayPrimariesRedY    = 0.330;
        _hdrDisplayPrimariesGreenX  = 0.300;
        _hdrDisplayPrimariesGreenY  = 0.600;
        _hdrDisplayPrimariesBlueX   = 0.150;
        _hdrDisplayPrimariesBlueY   = 0.060;
        _hdrWhitePointX             = 0.3127;
        _hdrWhitePointY             = 0.3290;
        return YES;
    }
    return NO;
}

/* ================================================================================== */
// MARK: - Public Accessor
/* ================================================================================== */

// readwrite - colorspace
- (int64_t)colorspace {
    return _colorspace;
}
- (void)setColorspace:(int64_t)value {
    if (!_outputFrame) return;
    _colorspace = value;
}

// readwrite - hdrElectroOpticalTransferFunc
- (int64_t)hdrElectroOpticalTransferFunc {
    return _hdrElectroOpticalTransferFunc;
}
- (void)setHdrElectroOpticalTransferFunc:(int64_t)value {
    if (!_outputFrame) return;
    _hdrElectroOpticalTransferFunc = MIN(MAX(value, 0), 7);
}

// readwrite - dolbyVision
- (NSData*)dolbyVision {
    if (!_dolbyVision) return nil;
    NSData* data = [NSData dataWithData:_dolbyVision];
    return data;
}
- (void)setDolbyVision:(NSData*)value {
    if (!_outputFrame) return;
    if (value == nil || value.length == 0) {
        _dolbyVision = nil;
    } else {
        NSData* data = [NSData dataWithData:value];
        _dolbyVision = data;
    }
}

// readwrite - hdrDisplayPrimariesRedX
- (double)hdrDisplayPrimariesRedX {
    return _hdrDisplayPrimariesRedX;
}
- (void)setHdrDisplayPrimariesRedX:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesRedX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesRedY
- (double)hdrDisplayPrimariesRedY {
    return _hdrDisplayPrimariesRedY;
}
- (void)setHdrDisplayPrimariesRedY:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesRedY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesGreenX
- (double)hdrDisplayPrimariesGreenX {
    return _hdrDisplayPrimariesGreenX;
}
- (void)setHdrDisplayPrimariesGreenX:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesGreenX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesGreenY
- (double)hdrDisplayPrimariesGreenY {
    return _hdrDisplayPrimariesGreenY;
}
- (void)setHdrDisplayPrimariesGreenY:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesGreenY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesBlueX
- (double)hdrDisplayPrimariesBlueX {
    return _hdrDisplayPrimariesBlueX;
}
- (void)setHdrDisplayPrimariesBlueX:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesBlueX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrDisplayPrimariesBlueY
- (double)hdrDisplayPrimariesBlueY {
    return _hdrDisplayPrimariesBlueY;
}
- (void)setHdrDisplayPrimariesBlueY:(double)value {
    if (!_outputFrame) return;
    _hdrDisplayPrimariesBlueY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrWhitePointX
- (double)hdrWhitePointX {
    return _hdrWhitePointX;
}
- (void)setHdrWhitePointX:(double)value {
    if (!_outputFrame) return;
    _hdrWhitePointX = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrWhitePointY
- (double)hdrWhitePointY {
    return _hdrWhitePointY;
}
- (void)setHdrWhitePointY:(double)value {
    if (!_outputFrame) return;
    _hdrWhitePointY = MIN(MAX(value, 0.0), 1.0);
}

// readwrite - hdrMaxDisplayMasteringLuminance
- (double)hdrMaxDisplayMasteringLuminance {
    return _hdrMaxDisplayMasteringLuminance;
}
- (void)setHdrMaxDisplayMasteringLuminance:(double)value {
    if (!_outputFrame) return;
    _hdrMaxDisplayMasteringLuminance = MIN(MAX(value, 1.0), 65535.0);
}

// readwrite - hdrMinDisplayMasteringLuminance
- (double)hdrMinDisplayMasteringLuminance {
    return _hdrMinDisplayMasteringLuminance;
}
- (void)setHdrMinDisplayMasteringLuminance:(double)value {
    if (!_outputFrame) return;
    _hdrMinDisplayMasteringLuminance = MIN(MAX(value, 0.0001), 6.5535);
}

// readwrite - hdrMaximumContentLightLevel
- (double)hdrMaximumContentLightLevel {
    return _hdrMaximumContentLightLevel;
}
- (void)setHdrMaximumContentLightLevel:(double)value {
    if (!_outputFrame) return;
    _hdrMaximumContentLightLevel = MIN(MAX(value, 1.0), 65535.0);
}

// readwrite - hdrMaximumFrameAverageLightLevel
- (double)hdrMaximumFrameAverageLightLevel {
    return _hdrMaximumFrameAverageLightLevel;
}
- (void)setHdrMaximumFrameAverageLightLevel:(double)value {
    if (!_outputFrame) return;
    _hdrMaximumFrameAverageLightLevel = MIN(MAX(value, 1.0), 65535.0);
}

@end
