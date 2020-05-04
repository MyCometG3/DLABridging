//
//  DLABVideoSetting.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
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
        case bmdFormat10BitRGB:
        case bmdFormat10BitRGBXLE:
        case bmdFormat10BitRGBX:
            stride = ((width + 63) / 64) * 256;
            break;
        case bmdFormat12BitRGB:
        case bmdFormat12BitRGBLE:
            stride = ((width * 36) / 8);
            break;
        default:
            break;
    }
    return stride;
}

NS_INLINE size_t cvBytesPerRow(OSType format, long width, long height)
{
    size_t rowBytes = 0;
    NSMutableDictionary* pbAttributes = [NSMutableDictionary dictionary];
    {
        NSString* pixelFormatKey = (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey;
        NSString* widthKey = (__bridge NSString *)kCVPixelBufferWidthKey;
        NSString* heightKey = (__bridge NSString *)kCVPixelBufferHeightKey;
        NSString* bytesPerRowAlignmentKey = (__bridge NSString *)kCVPixelBufferBytesPerRowAlignmentKey;
        pbAttributes[pixelFormatKey] = @(format);
        pbAttributes[widthKey] = @(width);
        pbAttributes[heightKey] = @(height);
        pbAttributes[bytesPerRowAlignmentKey] = @(16); // = 2^4 = 2 * sizeof(void*)
    }
    {
        CVPixelBufferRef pixelBuffer = nil;
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault,
                                           width, height, format,
                                           (__bridge CFDictionaryRef)pbAttributes,
                                           &pixelBuffer);
        if (!err && pixelBuffer) {
            rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferRelease(pixelBuffer);
        }
    }
    return rowBytes;
}

NS_INLINE OSType preferredCVPixelFormatFor(BMDPixelFormat dlFormat) {
    OSType cvFormat = 0;
    switch (dlFormat) {
        case bmdFormat8BitYUV: // '2vuy'
            cvFormat = kCVPixelFormatType_422YpCbCr8; // '2vuy'
            break;
        case bmdFormat10BitYUV: // 'v210'
            cvFormat = kCVPixelFormatType_422YpCbCr10; // 'v210'
            break;
        case bmdFormat8BitARGB: // 32
            cvFormat = kCVPixelFormatType_32ARGB; // 32
            break;
        case bmdFormat8BitBGRA: // 'BGRA'
            cvFormat = kCVPixelFormatType_32BGRA; // 'BGRA'
            break;
        case bmdFormat10BitRGB: // 'r210' (64-960)
        case bmdFormat10BitRGBXLE: // 'R10l' (64-960)
        case bmdFormat10BitRGBX: // 'R10b' (64-960)
            // cvFormat = kCVPixelFormatType_30RGBLEPackedWideGamut; // 'w30r' (384-895)
            // cvFormat = kCVPixelFormatType_ARGB2101010LEPacked; // 'l10r' (0-4095 LE)
            // cvFormat = kCVPixelFormatType_64RGBAHalf; // 'RGhA' (16bit float LE)
            cvFormat = kCVPixelFormatType_48RGB; // 'b48r' (0-65535 BE)
            break;
        case bmdFormat12BitRGB: // 'R12B'
        case bmdFormat12BitRGBLE: // 'R12L'
            // cvFormat = kCVPixelFormatType_64RGBAHalf; // 'RGhA' (16bit float LE)
            cvFormat = kCVPixelFormatType_48RGB; // 'b48r' (0-65535 BE)
            break;
        default:
            cvFormat = kCVPixelFormatType_422YpCbCr8; // '2vuy'
            break;
    }
    /*
     ### @ macOS 10.15.4 Catalina
     Filtered: ContainsRGB = 1 && IOSurfaceCoreAnimationCompatibility = 1
     => 'BGRA', 'RGhA', 'RGfA', 'w30r'
     Filtered: ContainsYCbCr = 1 && IOSurfaceCoreAnimationCompatibility = 1
     => 'r408', 'v408', 'y408', 'v308', 'v210', 'v410', 'r4fl',
     => '411v', '411f', '444v', '444f', 'y420', 'f420', 'a2vy',
     => 'x44p', 'xw4p', 'xf4p', 'x22p', 'xf2p', 'p420', 'p422',
     => 'p444', 'pf20', 'pf22', 'pf44', 'pw20', 'pw22', 'pw44',
     => '===1', '===2', '===3', 'ptv0', 'ptv2', 'ptv4', 'ptf0',
     => 'ptf2', 'ptf4', 'ptw0', 'ptw2', 'ptw4'
     */
    return cvFormat;
}

NS_INLINE NSString* nameForCVPixelFormatType(OSType cvPixelFormat)
{
    NSString* name = nil;
    switch (cvPixelFormat) {
        case kCVPixelFormatType_422YpCbCr8:         name = @"422YpCbCr8"; break;
        case kCVPixelFormatType_4444YpCbCrA8:       name = @"4444YpCbCrA8"; break;
        case kCVPixelFormatType_4444YpCbCrA8R:      name = @"4444YpCbCrA8R"; break;
        case kCVPixelFormatType_4444AYpCbCr8:       name = @"4444AYpCbCr8"; break;
        case kCVPixelFormatType_4444AYpCbCr16:      name = @"4444AYpCbCr16"; break;
        case kCVPixelFormatType_444YpCbCr8:         name = @"444YpCbCr8"; break;
        case kCVPixelFormatType_422YpCbCr16:        name = @"422YpCbCr16"; break;
        case kCVPixelFormatType_422YpCbCr10:        name = @"422YpCbCr10"; break;
        case kCVPixelFormatType_444YpCbCr10:        name = @"444YpCbCr10"; break;
        case kCVPixelFormatType_422YpCbCr8_yuvs:    name = @"422YpCbCr8_yuvs"; break;
        case kCVPixelFormatType_422YpCbCr8FullRange:    name = @"422YpCbCr8FullRange"; break;
            
        case kCVPixelFormatType_16LE555:            name = @"16LE555"; break;
        case kCVPixelFormatType_16LE5551:           name = @"16LE5551"; break;
        case kCVPixelFormatType_16LE565:            name = @"16LE565"; break;
        case kCVPixelFormatType_16BE555:            name = @"16BE555"; break;
        case kCVPixelFormatType_16BE565:            name = @"16BE565"; break;
        case kCVPixelFormatType_24RGB:              name = @"24RGB"; break;
        case kCVPixelFormatType_24BGR:              name = @"24BGR"; break;
        case kCVPixelFormatType_32ARGB:             name = @"32ARGB"; break;
        case kCVPixelFormatType_32BGRA:             name = @"32BGRA"; break;
        case kCVPixelFormatType_32ABGR:             name = @"32ABGR"; break;
        case kCVPixelFormatType_32RGBA:             name = @"32RGBA"; break;
        case kCVPixelFormatType_64ARGB:             name = @"64ARGB"; break;
        case kCVPixelFormatType_48RGB:              name = @"48RGB"; break;
        case kCVPixelFormatType_30RGB:              name = @"30RGB"; break;
        case kCVPixelFormatType_30RGBLEPackedWideGamut: name = @"30RGBLEPackedWideGamut"; break;
        case kCVPixelFormatType_ARGB2101010LEPacked:    name = @"ARGB2101010LEPacked"; break;
        case kCVPixelFormatType_64RGBAHalf:         name = @"64RGBAHalf"; break;
        case kCVPixelFormatType_128RGBAFloat:       name = @"128RGBAFloat"; break;
        case kCVPixelFormatType_14Bayer_GRBG:       name = @"14Bayer_GRBG"; break;
        case kCVPixelFormatType_14Bayer_RGGB:       name = @"14Bayer_RGGB"; break;
        case kCVPixelFormatType_14Bayer_BGGR:       name = @"14Bayer_BGGR"; break;
        case kCVPixelFormatType_14Bayer_GBRG:       name = @"14Bayer_GBRG"; break;
        default:                                    break;
    }
    return name;
}

NS_INLINE BOOL checkPixelFormat(BMDPixelFormat dlPixelFormat, OSType cvPixelFormat)
{
    BOOL dlReady = FALSE;
    switch (dlPixelFormat) {
        case bmdFormat8BitYUV:
        case bmdFormat10BitYUV:
            dlReady = true;
            break;
        case bmdFormat8BitARGB:
        case bmdFormat8BitBGRA:
        case bmdFormat10BitRGB:
        case bmdFormat10BitRGBXLE:
        case bmdFormat10BitRGBX:
        case bmdFormat12BitRGB:
        case bmdFormat12BitRGBLE:
            dlReady = true;
            break;
        default:
            dlReady = false;
            break;
    }
    
    BOOL cvReady = FALSE;
    switch (cvPixelFormat) {
        case kCVPixelFormatType_422YpCbCr8:
        case kCVPixelFormatType_4444YpCbCrA8:
        case kCVPixelFormatType_4444YpCbCrA8R:
        case kCVPixelFormatType_4444AYpCbCr8:
        case kCVPixelFormatType_4444AYpCbCr16:
        case kCVPixelFormatType_444YpCbCr8:
        case kCVPixelFormatType_422YpCbCr16:
        case kCVPixelFormatType_422YpCbCr10:
        case kCVPixelFormatType_444YpCbCr10:
        case kCVPixelFormatType_422YpCbCr8_yuvs:
        case kCVPixelFormatType_422YpCbCr8FullRange:
            cvReady = true;
            break;
        case kCVPixelFormatType_16LE555:
        case kCVPixelFormatType_16LE5551:
        case kCVPixelFormatType_16LE565:
        case kCVPixelFormatType_16BE555:
        case kCVPixelFormatType_16BE565:
        case kCVPixelFormatType_24RGB:
        case kCVPixelFormatType_24BGR:
        case kCVPixelFormatType_32ARGB:
        case kCVPixelFormatType_32BGRA:
        case kCVPixelFormatType_32ABGR:
        case kCVPixelFormatType_32RGBA:
        case kCVPixelFormatType_64ARGB:
        case kCVPixelFormatType_48RGB:
        case kCVPixelFormatType_30RGB:
        case kCVPixelFormatType_30RGBLEPackedWideGamut:
        case kCVPixelFormatType_ARGB2101010LEPacked:
        case kCVPixelFormatType_64RGBAHalf:
        case kCVPixelFormatType_128RGBAFloat:
        case kCVPixelFormatType_14Bayer_GRBG:
        case kCVPixelFormatType_14Bayer_RGGB:
        case kCVPixelFormatType_14Bayer_BGGR:
        case kCVPixelFormatType_14Bayer_GBRG:
            cvReady = true;
            break;
        default:
            cvReady = false;
            break;
    }
    return (dlReady && cvReady);
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
                     displayModeSupport:(BMDDisplayModeSupport_v10_11)displayModeSupport
{
    NSParameterAssert(newDisplayModeObj && pixelFormat && displayModeSupport);
    self = [self initWithDisplayModeObj:newDisplayModeObj
                            pixelFormat:pixelFormat
                         videoInputFlag:inputFlag];
    if (self) {
        _displayModeSupportW = (DLABDisplayModeSupportFlag1011)displayModeSupport;
    }
    return self;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                            pixelFormat:(BMDPixelFormat)pixelFormat
                         videoInputFlag:(BMDVideoInputFlags)inputFlag
{
    NSParameterAssert(newDisplayModeObj && pixelFormat);
    
    self = [self initWithDisplayModeObj:newDisplayModeObj];
    if (self) {
        _pixelFormatW = (DLABPixelFormat)pixelFormat;
        _inputFlagW = (DLABVideoInputFlag)inputFlag;
        _rowBytesW = rowBytesFor(pixelFormat, _widthW);
        
        _useVITCW = !_isHDW;
        _useRP188W = _isHDW;
        
        _cvPixelFormatType = preferredCVPixelFormatFor(_pixelFormatW);
    }
    return self;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                            pixelFormat:(BMDPixelFormat)pixelFormat
                        videoOutputFlag:(BMDVideoOutputFlags)outputFlag
                     displayModeSupport:(BMDDisplayModeSupport_v10_11)displayModeSupport
{
    NSParameterAssert(newDisplayModeObj && pixelFormat && displayModeSupport);
    
    self = [self initWithDisplayModeObj:newDisplayModeObj
                            pixelFormat:pixelFormat
                        videoOutputFlag:outputFlag];
    if (self) {
        _displayModeSupportW = (DLABDisplayModeSupportFlag1011)displayModeSupport;
    }
    return self;
}

- (instancetype) initWithDisplayModeObj:(IDeckLinkDisplayMode *)newDisplayModeObj
                            pixelFormat:(BMDPixelFormat)pixelFormat
                        videoOutputFlag:(BMDVideoOutputFlags)outputFlag
{
    NSParameterAssert(newDisplayModeObj && pixelFormat);
    
    self = [self initWithDisplayModeObj:newDisplayModeObj];
    if (self) {
        _pixelFormatW = (DLABPixelFormat)pixelFormat;
        _outputFlagW = (DLABVideoOutputFlag)outputFlag;
        _rowBytesW = rowBytesFor(pixelFormat, _widthW);
        
        _useVITCW = !_isHDW && (_outputFlagW & bmdVideoOutputVITC);
        _useRP188W = _isHDW && (_outputFlagW & bmdVideoOutputRP188);
        
        _cvPixelFormatType = preferredCVPixelFormatFor(_pixelFormatW);
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
        _displayModeFlagW = (DLABDisplayModeFlag) _displayModeObj->GetFlags();
        
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

// public hash - NSObject
- (NSUInteger) hash
{
    NSUInteger value = (NSUInteger)(_widthW^_heightW) ^ (NSUInteger)(_displayModeW^_pixelFormatW);
    return value;
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
    if (!( self.displayModeSupportW == object.displayModeSupportW )) return NO; // TODO: deprecated
    
    if (!( self.rowBytesW == object.rowBytesW )) return NO;
    
    if (!( self.cvPixelFormatType == object.cvPixelFormatType )) return NO;
    
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
        obj.displayModeSupportW = self.displayModeSupportW; // TODO: deprecated
        obj.rowBytesW = self.rowBytesW;
        obj.cvPixelFormatType = self.cvPixelFormatType;
        
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

// public sysnthesize
@synthesize extensions = _extensions;
@synthesize extensionsNoClap = _extensionsNoClap;

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
- (DLABDisplayModeSupportFlag1011) displayModeSupport { return _displayModeSupportW; } // TODO: deprecated
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
    DLABDisplayModeSupportFlag1011 displayModeSupport = self.displayModeSupportW; // TODO: deprecated
    
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
                                            @"displayModeSupport" : @(displayModeSupport), // TODO: deprecated
                                            @"rowBytes" : @(rowBytes),
                                            };
    return displayModeDictionary;
}

- (BOOL) buildVideoFormatDescription
{
    return [self buildVideoFormatDescriptionWithError:nil];
}

- (BOOL) buildVideoFormatDescriptionWithError:(NSError**)error
{
    {
        // long
        long width = self.widthW;
        long height = self.heightW;
        long rowBytes = self.rowBytesW;
        
        // pixel format
        BMDPixelFormat pixelFormat = self.pixelFormatW; //uint32_t
        OSType cvPixelFormat = self.cvPixelFormatType;  // uint32_t
        
        //
        BOOL ready = (width && height && rowBytes && pixelFormat && cvPixelFormat);
        if (!ready) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported settings detected."
                  code:E_INVALIDARG
                    to:error];
        }
        
        if (ready) {
            ready = checkPixelFormat(pixelFormat, cvPixelFormat);
            if (!ready) {
                [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                    reason:@"Unsupported pixel format(s) detected."
                      code:E_INVALIDARG
                        to:error];
            }
        }
        
        //
        if (pixelFormat != cvPixelFormat) {
            size_t cvRowBytes = cvBytesPerRow(cvPixelFormat, width, height);
            if (cvRowBytes > 0) {
                rowBytes = cvRowBytes;
                _cvRowBytes = cvRowBytes;
            } else {
                [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                    reason:@"Unsupported CoreVideo pixel format detected."
                      code:E_INVALIDARG
                        to:error];
                return NO;
            }
        }
        
        [self buildFormatDescriptionExtensionsOf:cvPixelFormat width:width height:height rowBytes:rowBytes];
        NSDictionary* extensions = self.extensions;
        
        if (ready && extensions) {
            // create format description
            OSStatus result = noErr;
            CMFormatDescriptionRef formatDescription = NULL;
            result = CMVideoFormatDescriptionCreate(NULL,
                                                    (CMVideoCodecType)cvPixelFormat,
                                                    (int32_t)width,
                                                    (int32_t)height,
                                                    (__bridge CFDictionaryRef)extensions,
                                                    &formatDescription);
            if (!result && formatDescription) {
                self.videoFormatDescriptionW = formatDescription;
                CFRelease(formatDescription);
                return TRUE;
            } else {
                [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                    reason:@"Failed to create CMVideoFormatDescription."
                      code:E_INVALIDARG
                        to:error];
            }
        }
    }
    return FALSE;
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
        // NOTE: Preserve specified CVPixelFormatType as is
        
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

- (void)buildFormatDescriptionExtensionsOf:(OSType)cvPixelFormat width:(long)width height:(long)height rowBytes:(size_t)rowBytes
{
    NSMutableDictionary *extensions = [NSMutableDictionary dictionary];
    {
        // format name (either rgb or yuv related name)
        NSString* keyFormatName = (__bridge NSString*)kCMFormatDescriptionExtension_FormatName;
        NSString* name = nameForCVPixelFormatType(cvPixelFormat);
        extensions[keyFormatName] = name;
        
        // stride (bytes per row)
        NSString* keyStride = (__bridge NSString*)kCMFormatDescriptionExtension_BytesPerRow;
        extensions[keyStride] = @(rowBytes);
        
        // gamma level (legacy)
        NSString* keyGamma = (__bridge NSString*)kCMFormatDescriptionExtension_GammaLevel;
        extensions[keyGamma] = @(2.2);
    }
    {
        // Color space
        NSString* keyMatrix = (__bridge NSString*)kCMFormatDescriptionExtension_YCbCrMatrix;
        NSString* matrix2020 = (__bridge NSString*)kCMFormatDescriptionYCbCrMatrix_ITU_R_2020;
        NSString* matrix709 = (__bridge NSString*)kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2;
        NSString* matrix601 = (__bridge NSString*)kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4;
        
        NSString* keyPrimary = (__bridge NSString*)kCMFormatDescriptionExtension_ColorPrimaries;
        NSString* primITUR2020 = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_ITU_R_2020;
        NSString* primITUR709 = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_ITU_R_709_2;
        NSString* primSMPTEC = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_SMPTE_C;
        NSString* primEBU3213 = (__bridge NSString*)kCMFormatDescriptionColorPrimaries_EBU_3213;
        
        NSString* keyXfer = (__bridge NSString*)kCMFormatDescriptionExtension_TransferFunction;
        NSString* xfer2020 = (__bridge NSString*)kCMFormatDescriptionTransferFunction_ITU_R_2020;
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
        if (displayModeFlag & bmdDisplayModeColorspaceRec2020) {
            frameMatrix = matrix2020;
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
        } else if (width <= 1920) {
            extensions[keyPrimary] = primITUR709;
            extensions[keyXfer] = xfer709;
            extensions[keyMatrix] = (frameMatrix ? frameMatrix : matrix709);
        } else {
            extensions[keyPrimary] = primITUR2020;
            extensions[keyXfer] = xfer2020;
            extensions[keyMatrix] = (frameMatrix ? frameMatrix : matrix2020);
        }
    }
    {
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
    if (self.paspReady) {
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
    _extensionsNoClap = extensions.copy;
    
    if (self.clapReady) {
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

        _extensions = extensions.copy;
    } else {
        _extensions = _extensionsNoClap;
    }
}

@end
