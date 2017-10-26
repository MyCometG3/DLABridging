//
//  DLABVideoSetting.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABVideoSetting+Internal.h"

NS_INLINE long rowBytesFor(BMDPixelFormat pixelFormat, long width) {
    long stride = 0;
    switch (pixelFormat) {
        case bmdFormat8BitYUV:
            stride = width * 16 / 8;
            break;
        case bmdFormat10BitYUV:
            stride = (width + 47) / 48 * 128;
            break;
        case bmdFormat8BitARGB:
        case bmdFormat8BitBGRA:
            stride = width * 32 / 8;
            break;
        default:
            break;
    }
    return stride;
}

@implementation DLABVideoSetting

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithDisplayModeObj:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
    return nil;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                            pixelFormat:(BMDPixelFormat)pixelFormat
                         videoInputFlag:(BMDVideoInputFlags)inputFlag
                     displayModeSupport:(BMDDisplayModeSupport)displayModeSupport
{
    NSParameterAssert(newDisplayModeObj && pixelFormat && displayModeSupport);
    
    self = [self initWithDisplayModeObj:newDisplayModeObj];
    if (self) {
        _pixelFormatW = (DLABPixelFormat)pixelFormat;
        _inputFlagW = (DLABVideoInputFlag)inputFlag;
        _displayModeSupportW = (DLABDisplayModeSupportFlag)displayModeSupport;
        _rowBytesW = rowBytesFor(pixelFormat, _widthW);
        
        _useVITCW = !_isHDW;
        _useRP188W = _isHDW;
    }
    return self;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                            pixelFormat:(BMDPixelFormat)pixelFormat
                        videoOutputFlag:(BMDVideoOutputFlags)outputFlag
                     displayModeSupport:(BMDDisplayModeSupport)displayModeSupport
{
    NSParameterAssert(newDisplayModeObj && pixelFormat && displayModeSupport);
    
    self = [self initWithDisplayModeObj:newDisplayModeObj];
    if (self) {
        _pixelFormatW = (DLABPixelFormat)pixelFormat;
        _outputFlagW = (DLABVideoOutputFlag)outputFlag;
        _displayModeSupportW = (DLABDisplayModeSupportFlag)displayModeSupport;
        _rowBytesW = rowBytesFor(pixelFormat, _widthW);
        
        _useVITCW = !_isHDW && (_outputFlagW & bmdVideoOutputVITC);
        _useRP188W = _isHDW && (_outputFlagW & bmdVideoOutputRP188);
    }
    return self;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
{
    NSParameterAssert(newDisplayModeObj);
    
    self = [super init];
    if (self) {
        // Retain
        _displayModeObj = newDisplayModeObj;
        _displayModeObj->AddRef();

        // get properties
        HRESULT result = E_FAIL;
        
        // long
        _widthW = _displayModeObj->GetWidth();
        _heightW = _displayModeObj->GetHeight();
        
        // NSString*
        _nameW = @"unknown";
        CFStringRef cfvalue = NULL;
        result = _displayModeObj->GetName(&cfvalue);
        if (result) {
            // ignore error
        } else {
            _nameW = CFBridgingRelease(cfvalue);
        }
        
        // int64_t
        _durationW = 0;
        _timeScaleW = 0;
        result = _displayModeObj->GetFrameRate(&_durationW, &_timeScaleW);
        if (result) {
            // ignore error
        }
        
        // uint32_t
        _displayModeW = (DLABDisplayMode) _displayModeObj->GetDisplayMode();
        _fieldDominanceW = (DLABFieldDominance) _displayModeObj->GetFieldDominance();
        _displayModeFlagW = (DLABDisplayModeSupportFlag) _displayModeObj->GetFlags();
        
        //
        switch (_displayModeW) {
            case DLABDisplayModeNTSC:
            case DLABDisplayModeNTSC2398:
            case DLABDisplayModePAL:
            case DLABDisplayModeNTSCp:
            case DLABDisplayModePALp:
                _isHDW = FALSE;
                break;
            default:
                _isHDW = TRUE;
        }
    }
    return self;
}

- (void) dealloc
{
    if (_videoFormatDescriptionW) {
        CFRelease(_videoFormatDescriptionW);
        _videoFormatDescriptionW = NULL;
    }
    if (_displayModeObj) {
        _displayModeObj->Release();
        _displayModeObj = NULL;
    }
}

// public comparison - NSObject
- (BOOL) isEqual:(id)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    return [self isEqualToVideoSetting:(DLABVideoSetting*)object];
}

// private comparison - DLABVideoSetting
- (BOOL) isEqualToVideoSetting:(DLABVideoSetting*)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    if (!( self.widthW == object.widthW )) return NO;
    if (!( self.heightW == object.heightW )) return NO;
    if (!( [self.nameW isEqualTo:object.nameW] )) return NO;
    
    if (!( self.durationW == object.durationW )) return NO;
    if (!( self.timeScaleW == object.timeScaleW )) return NO;
    
    if (!( self.displayModeW == object.displayModeW )) return NO;
    if (!( self.fieldDominanceW == object.fieldDominanceW )) return NO;
    if (!( self.displayModeFlagW == object.displayModeFlagW )) return NO;
    
    if (!( self.isHDW == object.isHDW )) return NO;
    if (!( self.useVITCW == object.useVITCW )) return NO;
    if (!( self.useRP188W == object.useRP188W )) return NO;
    
    if (!( self.clapReady == object.clapReady )) return NO;
    if (!( self.clapWidthN == object.clapWidthN )) return NO;
    if (!( self.clapWidthD == object.clapWidthD )) return NO;
    if (!( self.clapHeightN == object.clapHeightN )) return NO;
    if (!( self.clapHeightD == object.clapHeightD )) return NO;
    if (!( self.clapHOffsetN == object.clapHOffsetN )) return NO;
    if (!( self.clapHOffsetD == object.clapHOffsetD )) return NO;
    if (!( self.clapVOffsetN == object.clapVOffsetN )) return NO;
    if (!( self.clapVOffsetD == object.clapVOffsetD )) return NO;
    
    if (!( self.paspReady == object.paspReady )) return NO;
    if (!( self.paspHSpacing == object.paspHSpacing )) return NO;
    if (!( self.paspVSpacing == object.paspVSpacing )) return NO;
    
    if (!( self.pixelFormatW == object.pixelFormatW )) return NO;
    if (!( self.inputFlagW == object.inputFlagW )) return NO;
    if (!( self.outputFlagW == object.outputFlagW )) return NO;
    if (!( self.displayModeSupportW == object.displayModeSupportW )) return NO;
    
    if (!( self.rowBytesW == object.rowBytesW )) return NO;
    
    if (!CFEqual(self.videoFormatDescriptionW, object.videoFormatDescriptionW)) return NO;
    
    return YES;
}

// NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone
{
    DLABVideoSetting* obj = [[DLABVideoSetting alloc] initWithDisplayModeObj:self.displayModeObj];
    if (obj) {
        // copy public properties
        obj.isHDW = self.isHDW;
        obj.useVITCW = self.useVITCW;
        obj.useRP188W = self.useRP188W;
        
        obj.clapReady = self.clapReady;
        obj.clapWidthN = self.clapWidthN;
        obj.clapWidthD = self.clapWidthD;
        obj.clapHeightN = self.clapHeightN;
        obj.clapHeightD = self.clapHeightD;
        obj.clapHOffsetN = self.clapHOffsetN;
        obj.clapHOffsetD = self.clapHOffsetD;
        obj.clapVOffsetN = self.clapVOffsetN;
        obj.clapVOffsetD = self.clapVOffsetD;
        
        obj.paspReady = self.paspReady;
        obj.paspHSpacing = self.paspHSpacing;
        obj.paspVSpacing = self.paspVSpacing;
        
        obj.pixelFormatW = self.pixelFormatW;
        obj.inputFlagW = self.inputFlagW;
        obj.outputFlagW = self.outputFlagW;
        obj.displayModeSupportW = self.displayModeSupportW;
        obj.rowBytesW = self.rowBytesW;
        
        // private properties
        if (obj.videoFormatDescription) {
            [obj buildVideoFormatDescription];
        }
    }
    return obj;
}

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

- (BOOL) post:(NSString*)description
       reason:(NSString*)failureReason
         code:(NSInteger)result
           to:(NSError**)error;
{
    if (error) {
        if (!description) description = @"unknown description";
        if (!failureReason) failureReason = @"unknown failureReason";
        
        NSString *domain = @"com.MyCometG3.DLABridging.ErrorDomain";
        NSInteger code = (NSInteger)result;
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description,
                                   NSLocalizedFailureReasonErrorKey : failureReason,};
        *error = [NSError errorWithDomain:domain code:code userInfo:userInfo];
        return YES;
    }
    return NO;
}

/* =================================================================================== */
// MARK: - synthesized accessors
/* =================================================================================== */

// private synthesize
@synthesize widthW = _widthW;
@synthesize heightW = _heightW;
@synthesize nameW = _nameW;
@synthesize durationW = _durationW;
@synthesize timeScaleW = _timeScaleW;
@synthesize displayModeW = _displayModeW;
@synthesize fieldDominanceW = _fieldDominanceW;
@synthesize displayModeFlagW = _displayModeFlagW;
@synthesize pixelFormatW = _pixelFormatW;
@synthesize inputFlagW = _inputFlagW;
@synthesize outputFlagW = _outputFlagW;
@synthesize displayModeSupportW = _displayModeSupportW;
@synthesize rowBytesW = _rowBytesW;
@synthesize videoFormatDescriptionW = _videoFormatDescriptionW;
@synthesize isHDW = _isHDW;
@synthesize useVITCW = _useVITCW;
@synthesize useRP188W = _useRP188W;

/* =================================================================================== */
// MARK: - accessors
/* =================================================================================== */

// public readonly accessors
- (long) width { return _widthW; }
- (long) height { return _heightW; }
- (NSString*) name { return _nameW; }

- (DLABTimeValue) duration { return _durationW; }
- (DLABTimeScale) timeScale { return _timeScaleW; }
- (DLABDisplayMode) displayMode { return _displayModeW; }
- (DLABFieldDominance) fieldDominance { return _fieldDominanceW; }
- (DLABDisplayModeFlag) displayModeFlag { return _displayModeFlagW; }
- (DLABPixelFormat) pixelFormat { return _pixelFormatW; }
- (DLABVideoInputFlag) inputFlag { return _inputFlagW; }
- (DLABVideoOutputFlag) outputFlag { return _outputFlagW; }
- (DLABDisplayModeSupportFlag) displayModeSupport { return _displayModeSupportW; }
- (long) rowBytes { return _rowBytesW; }
- (CMVideoFormatDescriptionRef) videoFormatDescription { return _videoFormatDescriptionW; }
- (BOOL) isHD { return _isHDW; }
- (BOOL) useVITC { return _useVITCW; }
- (BOOL) useRP188 { return _useRP188W; }

- (void)setVideoFormatDescriptionW:(CMVideoFormatDescriptionRef)newFormatDescription
{
    if (_videoFormatDescriptionW == newFormatDescription) return;
    if (_videoFormatDescriptionW) {
        CFRelease(_videoFormatDescriptionW);
        _videoFormatDescriptionW = NULL;
    }
    if (newFormatDescription) {
        CFRetain(newFormatDescription);
        _videoFormatDescriptionW = newFormatDescription;
    }
}

/* =================================================================================== */
// MARK: - Public methods
/* =================================================================================== */

// public dictionary conversion
- (NSDictionary*) dictionaryOfDisplayModeObj
{
    // NSValue<pointer>
    NSValue* obj = [NSValue valueWithPointer:self.displayModeObj];
    
    // long
    long width = self.widthW;
    long height = self.heightW;
    long rowBytes = self.rowBytesW;
    
    // NSString*
    NSString* name = self.nameW;
    
    // int64_t
    DLABTimeValue duration = self.durationW;
    DLABTimeScale timeScale = self.timeScaleW;
    
    // uint32_t
    DLABDisplayMode displayMode = self.displayModeW;
    DLABFieldDominance fieldDominance = self.fieldDominanceW;
    DLABDisplayModeFlag displayModeFlag = self.displayModeFlagW;
    
    DLABPixelFormat pixelFormat = self.pixelFormatW;
    DLABVideoInputFlag inputFlag = self.inputFlagW;
    DLABVideoOutputFlag outputFlag = self.outputFlagW;
    DLABDisplayModeSupportFlag displayModeSupport = self.displayModeSupportW;
    
    NSDictionary *displayModeDictionary = @{@"objIdentifier" : obj,
                                            @"width" : @(width),
                                            @"height" : @(height),
                                            @"name" : name,
                                            @"frameRateDuration" : @(duration),
                                            @"frameRateScale" : @(timeScale),
                                            @"displayMode" : @(displayMode),
                                            @"fieldDominance" : @(fieldDominance),
                                            @"displayModeFlag" : @(displayModeFlag),
                                            @"pixelFormat" : @(pixelFormat),
                                            @"inputFlag" : @(inputFlag),
                                            @"outputFlag" : @(outputFlag),
                                            @"displayModeSupport" : @(displayModeSupport),
                                            @"rowBytes" : @(rowBytes),
                                            };
    return displayModeDictionary;
}

- (BOOL) buildVideoFormatDescription
{
    OSStatus err = noErr;
    CMFormatDescriptionRef formatDescription = NULL;
    {
        // long
        long width = self.widthW;
        long height = self.heightW;
        long rowBytes = self.rowBytesW;
        
        // pixel format
        BMDPixelFormat pixelFormat = self.pixelFormatW;    //uint32_t
        
        //
        BOOL ready = false;
        if (width && height && rowBytes && pixelFormat) {
            ready = true;
        } else {
            NSLog(@"ERROR: Unsupported setting detected.");
        }
        
        BOOL yuvColorSpace = false;
        if (ready) {
            switch (pixelFormat) {
                case bmdFormat8BitYUV:
                case bmdFormat10BitYUV:
                    yuvColorSpace = true;
                    ready = true;
                    break;
                case bmdFormat8BitARGB:
                case bmdFormat8BitBGRA:
                    yuvColorSpace = false;
                    ready = true;
                    break;
                default:
                    ready = false;
                    break;
            }
        }
        
        NSMutableDictionary *extensions = [NSMutableDictionary dictionary];
        if (ready && yuvColorSpace) {
            // Color space
            NSString* keyMatrix = (__bridge NSString*)kCMFormatDescriptionExtension_YCbCrMatrix;
            NSString* matrix709 = (__bridge NSString*)kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2;
            NSString* matrix601 = (__bridge NSString*)kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4;
            
            NSString* keyPrimary = (__bridge NSString*)kCMFormatDescriptionExtension_ColorPrimaries;
            NSString* primITUR709 = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_ITU_R_709_2;
            NSString* primSMPTEC = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_SMPTE_C;
            NSString* primEBU3213 = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_EBU_3213;
            
            NSString* keyXfer = (__bridge NSString*)kCMFormatDescriptionExtension_TransferFunction;
            NSString* xfer709 = (__bridge NSString*)kCMFormatDescriptionTransferFunction_ITU_R_709_2;
            
            // prefer displayModeFlag's colorspace information if specified
            BMDDisplayModeFlags displayModeFlag = self.displayModeFlagW;
            NSString* frameMatrix = nil;
            if (displayModeFlag & bmdDisplayModeColorspaceRec601) {
                frameMatrix = matrix601;
            }
            if (displayModeFlag & bmdDisplayModeColorspaceRec709) {
                frameMatrix = matrix709;
            }
            
            // apply color information (primary/transfer function/YCbCrMatrix)
            if (height <= 525) {
                extensions[keyPrimary] = primSMPTEC;
                extensions[keyXfer] = xfer709;
                extensions[keyMatrix] = (frameMatrix ? frameMatrix : matrix601);
            } else if (height <= 625) {
                extensions[keyPrimary] = primEBU3213;
                extensions[keyXfer] = xfer709;
                extensions[keyMatrix] = (frameMatrix ? frameMatrix : matrix601);
            } else {
                extensions[keyPrimary] = primITUR709;
                extensions[keyXfer] = xfer709;
                extensions[keyMatrix] = (frameMatrix ? frameMatrix : matrix709);
            }
        }
        
        if (ready && self.clapReady) {
            // Clean Aperture
            NSString* keyClap = (__bridge NSString*)kCMFormatDescriptionExtension_CleanAperture;
            
            NSString* keyClapWidthR = (__bridge NSString*)kCMFormatDescriptionKey_CleanApertureWidthRational;
            NSString* keyClapHeightR = (__bridge NSString*)kCMFormatDescriptionKey_CleanApertureHeightRational;
            NSString* keyClapHOffsetR = (__bridge NSString*)kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational;
            NSString* keyClapVOffsetR = (__bridge NSString*)kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational;
            
            NSNumber* clapWidthN = @(self.clapWidthN);
            NSNumber* clapWidthD = @(self.clapWidthD);
            NSNumber* clapHeightN = @(self.clapHeightN);
            NSNumber* clapHeightD = @(self.clapHeightD);
            NSNumber* clapHOffsetN = @(self.clapHOffsetN);
            NSNumber* clapHOffsetD = @(self.clapHOffsetD);
            NSNumber* clapVOffsetN = @(self.clapVOffsetN);
            NSNumber* clapVOffsetD = @(self.clapVOffsetD);
            
            NSDictionary* valueClap = @{
                                        keyClapWidthR   : @[clapWidthN, clapWidthD],
                                        keyClapHeightR  : @[clapHeightN, clapHeightD],
                                        keyClapHOffsetR : @[clapHOffsetN, clapHOffsetD],
                                        keyClapVOffsetR : @[clapVOffsetN, clapVOffsetD],
                                        };
            extensions[keyClap] = valueClap;
        }
        
        if (ready && self.paspReady) {
            // Pixel Aspect Ratio
            NSString* keyPasp = (__bridge NSString*)kCMFormatDescriptionExtension_PixelAspectRatio;
            
            NSString* keyPaspHSpacing = (__bridge NSString*)kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing;
            NSString* keyPaspVSpacing = (__bridge NSString*)kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing;
            
            NSNumber* paspHSpacing = @(self.paspHSpacing);
            NSNumber* paspVSpacing = @(self.paspVSpacing);
            
            NSDictionary* valuePasp = @{
                                        keyPaspHSpacing : paspHSpacing,
                                        keyPaspVSpacing : paspVSpacing,
                                        };
            extensions[keyPasp] = valuePasp;
        }
        
        if (ready) {
            // format name (either rgb or yuv related name)
            NSString* keyFormatName = (__bridge NSString*)kCMFormatDescriptionExtension_FormatName;
            NSString* name = self.nameW;
            extensions[keyFormatName] = name;
            
            // stride (bytes per row)
            NSString* keyStride = (__bridge NSString*)kCMFormatDescriptionExtension_BytesPerRow;
            extensions[keyStride] = @(rowBytes);
            
            // gamma level (legacy)
            NSString* keyGamma = (__bridge NSString*)kCMFormatDescriptionExtension_GammaLevel;
            extensions[keyGamma] = @(2.2);
            
            // field dominance
            NSString* keyFieldCount = (__bridge NSString*)kCMFormatDescriptionExtension_FieldCount;
            NSString* keyFieldDetail = (__bridge NSString*)kCMFormatDescriptionExtension_FieldDetail;
            NSString* tempTopFirst = (__bridge NSString*)kCMFormatDescriptionFieldDetail_TemporalTopFirst;
            //NSString* tempBottomFirst = (__bridge NSString*)kCMFormatDescriptionFieldDetail_TemporalBottomFirst;
            NSString* spatTopEarly = (__bridge NSString*)kCMFormatDescriptionFieldDetail_SpatialFirstLineEarly;
            NSString* spatBotEarly = (__bridge NSString*)kCMFormatDescriptionFieldDetail_SpatialFirstLineLate;
            /*
             * SpatialFirstLine... are for "2 fields woven into a frame".
             * SpatialFirstLineLate (14) is suit for NTSC D1 source.
             * SpatialFirstLineEarly (9) is suit for any HD interlaced and PAL D1 source.
             * So Decompressed CMSampleBuffer is either progressive or spatialFistLineXXX.
             */

            BMDFieldDominance fieldDominance = self.fieldDominanceW;
            switch (fieldDominance) {
                case bmdLowerFieldFirst: // woven-fields representation
                    extensions[keyFieldCount] = @2;
                    extensions[keyFieldDetail] = spatBotEarly; // detail == 14
                    break;
                case bmdUpperFieldFirst: // woven-fields representation
                    extensions[keyFieldCount] = @2;
                    extensions[keyFieldDetail] = spatTopEarly; // detail == 9
                    break;
                case bmdProgressiveFrame:
                    extensions[keyFieldCount] = @1;
                    break;
                case bmdProgressiveSegmentedFrame: // split-fields representation
                    extensions[keyFieldCount] = @2;
                    extensions[keyFieldDetail] = tempTopFirst; // detail == 1
                    break;
                default:
                    break;
            }
        }
        
        if (ready) {
            // create format description
            err = CMVideoFormatDescriptionCreate(NULL,
                                                 (CMVideoCodecType)pixelFormat,
                                                 (int32_t)width,
                                                 (int32_t)height,
                                                 (__bridge CFDictionaryRef)extensions,
                                                 &formatDescription);
            if (!err) {
                self.videoFormatDescriptionW = formatDescription;
            }
        }
    }
    if (formatDescription) {
        CFRelease(formatDescription);
        return TRUE;
    } else {
        return FALSE;    // TODO handle err
    }
}

- (BOOL) addClapExtOfWidthN:(int32_t)clapWidthN
                     widthD:(int32_t)clapWidthD
                    heightN:(int32_t)clapHeightN
                    heightD:(int32_t)clapHeightD
                   hOffsetN:(int32_t)clapHOffsetN
                   hOffsetD:(int32_t)clapHOffsetD
                   vOffsetN:(int32_t)clapVOffsetN
                   vOffsetD:(int32_t)clapVOffsetD
                      error:(NSError**)error
{
    NSParameterAssert(clapWidthD && clapHeightD && clapHOffsetD && clapVOffsetD);
    
    double visibleWidth = (double)clapWidthN/clapWidthD;
    double visibleHeight = (double)clapHeightN/clapHeightD;
    double hOffset = (double)clapHOffsetN/clapHOffsetD;
    double vOffset = (double)clapVOffsetN/clapVOffsetD;
    
    double encWidth = (double)self.width;
    double encHeight = (double)self.height;
    double hFrame = (encWidth - visibleWidth) / 2.0;
    double vFrame = (encHeight - visibleHeight) / 2.0;
    
    if (visibleWidth > 0.0 && visibleWidth <= encWidth &&
        visibleHeight > 0.0 && visibleHeight <= encHeight &&
        hOffset >= -hFrame && hOffset <= hFrame &&
        vOffset >= -vFrame && vOffset <= vFrame)
    {
        self.clapWidthN = clapWidthN;     self.clapWidthD = clapWidthD;
        self.clapHeightN = clapHeightN;   self.clapHeightD = clapHeightD;
        self.clapHOffsetN = clapHOffsetN; self.clapHOffsetD = clapHOffsetD;
        self.clapVOffsetN = clapVOffsetN; self.clapVOffsetD = clapVOffsetD;
        self.clapReady = TRUE;
        
        if (self.videoFormatDescription) {
            [self buildVideoFormatDescription];
        }
        return TRUE;
    } else {
        self.clapReady = FALSE;
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported clap settins detected."
              code:E_INVALIDARG
                to:error];
        return FALSE;
    }
}

- (BOOL) addPaspExtOfHSpacing:(uint32_t)paspHSpacing
                     vSpacing:(uint32_t)paspVSpacing
                        error:(NSError**)error
{
    if (paspHSpacing > 0 && paspVSpacing > 0) {
        self.paspHSpacing = paspHSpacing;
        self.paspVSpacing = paspVSpacing;
        self.paspReady = TRUE;
        
        if (self.videoFormatDescription) {
            [self buildVideoFormatDescription];
        }
        return TRUE;
    } else {
        self.paspReady = FALSE;
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported pasp settins detected."
              code:E_INVALIDARG
                to:error];
        return FALSE;
    }
}

/* =================================================================================== */
// MARK: - Private methods
/* =================================================================================== */

// Use first inputVideoFrame to create inputVideoFormatDescription
- (BOOL) updateInputVideoFormatDescriptionUsingVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame
{
    NSParameterAssert(videoFrame);
    
    // check videoFrame paramters
    // long
    long width = videoFrame->GetWidth();
    long height = videoFrame->GetHeight();
    long rowBytes = videoFrame->GetRowBytes();
    
    // pixel format
    BMDPixelFormat pixelFormat = videoFrame->GetPixelFormat();    //uint32_t
    
    // unused
    // videoFrame->GetFlags()
    // videoFrame->GetBytes(...)
    // videoFrame->GetTimecode(...)
    // videoFrame->GetAncillaryData(...)
    // videoFrame->GetStreamTime(...)
    // videoFrame->GetHardwareReferenceTimestamp(...)
    
    //
    BOOL ready = false;
    if (width && height && rowBytes && pixelFormat) {
        ready = true;
    } else {
        NSLog(@"ERROR: Unsupported setting detected.");
    }
    
    if (ready) {
        // Keep original value
        // long
        long widthOrg = self.widthW;
        long heightOrg = self.heightW;
        long rowBytesOrg = self.rowBytesW;
        // pixel format
        DLABPixelFormat pixelFormatOrg = self.pixelFormatW;    //uint32_t
        
        // update parameters
        self.widthW = width;
        self.heightW = height;
        self.rowBytesW = rowBytes;
        self.pixelFormatW = (DLABPixelFormat)pixelFormat;
        
        // update videoFormatDescription using new values from videoFrame
        ready = [self buildVideoFormatDescription];
        
        if (!ready) {
            // revert parameters
            self.widthW = widthOrg;
            self.heightW = heightOrg;
            self.rowBytesW = rowBytesOrg;
            self.pixelFormatW = pixelFormatOrg;
        }
    }
    
    if (ready) {
        return TRUE;
    } else {
        return FALSE;    // TODO handle err
    }
}

@end
