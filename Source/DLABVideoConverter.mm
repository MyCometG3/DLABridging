//
//  DLABVideoConverter.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/04/07.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import "DLABVideoConverter.h"

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

@interface DLABVideoConverter ()

@property (nonatomic, assign) OSType cvFormat;
@property (nonatomic, assign) vImagePixelCount cvWidth;
@property (nonatomic, assign) vImagePixelCount cvHeight;

@property (nonatomic, assign) BMDPixelFormat dlFormat;
@property (nonatomic, assign) vImagePixelCount dlWidth;
@property (nonatomic, assign) vImagePixelCount dlHeight;
@property (nonatomic, assign) size_t dlRowBytes;
@property (nonatomic, assign) BOOL dlEndianSwap;

@property (nonatomic, assign) int32_t dlRangeMin;
@property (nonatomic, assign) int32_t dlRangeMax;

@property (nonatomic, assign) BOOL dlDefault16Q12;
@property (nonatomic, assign) BOOL dlUseXRGB16U;
@property (nonatomic, assign) vImage_YpCbCrToARGB infoToARGB;
@property (nonatomic, assign) vImage_ARGBToYpCbCr infoToYpCbCr;

@property (nonatomic, assign) vImage_Buffer dlHostBuffer; // dlBuffer in HostEndian
@property (nonatomic, assign) vImage_Buffer interimBuffer; // interim XRGB16U format (RGB444)
@property (nonatomic, assign) vImage_Buffer argb8888Buffer; // For dlUseXRGB16U: YUV8 <-> RGB8 <-> RGB16

@property (nonatomic, assign) vImageConverterRef convCVtoCG; // for output converter from CV to XRGB16U
@property (nonatomic, assign) vImageConverterRef convCGtoCV; // for input converter from XRGB16U to CV;
@property (nonatomic, assign) void* tempBuffer;
@property (nonatomic, assign) BOOL queryTempBuffer;

@property (nonatomic, assign) vImageConverterRef convCGtoRGB12U; // for output converter from XRGB16U to R12L
@property (nonatomic, assign) vImageConverterRef convRGB12UtoCG; // for input converter from R12L to XRGB16U
@property (nonatomic, assign) void* temp1216Buffer;
@property (nonatomic, assign) BOOL queryTemp1216Buffer;

@end

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

@implementation DLABVideoConverter

- (instancetype) initWithDL:(IDeckLinkVideoFrame*)videoFrame toCV:(CVPixelBufferRef)pixelBuffer
{
    self = [super init];
    if (self) {
        BOOL ready = [self prepareDL:videoFrame toCV:pixelBuffer];
        if (ready) return self;
    }
    return nil;
}

- (instancetype) initWithCV:(CVPixelBufferRef)pixelBuffer toDL:(IDeckLinkMutableVideoFrame*)videoFrame
{
    self = [super init];
    if (self) {
        BOOL ready = [self prepareCV:pixelBuffer toDL:videoFrame];
        if (ready) return self;
    }
    return nil;
}

- (void)dealloc
{
    [self cleanup];
}

/* =================================================================================== */
// MARK: - Accessor -
/* =================================================================================== */

/* =================================================================================== */
// MARK: Public accessor
/* =================================================================================== */

@synthesize dlColorSpace = dlColorSpace, cvColorSpace = cvColorSpace;
@synthesize useDLColorSpace = useDLColorSpace;
@synthesize useGammaSubstitute = useGammaSubstitute;

- (void)setDlColorSpace:(CGColorSpaceRef)newColorSpace
{
    if (dlColorSpace != newColorSpace) {
        CGColorSpaceRelease(dlColorSpace);
        CGColorSpaceRetain(newColorSpace);
        dlColorSpace = newColorSpace;
    }
}

- (void)setCvColorSpace:(CGColorSpaceRef)newColorSpace
{
    if (cvColorSpace != newColorSpace) {
        CGColorSpaceRelease(cvColorSpace);
        CGColorSpaceRetain(newColorSpace);
        cvColorSpace = newColorSpace;
    }
}

/* =================================================================================== */
// MARK: Private accessor
/* =================================================================================== */

@synthesize cvFormat = cvFormat;
@synthesize cvWidth = cvWidth;
@synthesize cvHeight = cvHeight;

@synthesize dlFormat = dlFormat;
@synthesize dlWidth = dlWidth;
@synthesize dlHeight = dlHeight;
@synthesize dlRowBytes = dlRowBytes;
@synthesize dlEndianSwap = dlEndianSwap;

@synthesize dlRangeMin = dlRangeMin;
@synthesize dlRangeMax = dlRangeMax;

@synthesize dlDefault16Q12 = dlDefault16Q12;
@synthesize dlUseXRGB16U = dlUseXRGB16U;
@synthesize infoToARGB = infoToARGB;
@synthesize infoToYpCbCr = infoToYpCbCr;

@synthesize dlHostBuffer = dlHostBuffer;
@synthesize interimBuffer = interimBuffer;
@synthesize argb8888Buffer = argb8888Buffer;

@synthesize convCVtoCG = convCVtoCG;
@synthesize convCGtoCV = convCGtoCV;
@synthesize tempBuffer = tempBuffer;
@synthesize queryTempBuffer = queryTempBuffer;

@synthesize convCGtoRGB12U = convCGtoRGB12U;
@synthesize convRGB12UtoCG = convRGB12UtoCG;
@synthesize temp1216Buffer = temp1216Buffer;
@synthesize queryTemp1216Buffer = queryTemp1216Buffer;

/* =================================================================================== */
// MARK: - Functions -
/* =================================================================================== */

// MARK: Interim vImage Format
/*
 NOTE: vImage_Utilities.h
 65  *      vImage_CGImageFormat format = {
 66  *          .bitsPerComponent = 8,
 67  *          .bitsPerPixel = 32,
 68  *          .colorSpace = CGColorSpaceCreateDeviceRGB(),                                    // don't forget to release this!
 69  *          .bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
 70  *          .version = 0,                                                                   // must be 0
 71  *          .decode = NULL,
 72  *          .renderingIntent = kCGRenderingIntentDefault
 73  *      };
 
 90  *      RGBA16F      ->  {16, 64, NULL, alpha last | kCGBitmapFloatComponents | kCGBitmapByteOrder16Little, 0, NULL, kCGRenderingIntentDefault }
 */

NS_INLINE vImage_CGImageFormat formatXRGB16U(CGColorSpaceRef colorspace) {
    const vImage_CGImageFormat formatXRGB16U = {
        .bitsPerComponent = 16,
        .bitsPerPixel = 64,
        .colorSpace = colorspace,
        .bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little,
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    return formatXRGB16U;
}

NS_INLINE vImage_CGImageFormat formatXRGB16Q12(CGColorSpaceRef colorspace) {
    const vImage_CGImageFormat formatXRGB16Q12 = {
        .bitsPerComponent = 16,
        .bitsPerPixel = 64,
        .colorSpace = colorspace,
        .bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little,
        .version = 0,
        .decode = kvImageDecodeArray_16Q12Format,
        .renderingIntent = kCGRenderingIntentDefault
    };
    return formatXRGB16Q12;
}

NS_INLINE vImage_CGImageFormat formatXRGB8888(CGColorSpaceRef colorspace) {
    const vImage_CGImageFormat formatXRGB8888 = {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = colorspace,
        .bitmapInfo = kCGImageAlphaNoneSkipFirst,
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    return formatXRGB8888;
}

// MARK: RGB12U vImage format

NS_INLINE vImage_CGImageFormat formatRGB12U(CGColorSpaceRef colorspace) {
    const vImage_CGImageFormat formatRGB12U = {
        .bitsPerComponent = 12,
        .bitsPerPixel = 36,
        .colorSpace = colorspace,
        .bitmapInfo = kCGImageAlphaNone,
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    return formatRGB12U;
}

// MARK: Transfer functions

/*
 NOTE: vImage_CVUtilities.h
 
 309  * @function vImageCVImageFormat_Create
 
 330  * @param  baseColorspace       For RGB and monochrome images, this is the colorspace of the image.
 331  *
 332  *                              For YpCbCr images, this is the colorspace of the RGB image before it was converted to YpCbCr using the ARGB-to-YpCbCr
 333  *                              conversion matrix (see matrix parameter above). The colorspace is defined based on the YpCbCr format RGB primaries
 334  *                              and transfer function.
 335  *
 336  *                              This may be NULL. However, you will eventually be forced to set set a colorspace for all image types, before
 337  *                              a vImageConvertRef can be made with this object.
 
 830 typedef struct vImageTransferFunction
 831 {
 832     CGFloat c0, c1, c2, c3, gamma;          // R' = c0 * pow( c1 * R + c2, gamma ) + c3,    (R >= cutoff)
 833     CGFloat cutoff;                         // See immediately above and below.  For no linear region (no below segment), pass -INFINITY here.
 834     CGFloat c4, c5;                         // R' = c4 * R + c5                             (R < cutoff)
 835 }vImageTransferFunction;
 
 844  * @function vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction
 845  *
 846  * @abstract Create a RGB colorspace based on primitives typically found in Y'CbCr specifications
 847  *
 848  * @discussion This function may be used to create a CGColorSpaceRef to correspond with a given set of color
 849  * primaries and transfer function. This defines a RGB colorspace. (A Y'CbCr colorspace is defined as a RGB
 850  * colorspace and a conversion matrix from RGB to Y'CbCr.) The color primaries give the extent of a colorspace
 851  * in x,y,z space and the transfer function gives the transformation from linear color to non-linear color that
 852  * the pixels actually reside in.
 
 896  *      Note: This low level function does not conform to CoreVideo practice of automatically substituting gamma 1/1.961
 897  *      for kCVImageBufferTransferFunction_ITU_R_709_2 and kCVImageBufferTransferFunction_SMPTE_240M_1995 instead of using
 898  *      the ITU-R BT.709-5 specified transfer function. (vImageBuffer_InitWithCVPixelBuffer and vImageBuffer_CopyToCVPixelBuffer
 899  *      do.) If you would like that behavior, you can use the following transfer function:
 900  *
 901  *      const vImageTransferFunction f709_Apple =
 */

/*
 For reference: Some suggestive discussion there:
 https://forums.developer.apple.com/thread/113337
 https://github.com/mpv-player/mpv/issues/4248
 */

NS_INLINE vImageTransferFunction tfCoreVideo(void)
{
    // NonStrict CoreVideo practice of gamma substituting
    const vImageTransferFunction f709_Apple = {
        .c0 =       1.0,
        .c1 =       1.0,
        .c2 =       0.0,
        .c3 =       0,
        .gamma =    1.0/1.961,
        .cutoff =   -INFINITY,
        .c4 =       1,
        .c5 =       0
    };
    return f709_Apple;
}

NS_INLINE vImageTransferFunction tfHD12(void)
{
    const vImageTransferFunction f2020_12 = {
        .c0 =       1.0993,
        .c1 =       1.0,
        .c2 =       0.0,
        .gamma =    0.45,
        .cutoff =   0.0181,
        .c3 =       -0.0993,
        .c4 =       4.5,
        .c5 =       0.0,
    };
    return f2020_12;
}

NS_INLINE vImageTransferFunction tfHD(void)
{
    const vImageTransferFunction f709 = {
        .c0 =       1.099,
        .c1 =       1.0,
        .c2 =       0.0,
        .gamma =    0.45,
        .cutoff =   0.018,
        .c3 =       -0.099,
        .c4 =       4.5,
        .c5 =       0.0,
    };
    return f709;
}

NS_INLINE vImageTransferFunction tfSD(void)
{
    const vImageTransferFunction f601 = {
        .c0 =       1.099,
        .c1 =       1.0,
        .c2 =       0.0,
        .gamma =    0.45,
        .cutoff =   0.018,
        .c3 =       -0.099,
        .c4 =       4.5,
        .c5 =       0.0,
    };
    return f601;
}

NS_INLINE vImageTransferFunction func2020_12(BOOL strict)
{
    return (strict ? tfHD12() : tfCoreVideo());
}

NS_INLINE vImageTransferFunction func2020_10(BOOL strict)
{
    return (strict ? tfHD() : tfCoreVideo());
}

NS_INLINE vImageTransferFunction func709(BOOL strict)
{
    return (strict ? tfHD() : tfCoreVideo());
}

NS_INLINE vImageTransferFunction func601(BOOL strict)
{
    return (strict ? tfSD() : tfCoreVideo());
}

// MARK: Color primaries

NS_INLINE vImageRGBPrimaries prim2020(void)
{
    const vImageRGBPrimaries p2020 = {
        .red_x =    0.708,  .red_y =    0.292,
        .green_x =  0.170,  .green_y =  0.797,
        .blue_x =   0.131,  .blue_y =   0.046,
        .white_x =  0.3127, .white_y =  0.3290,
    };
    return p2020;
}

NS_INLINE vImageRGBPrimaries prim709(void)
{
    const vImageRGBPrimaries p709 = {
        .red_x =    0.640,  .red_y =    0.330,
        .green_x =  0.300,  .green_y =  0.600,
        .blue_x =   0.150,  .blue_y =   0.060,
        .white_x =  0.3127, .white_y =  0.3290,
    };
    return p709;
}

NS_INLINE vImageRGBPrimaries prim601_625(void)
{
    const vImageRGBPrimaries p601_625 = {
        .red_x =    0.640,  .red_y =    0.330,
        .green_x =  0.290,  .green_y =  0.600,
        .blue_x =   0.150,  .blue_y =   0.060,
        .white_x =  0.3127, .white_y =  0.3290,
    };
    return p601_625;
}

NS_INLINE vImageRGBPrimaries prim601_525(void)
{
    const vImageRGBPrimaries p601_525 = {
        .red_x =    0.630,  .red_y =    0.340,
        .green_x =  0.310,  .green_y =  0.595,
        .blue_x =   0.155,  .blue_y =   0.070,
        .white_x =  0.3127, .white_y =  0.3290,
    };
    return p601_525;
}

// MARK: Color matrices

NS_INLINE vImage_YpCbCrToARGBMatrix matrixToRGB2020(void)
{
    const vImage_YpCbCrToARGBMatrix matrix = {
        .Yp     = 1.0,
        .Cr_R   = 1.4746,
        .Cr_G   = (-1.4746 * 0.2627 / 0.6780),
        .Cb_G   = (-1.8814 * 0.0593 / 0.6780),
        .Cb_B   = 1.8814
    };
    return matrix;
}

NS_INLINE vImage_YpCbCrToARGBMatrix matrixToRGB709(void)
{
    return *kvImage_YpCbCrToARGBMatrix_ITU_R_709_2;
}

NS_INLINE vImage_YpCbCrToARGBMatrix matrixToRGB601(void)
{
    return *kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
}

NS_INLINE vImage_ARGBToYpCbCrMatrix matrixToYpCbCr2020(void)
{
    const vImage_ARGBToYpCbCrMatrix matrix = {
        .R_Yp   = 0.2627,
        .G_Yp   = 0.6780,
        .B_Yp   = 0.0593,
        .R_Cb   = (-0.2627/1.8814),
        .G_Cb   = (-0.6780/1.8814),
        .B_Cb_R_Cr = 0.5,
        .G_Cr   = (-0.6780/1.4746),
        .B_Cr   = (-0.0593/1.4746)
    };
    return matrix;
}

NS_INLINE vImage_ARGBToYpCbCrMatrix matrixToYpCbCr709(void)
{
    return *kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2;
}

NS_INLINE const vImage_ARGBToYpCbCrMatrix matrixToYpCbCr601(void)
{
    return *kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
}

NS_INLINE vImage_ARGBToYpCbCrMatrix matrixToYpCbCrFor(size_t w, size_t h)
{
    vImage_ARGBToYpCbCrMatrix matrix = {0};
    if (h <= 525) {
        matrix = matrixToYpCbCr601();
    } else if (h <= 625) {
        matrix = matrixToYpCbCr601();
    } else if (h <= 1125) {
        matrix = matrixToYpCbCr709();
    } else { //if (w > 1920)
        matrix = matrixToYpCbCr2020();
    }
    return matrix;
}

NS_INLINE vImage_YpCbCrToARGBMatrix matrixToRGBFor(size_t w, size_t h)
{
    vImage_YpCbCrToARGBMatrix matrix = {0};
    if (h <= 525) {
        matrix = matrixToRGB601();
    } else if (h <= 625) {
        matrix = matrixToRGB601();
    } else if (h <= 1125) {
        matrix = matrixToRGB709();
    } else { //if (w > 1920)
        matrix = matrixToRGB2020();
    }
    return matrix;
}

// MARK: Quantization

NS_INLINE vImage_YpCbCrPixelRange videoRange8Clamped(void)
{
    const vImage_YpCbCrPixelRange pixelRange = {
        .Yp_bias = 16,
        .CbCr_bias = 128,
        .YpRangeMax = 235,
        .CbCrRangeMax = 240,
        .YpMax = 235,
        .YpMin = 16,
        .CbCrMax = 240,
        .CbCrMin = 16
    };
    return pixelRange;
}

NS_INLINE vImage_YpCbCrPixelRange videoRange10Clamped(void)
{
    const vImage_YpCbCrPixelRange pixelRange = {
        .Yp_bias = 64,
        .CbCr_bias = 512,
        .YpRangeMax = 940,
        .CbCrRangeMax = 960,
        .YpMax = 940,
        .YpMin = 64,
        .CbCrMax = 960,
        .CbCrMin = 64
    };
    return pixelRange;
}

// MARK: ColorSpace generation

NS_INLINE CGColorSpaceRef createColorSpaceForITUR_2020(BOOL strict, BOOL for12bits)
{
    // Rec2020; ITU-R BT.2020-2
    vImage_Error err = kvImageNoError;
    CGColorSpaceRef cs = NULL;
    const vImageRGBPrimaries p2020 = prim2020();
    const vImageTransferFunction f2020 = (for12bits ? func2020_12(strict) : func2020_10(strict));
    cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&p2020, &f2020,
                                                                   kCGRenderingIntentDefault,
                                                                   kvImageNoFlags, &err );
    return cs;
}

NS_INLINE CGColorSpaceRef createColorSpaceForITUR_709(BOOL strict)
{
    // Rec.709; ITU-R BT.709-6
    vImage_Error err = kvImageNoError;
    CGColorSpaceRef cs = NULL;
    const vImageRGBPrimaries p709 = prim709();
    const vImageTransferFunction f709 = func709(strict);
    cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&p709, &f709,
                                                                   kCGRenderingIntentDefault,
                                                                   kvImageNoFlags, &err );
    return cs;
}

NS_INLINE CGColorSpaceRef createColorSpaceForITUR_601_625(BOOL strict)
{
    // Rec.601; ITU-R BT.601-7 625lines
    vImage_Error err = kvImageNoError;
    CGColorSpaceRef cs = NULL;
    const vImageRGBPrimaries p601_625 = prim601_625();
    const vImageTransferFunction f601 = func601(strict);
    cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&p601_625, &f601,
                                                                   kCGRenderingIntentDefault,
                                                                   kvImageNoFlags, &err );
    return cs;
}

NS_INLINE CGColorSpaceRef createColorSpaceForITUR_601_525(BOOL strict)
{
    // Rec601;. ITU-R BT.601-7 525lines
    vImage_Error err = kvImageNoError;
    CGColorSpaceRef cs = NULL;
    const vImageRGBPrimaries p601_525 = prim601_525();
    const vImageTransferFunction f601 = func601(strict);
    cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&p601_525, &f601,
                                                                   kCGRenderingIntentDefault,
                                                                   kvImageNoFlags, &err );
    return cs;
}

NS_INLINE CGColorSpaceRef createColorSpaceITURFor(size_t w, size_t h, BOOL for12bits)
{
    // Use strict definition in ITU-R standards (= slower),
    CGColorSpaceRef cs = NULL;
    {
        BOOL strict = true;
        if (h <= 525) {
            cs = createColorSpaceForITUR_601_525(strict); // SD-525
        } else if (h <= 625) {
            cs = createColorSpaceForITUR_601_625(strict); // SD-625
        } else if (h <= 1125) {
            cs = createColorSpaceForITUR_709(strict); // HD (2K), 8 or 10 bits
        } else { //if (w > 1920) {
            cs = createColorSpaceForITUR_2020(strict, for12bits); // HDR (4K/8K), 10 or 12 bits
        }
    }
    return cs;
}

NS_INLINE CGColorSpaceRef createColorSpaceSubstitutedFor(size_t w, size_t h, BOOL for12bits)
{
    // Use Non strict CoreVideo approximation function (= faster)
    CGColorSpaceRef cs = NULL;
    {
        BOOL strict = false;
        if (h <= 525) {
            cs = createColorSpaceForITUR_601_525(strict); // SD-525
        } else if (h <= 625) {
            cs = createColorSpaceForITUR_601_625(strict); // SD-625
        } else if (h <= 1125) {
            cs = createColorSpaceForITUR_709(strict); // HD (2K), 8 or 10 bits
        } else { //if (w > 1920) {
            cs = createColorSpaceForITUR_2020(strict, for12bits); // HDR (4K/8K), 10 or 12 bits
        }
    }
    return cs;
}

NS_INLINE BOOL dl12bits(IDeckLinkVideoFrame* videoFrame)
{
    // Check if format is high bit depth (12bits and more)
    BOOL componentIn12bits = FALSE;
    BMDPixelFormat format = videoFrame->GetPixelFormat();
    switch (format) {
        case bmdFormat12BitRGB:
        case bmdFormat12BitRGBLE:
            componentIn12bits = TRUE;
            break;
        default:
            break;
    }
    return componentIn12bits;
}

CGColorSpaceRef createColorSpaceForVideoFrame(IDeckLinkVideoFrame* videoFrame, BOOL tfSubstitute)
{
    // Create ColorSpaceRef for IDeckLinkVideoFrame
    size_t w = videoFrame->GetWidth();
    size_t h = videoFrame->GetHeight();
    
    CGColorSpaceRef cs = NULL;
    if (!tfSubstitute) {
        {
            cs = createColorSpaceITURFor(w, h, dl12bits(videoFrame));
        }
        if (!cs) {
            cs = CGColorSpaceCreateDeviceRGB(); // owned - inaccurate
        }
    } else {
        cs = createColorSpaceSubstitutedFor(w, h, dl12bits(videoFrame));
    }
    return cs;
}

NS_INLINE BOOL cv12bits(CVPixelBufferRef pixelBuffer)
{
    // Check if format is high bit depth (12bits and more)
    BOOL componentIn12bits = FALSE;
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (format) {
        case kCVPixelFormatType_4444AYpCbCr16:
        case kCVPixelFormatType_422YpCbCr16:
            componentIn12bits = TRUE;
            break;
        case kCVPixelFormatType_64ARGB:
        case kCVPixelFormatType_48RGB:
        case kCVPixelFormatType_64RGBAHalf:
        case kCVPixelFormatType_128RGBAFloat:
        case kCVPixelFormatType_14Bayer_GRBG:
        case kCVPixelFormatType_14Bayer_RGGB:
        case kCVPixelFormatType_14Bayer_BGGR:
        case kCVPixelFormatType_14Bayer_GBRG:
            componentIn12bits = TRUE;
            break;
        default:
            break;
    }
    return componentIn12bits;
}

CGColorSpaceRef createColorSpaceForPixelBuffer(CVPixelBufferRef pixelBuffer, BOOL tfSubstitute)
{
    // Create ColorSpaceRef for CVPixelBuffer
    size_t w = CVPixelBufferGetWidth(pixelBuffer);
    size_t h = CVPixelBufferGetHeight(pixelBuffer);
    
    CGColorSpaceRef cs = NULL;
    if (!tfSubstitute) {
        // Check metadata of CVPixelBuffer for CGColorSpace first
        cs = CVImageBufferGetColorSpace(pixelBuffer); // getter for kCVImageBufferCGColorSpaceKey
        if (cs) {
            CGColorSpaceRetain(cs); // owned
        } else {
            CFDictionaryRef dict = CVBufferGetAttachments(pixelBuffer, kCVAttachmentMode_ShouldPropagate);
            if (dict) {
                cs = CVImageBufferCreateColorSpaceFromAttachments(dict); // owned
            }
        }
        if (!cs) {
            {
                cs = createColorSpaceITURFor(w, h, cv12bits(pixelBuffer));
            }
            if (!cs) {
                cs = CGColorSpaceCreateDeviceRGB(); // owned - inaccurate
            }
        }
    } else {
        cs = createColorSpaceSubstitutedFor(w, h, cv12bits(pixelBuffer));
    }
    return cs;
}

// MARK: Complement vImageCVImageFormatRef

vImage_Error fillCVColorSpace(vImageCVImageFormatRef format, CGColorSpaceRef cvColorSpace) {
    vImage_Error err = kvImageNoError;
    if (!vImageCVImageFormat_GetColorSpace(format)) {
        err = vImageCVImageFormat_SetColorSpace(format, cvColorSpace);
    }
    return err;
}

vImage_Error fillCVChromaSiting(vImageCVImageFormatRef format, CFStringRef siting) {
    vImage_Error err = kvImageNoError;
    uint32_t fourcc = vImageCVImageFormat_GetFormatCode(format);
    switch (fourcc) {
        case kCVPixelFormatType_422YpCbCr8:
        case kCVPixelFormatType_422YpCbCr16:
        case kCVPixelFormatType_422YpCbCr10:
        case kCVPixelFormatType_422YpCbCr8_yuvs:
        case kCVPixelFormatType_422YpCbCr8FullRange:
        {
            if (!vImageCVImageFormat_GetChromaSiting(format)) {
                err = vImageCVImageFormat_SetChromaSiting(format, siting);
            }
            break;
        }
        default:
            break;
    }
    return err;
}

vImage_Error fillCVConversionMatrix(vImageCVImageFormatRef format, vImage_ARGBToYpCbCrMatrix matrix) {
    vImage_Error err = kvImageNoError;
    uint32_t fourcc = vImageCVImageFormat_GetFormatCode(format);
    switch (fourcc) {
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
        {
            vImageMatrixType type = NULL;
            if (!vImageCVImageFormat_GetConversionMatrix(format, &type)) {
                vImageMatrixType outType = kvImageMatrixType_ARGBToYpCbCrMatrix;
                err = vImageCVImageFormat_CopyConversionMatrix(format, &matrix, outType);
            }
            break;
        }
        default:
            break;
    }
    return err;
}

// MARK: RGB12U endian conversion

void endianRGB12U_B2L(vImage_Buffer *buffer) {
    // 12U_B2L: vImage(12UBE) to DeckLink(12ULE)
    size_t height = (size_t)buffer->height;
    size_t rowBytes = buffer->rowBytes;
    size_t bufSize = rowBytes * height;
    uint8_t* ptr = (uint8_t*)buffer->data;
    assert(ptr && bufSize);
    if (rowBytes % 3 == 0) {
        for (size_t offset = 0; offset < bufSize; offset += 3) {
            size_t offset0 = (offset + 0), offset1 = (offset + 1), offset2 = (offset + 2);
            uint8_t p0 = ptr[offset0];
            uint8_t p1 = ptr[offset1];
            uint8_t p2 = ptr[offset2];
            ptr[offset0] = (p0<<4 | p1>>4);
            ptr[offset1] = (p2<<4 | p0>>4);
            ptr[offset2] = (p1<<4 | p2>>4);
        }
    } else {
        for (size_t vOffset = 0; vOffset < bufSize; vOffset += rowBytes) {
            for (size_t hOffset = 0; hOffset <= rowBytes - 3; hOffset += 3) {
                size_t offset = (vOffset + hOffset);
                size_t offset0 = (offset + 0), offset1 = (offset + 1), offset2 = (offset + 2);
                uint8_t p0 = ptr[offset0];
                uint8_t p1 = ptr[offset1];
                uint8_t p2 = ptr[offset2];
                ptr[offset0] = (p0<<4 | p1>>4);
                ptr[offset1] = (p2<<4 | p0>>4);
                ptr[offset2] = (p1<<4 | p2>>4);
            }
        }
    }
}

void endianRGB12U_L2B(vImage_Buffer *buffer) {
    // 12U_L2B: DeckLink(12ULE) to vImage(12UBE)
    size_t height = (size_t)buffer->height;
    size_t rowBytes = buffer->rowBytes;
    size_t bufSize = rowBytes * height;
    uint8_t* ptr = (uint8_t*)buffer->data;
    assert(ptr && bufSize);
    if (rowBytes % 3 == 0) {
        for (size_t offset = 0; offset < bufSize; offset += 3) {
            size_t offset0 = (offset + 0), offset1 = (offset + 1), offset2 = (offset + 2);
            uint8_t p0 = ptr[offset0];
            uint8_t p1 = ptr[offset1];
            uint8_t p2 = ptr[offset2];
            ptr[offset0] = (p0>>4 | p1<<4);
            ptr[offset1] = (p2>>4 | p0<<4);
            ptr[offset2] = (p1>>4 | p2<<4);
        }
    } else {
        for (size_t vOffset = 0; vOffset < bufSize; vOffset += rowBytes) {
            for (size_t hOffset = 0; hOffset <= rowBytes - 3; hOffset += 3) {
                size_t offset = (vOffset + hOffset);
                size_t offset0 = (offset + 0), offset1 = (offset + 1), offset2 = (offset + 2);
                uint8_t p0 = ptr[offset0];
                uint8_t p1 = ptr[offset1];
                uint8_t p2 = ptr[offset2];
                ptr[offset0] = (p0>>4 | p1<<4);
                ptr[offset1] = (p2>>4 | p0<<4);
                ptr[offset2] = (p1>>4 | p2<<4);
            }
        }
    }
}

/* =================================================================================== */
// MARK: - Methods -
/* =================================================================================== */

/* =================================================================================== */
// MARK: Private methods
/* =================================================================================== */

- (BOOL)applyFormatCV:(CVPixelBufferRef)pixelBuffer
{
    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    BOOL supported = (width * height > 0);
    // See: DLABVideoSetting:checkPixelFormat()
    switch (format) { // Ordered same as CVPixelBuffer.h
        case kCVPixelFormatType_16BE555:        // 0x00000010:ok:ok NotViewable
        case kCVPixelFormatType_16LE555:        // L555:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_16LE5551:       // 5551:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_16BE565:        // B565:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_16LE565:        // L565:-6680: CVPixelBufferCreate()
            break;
        case kCVPixelFormatType_24RGB:          // 0x00000018:ok:ok
        case kCVPixelFormatType_24BGR:          // 24BG:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_32ARGB:         // 0x00000020:ok:ok
        case kCVPixelFormatType_32BGRA:         // BGRA:ok:ok
        case kCVPixelFormatType_32ABGR:         // ABGR:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_32RGBA:         // RGBA:-6680: CVPixelBufferCreate()
        case kCVPixelFormatType_64ARGB:         // b64a:fail: vImageCVImageFormat_Create()
        case kCVPixelFormatType_48RGB:          // b48r:ok:ok NotViewable
        case kCVPixelFormatType_30RGB:          // R10k:crash: vImageConverter_CreateForCGToCVImageFormat()
            break;
        case kCVPixelFormatType_422YpCbCr8:     // ( 0)2vuy:ok:ok
        case kCVPixelFormatType_4444YpCbCrA8:   // ( 7)v408:ok:ok NotViewable
        case kCVPixelFormatType_4444YpCbCrA8R:  // ( 5)r408:ok:ok NotViewable
        case kCVPixelFormatType_4444AYpCbCr8:   // ( 5)y408:ok:ok NotViewable
        case kCVPixelFormatType_4444AYpCbCr16:  // (14)y416:ok:ok NotViewable
        case kCVPixelFormatType_444YpCbCr8:     // ( 6)v308:ok:ok NotViewable
        case kCVPixelFormatType_422YpCbCr16:    // (13)v216:ok:ok NotViewable
        case kCVPixelFormatType_422YpCbCr10:    // ( 9)v210:ok:ok
            break;
        case kCVPixelFormatType_444YpCbCr10:    // ( 8)v410:ok:ok NotViewable
            break;
        case kCVPixelFormatType_422YpCbCr8_yuvs:         // ( 1)yuvs:ok:ok
        case kCVPixelFormatType_422YpCbCr8FullRange:     // ( 1)yuvf:ok:ok NotViewable
            break;
        case kCVPixelFormatType_30RGBLEPackedWideGamut:  // w30r:fail: vImageCVImageFormat_Create()
        case kCVPixelFormatType_ARGB2101010LEPacked:     // l10r:fail: vImageCVImageFormat_Create()
            break;
        case kCVPixelFormatType_64RGBAHalf:     // RGhA:ok:ok
        case kCVPixelFormatType_128RGBAFloat:   // RGfA:ok:ok
            break;
        case kCVPixelFormatType_14Bayer_GRBG:   // grb4:fail: vImageCVImageFormat_Create()
        case kCVPixelFormatType_14Bayer_RGGB:   // rgg4:fail: vImageCVImageFormat_Create()
        case kCVPixelFormatType_14Bayer_BGGR:   // bgg4:fail: vImageCVImageFormat_Create()
        case kCVPixelFormatType_14Bayer_GBRG:   // gbr4:fail: vImageCVImageFormat_Create()
            break;
        default:
            supported = false;
            break;
    }
    if (supported) {
        if (!cvColorSpace) {
            cvColorSpace = createColorSpaceForPixelBuffer(pixelBuffer, useGammaSubstitute);
        }
        if (cvColorSpace) {
            cvFormat = format;
            cvWidth = width;
            cvHeight = height;
            
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)applyFormatDL:(IDeckLinkVideoFrame*)videoFrame
{
    long width  = videoFrame->GetWidth();
    long height = videoFrame->GetHeight();
    long rowBytes = videoFrame->GetRowBytes();
    BOOL endianSwap = false;
    int32_t rangeMin = 64;
    int32_t rangeMax = 940;
    BOOL default16Q12 = true;
    BOOL supported = (width * height > 0);
    BMDPixelFormat format = videoFrame->GetPixelFormat();
    switch (format) {
        case bmdFormat8BitYUV:
            endianSwap = false;
            rangeMin = 1; rangeMax = 255; // luma uses [16,235], chroma uses [16,240]
            default16Q12 = false; // use ARGB8888 for interimBuffer
            break;
        case bmdFormat10BitYUV:
            endianSwap = false;
            rangeMin = 1; rangeMax = 1023; // luma uses [64,940], chroma uses [64,960]
            default16Q12 = true; // use ARGB16Q12 for interimBuffer
            break;
        case bmdFormat8BitARGB:
            endianSwap = false;
            rangeMin = 0; rangeMax = 255;
            default16Q12 = false;
            break;
        case bmdFormat8BitBGRA:
            endianSwap = false;
            rangeMin = 0; rangeMax = 255;
            default16Q12 = false;
            break;
        case bmdFormat10BitRGB:     // 2101010 xRGB BigEndian
            endianSwap = true;
            rangeMin = 64; rangeMax = 960;
            default16Q12 = true;
            break;
        case bmdFormat10BitRGBX:    // 1010102 RGBx BigEndian
            endianSwap = true;
            rangeMin = 64; rangeMax = 940;
            default16Q12 = true;
            break;
        case bmdFormat10BitRGBXLE:  // 1010102 RGBx LittleEndian
            endianSwap = false;
            rangeMin = 64; rangeMax = 940;
            default16Q12 = true;
            break;
        case bmdFormat12BitRGB: // R12B BigEndian
            endianSwap = true;
            rangeMin = 0; rangeMax = 4095;
            default16Q12 = true;
            break;
        case bmdFormat12BitRGBLE: // R12L LittleEndian
            endianSwap = false;
            rangeMin = 0; rangeMax = 4095;
            default16Q12 = true;
            break;
        default:
            supported = false;
            break;
    }
    if (supported) {
        if (!dlColorSpace) {
            dlColorSpace = createColorSpaceForVideoFrame(videoFrame, useGammaSubstitute);
        }
        if (dlColorSpace) {
            dlFormat = format;
            dlWidth = width;
            dlHeight = height;
            dlRowBytes = rowBytes;
            dlEndianSwap = endianSwap;
            dlRangeMin = rangeMin;
            dlRangeMax = rangeMax;
            dlDefault16Q12 = default16Q12;
            
            return TRUE;
        }
    }
    return FALSE;
}

- (vImage_Error) vImageConvertDLRGB:(vImage_Buffer *)src
                          toInterim:(vImage_Buffer *)dest
                              flags:(vImage_Flags)flags
{
    // Convert DLRGB to interimBuffer
    vImage_Error convErr = kvImageInternalError;
    
    if (dlEndianSwap) {
        // bmdFormat10BitRGBX
        // bmdFormat10BitRGB
        // bmdFormat12BitRGB
        if (dlFormat == bmdFormat10BitRGBX) { // 1010102 BE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_RGBA1010102ToARGB16Q12(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_RGBA1010102ToARGB16U(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat10BitRGB) { // 2101010 BE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_ARGB2101010ToARGB16Q12(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_ARGB2101010ToARGB16U(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat12BitRGB) {
            if (convRGB12UtoCG) { // R12L to interimBuffer converter reference
                if (queryTemp1216Buffer) {
                    queryTemp1216Buffer = FALSE;
                    free(temp1216Buffer); temp1216Buffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convRGB12UtoCG, src, dest,
                                                               temp1216Buffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        posix_memalign(&ptr, 16, (size_t)size);
                        temp1216Buffer = ptr;
                    }
                }
                endianRGB12U_L2B(src); // 12U endian swap in place
                convErr = vImageConvert_AnyToAny(convRGB12UtoCG, src, dest,
                                                 temp1216Buffer, flags);
            }
        }
    } else {
        // bmdFormat8BitARGB
        // bmdFormat8BitBGRA
        // bmdFormat10BitRGBXLE
        // bmdFormat12BitRGBLE
        if (dlFormat == bmdFormat8BitARGB) {
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageCopyBuffer(src, dest, 4, flags);
            } else {
                uint8_t copyMask = 0b0000;
                Pixel_ARGB_16U bgColor = {0,0,0,0};
                convErr = vImageConvert_ARGB8888ToARGB16U(src, dest,
                                                          permuteMap, copyMask,
                                                          bgColor, flags);
            }
        } else if (dlFormat == bmdFormat8BitBGRA) {
            uint8_t permuteMap[4] = {3,2,1,0}; // componentOrder: B3, G2, R1, A0
            if (!dlUseXRGB16U) {
                convErr = vImagePermuteChannels_ARGB8888(src, dest,
                                                         permuteMap, flags);
            } else {
                uint8_t copyMask = 0b0000;
                Pixel_ARGB_16U bgColor = {0,0,0,0};
                convErr = vImageConvert_ARGB8888ToARGB16U(src, dest,
                                                          permuteMap, copyMask,
                                                          bgColor, flags);
            }
        } else if (dlFormat == bmdFormat10BitRGBXLE) { // 1010102 LE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_RGBA1010102ToARGB16Q12(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_RGBA1010102ToARGB16U(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat12BitRGBLE) {
            if (convRGB12UtoCG) { // R12L to interimBuffer converter reference
                if (queryTemp1216Buffer) {
                    queryTemp1216Buffer = FALSE;
                    free(temp1216Buffer); temp1216Buffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convRGB12UtoCG, src, dest,
                                                               temp1216Buffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        posix_memalign(&ptr, 16, (size_t)size);
                        temp1216Buffer = ptr;
                    }
                }
                endianRGB12U_L2B(src); // 12U endian swap in place
                convErr = vImageConvert_AnyToAny(convRGB12UtoCG, src, dest,
                                                 temp1216Buffer, flags);
            }
        }
    }
    return convErr;
}

- (vImage_Error) vImageConvertInterim:(vImage_Buffer *)src
                              toDLRGB:(vImage_Buffer *)dest
                                flags:(vImage_Flags)flags
{
    // Convert interimBuffer to DLRGB
    vImage_Error convErr = kvImageInternalError;
    
    if (dlEndianSwap) {
        // bmdFormat10BitRGBX
        // bmdFormat10BitRGB
        // bmdFormat12BitRGB
        if (dlFormat == bmdFormat10BitRGBX) { // 1010102 BE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_ARGB16Q12ToRGBA1010102(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_ARGB16UToRGBA1010102(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat10BitRGB) { // 2101010 BE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_ARGB16Q12ToARGB2101010(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_ARGB16UToARGB2101010(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat12BitRGB) {
            if (convCGtoRGB12U) { // interimBuffer to R12L converter reference
                if (queryTemp1216Buffer) {
                    queryTemp1216Buffer = FALSE;
                    free(temp1216Buffer); temp1216Buffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convCGtoRGB12U, src, dest,
                                                               temp1216Buffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        posix_memalign(&ptr, 16, (size_t)size);
                        temp1216Buffer = ptr;
                    }
                }
                convErr = vImageConvert_AnyToAny(convCGtoRGB12U, src, dest,
                                                 temp1216Buffer, flags);
                endianRGB12U_B2L(dest); // 12U endian swap in place
            }
        }
    } else {
        // bmdFormat8BitARGB
        // bmdFormat8BitBGRA
        // bmdFormat10BitRGBXLE
        // bmdFormat12BitRGBLE
        if (dlFormat == bmdFormat8BitARGB) {
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageCopyBuffer(src, dest, 4, flags);
            } else {
                uint8_t copyMask = 0b0000;
                Pixel_8888 bgColor = {0,0,0,0};
                convErr = vImageConvert_ARGB16UToARGB8888(src, dest,
                                                          permuteMap, copyMask,
                                                          bgColor, flags);
            }
        } else if (dlFormat == bmdFormat8BitBGRA) {
            uint8_t permuteMap[4] = {3,2,1,0}; // componentOrder: B3, G2, R1, A0
            if (!dlUseXRGB16U) {
                convErr = vImagePermuteChannels_ARGB8888(src, dest,
                                                         permuteMap, flags);
            } else {
                uint8_t copyMask = 0b0000;
                Pixel_8888 bgColor = {0,0,0,0};
                convErr = vImageConvert_ARGB16UToARGB8888(src, dest,
                                                          permuteMap, copyMask,
                                                          bgColor, flags);
            }
        } else if (dlFormat == bmdFormat10BitRGBXLE) { // 1010102 LE
            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
            if (!dlUseXRGB16U) {
                convErr = vImageConvert_ARGB16Q12ToRGBA1010102(src, dest,
                                                               dlRangeMin, dlRangeMax,
                                                               dlRangeMin, dlRangeMax,
                                                               permuteMap, flags);
            } else {
                convErr = vImageConvert_ARGB16UToRGBA1010102(src, dest,
                                                             dlRangeMin, dlRangeMax,
                                                             permuteMap, flags);
            }
        } else if (dlFormat == bmdFormat12BitRGBLE) {
            if (convCGtoRGB12U) { // interimBuffer to R12L converter reference
                if (queryTemp1216Buffer) {
                    queryTemp1216Buffer = FALSE;
                    free(temp1216Buffer); temp1216Buffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convCGtoRGB12U, src, dest,
                                                               temp1216Buffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        posix_memalign(&ptr, 16, (size_t)size);
                        temp1216Buffer = ptr;
                    }
                }
                convErr = vImageConvert_AnyToAny(convCGtoRGB12U, src, dest,
                                                 temp1216Buffer, flags);
                endianRGB12U_B2L(dest); // 12U endian swap in place
            }
        }
    }
    return convErr;
}

/* =================================================================================== */
// MARK: Public methods
/* =================================================================================== */

- (void)cleanup
{
    @synchronized (self) {
        // public
        CGColorSpaceRelease(dlColorSpace); dlColorSpace = NULL;
        CGColorSpaceRelease(cvColorSpace); cvColorSpace = NULL;
        useDLColorSpace = FALSE;
        useGammaSubstitute = FALSE;
        
        // private
        cvFormat = 0; cvWidth = 0; cvHeight = 0;
        dlFormat = 0; dlWidth = 0; dlHeight = 0;
        dlRowBytes = 0; dlEndianSwap = FALSE;
        dlRangeMin = 0; dlRangeMax = 0;
        dlDefault16Q12 = FALSE;
        
        dlUseXRGB16U = FALSE;
        infoToARGB = {0}; infoToYpCbCr = {0};
        
        free(dlHostBuffer.data); dlHostBuffer = {0};
        free(interimBuffer.data); interimBuffer = {0};
        free(argb8888Buffer.data); argb8888Buffer = {0};
        
        vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
        vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
        free(tempBuffer); tempBuffer = NULL;
        queryTempBuffer = TRUE;
        
        vImageConverter_Release(convRGB12UtoCG); convRGB12UtoCG = NULL;
        vImageConverter_Release(convCGtoRGB12U); convCGtoRGB12U = NULL;
        free(temp1216Buffer); temp1216Buffer = NULL;
        queryTemp1216Buffer = TRUE;
    }
}

- (BOOL)compatibleWithDL:(IDeckLinkVideoFrame*)videoFrame
                   andCV:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(videoFrame != NULL && pixelBuffer != NULL);
    
    BOOL cvReady = FALSE;
    if (cvColorSpace != NULL) {
        OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        size_t width  = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        if (cvFormat == format && cvWidth == width && cvHeight == height) {
            cvReady = TRUE;
        }
    }
    BOOL dlReady = FALSE;
    if (dlColorSpace != NULL) {
        BMDPixelFormat format = videoFrame->GetPixelFormat();
        long width  = videoFrame->GetWidth();
        long height = videoFrame->GetHeight();
        if (dlFormat == format && dlWidth == width && dlHeight == height) {
            dlReady = TRUE;
        }
    }
    BOOL noScaling = (dlWidth == cvWidth && dlHeight == cvHeight);
    return (cvReady && dlReady && noScaling);
}

- (BOOL)prepareDL:(IDeckLinkVideoFrame*)videoFrame toCV:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(videoFrame != NULL && pixelBuffer != NULL);
    
    if (!(cvColorSpace && dlColorSpace)) {
        BOOL dlReady = [self applyFormatDL:videoFrame];
        BOOL cvReady = [self applyFormatCV:pixelBuffer];
        if (!(dlReady && cvReady)) return false;
    }
    
    BOOL formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    if (!formatOK) return false;
    
    @synchronized (self) {
        {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            free(argb8888Buffer.data); argb8888Buffer = {0};
            vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
        }
        
        vImage_Error matrixErr = kvImageInternalError;
        vImage_Error dlHostErr = kvImageInternalError;
        vImage_Error interimErr = kvImageInternalError;
        vImage_Error errCGtoCV = kvImageInternalError;
        vImage_Error errRGB12UtoCG = kvImageInternalError;
        {
            if (dlFormat == bmdFormat10BitYUV) {
                // conv: YUV10 => either RGB8 or RGB16Q12; No RGB16U. See vImage/Conversion.h
                vImage_YpCbCrToARGBMatrix matrix = matrixToRGBFor(dlWidth, dlHeight);
                vImage_YpCbCrPixelRange pixelRange = videoRange10Clamped();
                vImage_YpCbCrToARGB info = {0};
                vImageARGBType interimType = (dlDefault16Q12 ? kvImageARGB16Q12 : kvImageARGB8888);
                matrixErr = vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                                          &pixelRange,
                                                                          &info,
                                                                          kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10,
                                                                          interimType,
                                                                          kvImageNoFlags);
                if (matrixErr == kvImageNoError) infoToARGB = info;
            } else if (dlFormat == bmdFormat8BitYUV) {
                // conv: YUV8 => RGB8 only; See vImage/Conversion.h
                vImage_YpCbCrToARGBMatrix matrix = matrixToRGBFor(dlWidth, dlHeight);
                vImage_YpCbCrPixelRange pixelRange = videoRange8Clamped();
                vImage_YpCbCrToARGB info = {0};
                vImageARGBType interimType = (kvImageARGB8888);
                matrixErr = vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                                          &pixelRange,
                                                                          &info,
                                                                          kvImage422CbYpCrYp8,
                                                                          interimType,
                                                                          kvImageNoFlags);
                if (matrixErr == kvImageNoError) {
                    infoToARGB = info;
                    
                    // For dlUseXRGB16U: YUV8 => RGB8 => RGB16; See vImage/Conversion.h
                    if (dlUseXRGB16U) {
                        size_t rowBytes = (dlWidth * 4);
                        void* ptr = NULL;
                        size_t bufferSize = (rowBytes * dlHeight);
                        if (posix_memalign(&ptr, 16, bufferSize) == 0 && ptr != NULL) {
                            argb8888Buffer.data = ptr;
                            argb8888Buffer.width = dlWidth;
                            argb8888Buffer.height = dlHeight;
                            argb8888Buffer.rowBytes = rowBytes;
                        } else {
                            matrixErr = kvImageInternalError;
                        }
                    }
                }
            } else {
                // RGBtoRGB conversion
                matrixErr = kvImageNoError;
            }
            if (matrixErr) {
                NSLog(@"ERROR: vImageConvert_YpCbCrToARGB_GenerateConversion() failed.");
            }
        }
        vImage_CGImageFormat interimFormat = {0};
        if (matrixErr == kvImageNoError) {
            void* ptr = NULL;
            size_t bufferSize = (dlRowBytes * dlHeight);
            if (posix_memalign(&ptr, 16, bufferSize) == 0 && ptr != NULL) {
                dlHostBuffer.data = ptr;
                dlHostBuffer.width = dlWidth;
                dlHostBuffer.height = dlHeight;
                dlHostBuffer.rowBytes = dlRowBytes;
                dlHostErr = kvImageNoError;
            }
        }
        if (dlHostErr == kvImageNoError) {
            CGColorSpaceRef cs = (useDLColorSpace? dlColorSpace : cvColorSpace);
            interimFormat = (dlUseXRGB16U ? formatXRGB16U(cs) :
                             (dlDefault16Q12 ? formatXRGB16Q12(cs) : formatXRGB8888(cs)));
            interimErr = vImageBuffer_Init(&interimBuffer,
                                           dlHeight, dlWidth, // rect of VideoFrame
                                           interimFormat.bitsPerPixel, kvImageNoFlags);
        }
        if (interimErr == kvImageNoError) {
            vImageCVImageFormatRef outFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer);
            if (outFormat) {
                assert(kvImageNoError == fillCVColorSpace(outFormat, cvColorSpace));
                assert(kvImageNoError == fillCVChromaSiting(outFormat, kCVImageBufferChromaLocation_Center));
                assert(kvImageNoError == fillCVConversionMatrix(outFormat, matrixToYpCbCrFor(dlWidth, dlHeight)));
                vImage_Flags flags = kvImageNoFlags; // kvImagePrintDiagnosticsToConsole
                CGFloat bgColor[3] = {0,0,0};
                convCGtoCV = vImageConverter_CreateForCGToCVImageFormat(&interimFormat,
                                                                        outFormat,
                                                                        bgColor,
                                                                        flags,
                                                                        &errCGtoCV);
                if (errCGtoCV || !convCGtoCV) {
                    NSLog(@"ERROR: vImageConverter_CreateForCGToCVImageFormat() failed.(%ld)", errCGtoCV);
                }
                vImageCVImageFormat_Release(outFormat);
                
                queryTempBuffer = TRUE;
                free(tempBuffer); tempBuffer = NULL;
            } else {
                NSLog(@"ERROR: vImageCVImageFormat_CreateWithCVPixelBuffer() failed.");
            }
        }
        if (errCGtoCV == kvImageNoError) {
            if (dlFormat == bmdFormat12BitRGB || dlFormat == bmdFormat12BitRGBLE) {
                CGColorSpaceRef cs = (useDLColorSpace? dlColorSpace : cvColorSpace);
                vImage_CGImageFormat inFormat = formatRGB12U(cs);
                CGFloat bgColor[3] = {0,0,0};
                convRGB12UtoCG = vImageConverter_CreateWithCGImageFormat(&inFormat,
                                                                         &interimFormat,
                                                                         bgColor,
                                                                         kvImageNoFlags,
                                                                         &errRGB12UtoCG);
                
                queryTemp1216Buffer = TRUE;
                free(temp1216Buffer); temp1216Buffer = NULL;
            } else {
                errRGB12UtoCG = kvImageNoError;
            }
        }
        
        BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCGtoCV != NULL);
        converterOK = converterOK && (errRGB12UtoCG == kvImageNoError);
        if (!converterOK) {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            free(argb8888Buffer.data); argb8888Buffer = {0};
            vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
            vImageConverter_Release(convRGB12UtoCG); convRGB12UtoCG = NULL;
        }
        return converterOK;
    }
}

- (BOOL)convertDL:(IDeckLinkVideoFrame*)videoFrame toCV:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(videoFrame != NULL && pixelBuffer != NULL);
    
    //
    BOOL formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCGtoCV != NULL);
    if (!(formatOK && converterOK)) {
        return FALSE; // unsupported conversion
    }
    
    @synchronized (self) {
        /* ================================================================ */
        // VideoFrame [(permute) dlHostBuffer] (xfer) interimBuffer (convCGtoCV) CVPixelBuffer
        /* ================================================================ */
        
        vImage_Error convErr = kvImageNoError;
        {
            // source vImage_Buffer
            void* ptr = NULL;
            HRESULT result = videoFrame->GetBytes(&ptr);
            assert (result == S_OK && ptr != NULL);
            
            vImage_Buffer sourceBuffer = {
                .data = ptr,
                .width = dlWidth,
                .height = dlHeight,
                .rowBytes = dlRowBytes
            };
            
            // Read from VideoFrame
            if (dlEndianSwap) {
                // Permute BigToHost
                {
                    uint8_t permuteMap[4] = {3,2,1,0};
                    convErr = vImagePermuteChannels_ARGB8888(&sourceBuffer, &dlHostBuffer,
                                                             permuteMap, kvImageNoFlags);
                }
                // Convert VideoFrame format (in hostEndian) to interimBuffer
                if (convErr == kvImageNoError) {
                    // bmdFormat10BitRGBX
                    // bmdFormat10BitRGB
                    // bmdFormat12BitRGB
                    convErr = [self vImageConvertDLRGB:&dlHostBuffer
                                             toInterim:&interimBuffer
                                                 flags:kvImageNoFlags];
                }
            } else {
                // Convert VideoFrame format to interimBuffer
                if (dlFormat == bmdFormat10BitYUV) { // v210
                    if (dlUseXRGB16U) {
                        // conv: YUV10 => XRGB16Q12 => XRGB16U
                        {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            convErr = vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(&sourceBuffer,
                                                                                             &interimBuffer,
                                                                                             &infoToARGB,
                                                                                             permuteMap,
                                                                                             4096,
                                                                                             kvImageNoFlags);
                        }
                        if (convErr == kvImageNoError) {
                            vImage_Buffer inPlace = interimBuffer;
                            inPlace.width = inPlace.width * 4;
                            convErr = vImageConvert_16Q12to16U(&inPlace, &inPlace, kvImageNoFlags);
                        }
                    } else {
                        // conv: YUV10 => XRGB16Q12
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(&sourceBuffer,
                                                                                         &interimBuffer,
                                                                                         &infoToARGB,
                                                                                         permuteMap,
                                                                                         4096,
                                                                                         kvImageNoFlags);
                    }
                } else if (dlFormat == bmdFormat8BitYUV) { // 2vuy
                    if (dlUseXRGB16U) {
                        // conv: YUV8 => XRGB8 => XRGB16U
                        {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            convErr = vImageConvert_422CbYpCrYp8ToARGB8888(&sourceBuffer, &argb8888Buffer,
                                                                           &infoToARGB, permuteMap,
                                                                           255, kvImageNoFlags);
                        }
                        if (convErr == kvImageNoError) {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            uint8_t copyMask = 0;
                            Pixel_16U bgColor[4] = {0,0,0,0};
                            convErr = vImageConvert_ARGB8888ToARGB16U(&argb8888Buffer, &interimBuffer,
                                                                      permuteMap, copyMask, bgColor,
                                                                      kvImageNoFlags);
                        }
                    } else {
                        // conv: YUV8 => XRGB8
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_422CbYpCrYp8ToARGB8888(&sourceBuffer, &interimBuffer,
                                                                       &infoToARGB, permuteMap,
                                                                       255, kvImageNoFlags);
                    }
                } else {
                    // bmdFormat8BitARGB
                    // bmdFormat8BitBGRA
                    // bmdFormat10BitRGBXLE
                    // bmdFormat12BitRGBLE
                    convErr = [self vImageConvertDLRGB:&sourceBuffer
                                             toInterim:&interimBuffer
                                                 flags:kvImageNoFlags];
                }
            }
        }
        if (convErr == kvImageNoError) {
            // Convert interimBuffer to CVPixelBuffer format
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            
            // target vImage_Buffer
            vImage_Buffer targetBuffer = {0};
            vImage_Flags targetFlags = kvImageNoAllocate;
            convErr = vImageBuffer_InitForCopyToCVPixelBuffer(&targetBuffer, convCGtoCV,
                                                              pixelBuffer, targetFlags);
            if (convErr == kvImageNoError) {
                if (queryTempBuffer) {
                    queryTempBuffer = FALSE;
                    free(tempBuffer); tempBuffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convCGtoCV,
                                                               &interimBuffer, &targetBuffer,
                                                               tempBuffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        if (posix_memalign(&ptr, 16, (size_t)size) == 0 && ptr != NULL) {
                            tempBuffer = ptr;
                        } else {
                            return FALSE;
                        }
                    }
                }
                convErr = vImageConvert_AnyToAny(convCGtoCV,
                                                 &interimBuffer, &targetBuffer,
                                                 tempBuffer, kvImageNoFlags);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        }
        
        return (convErr == kvImageNoError);
    }
}

- (BOOL)prepareCV:(CVPixelBufferRef)pixelBuffer toDL:(IDeckLinkMutableVideoFrame*)videoFrame
{
    NSParameterAssert(pixelBuffer != NULL && videoFrame != NULL);
    
    if (!(cvColorSpace && dlColorSpace)) {
        BOOL dlReady = [self applyFormatDL:videoFrame];
        BOOL cvReady = [self applyFormatCV:pixelBuffer];
        if (!(dlReady && cvReady)) return false;
    }
    
    BOOL formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    if (!formatOK) return false;
    
    @synchronized (self) {
        {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            free(argb8888Buffer.data); argb8888Buffer = {0};
            vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
        }
        
        vImage_Error matrixErr = kvImageInternalError;
        vImage_Error dlHostErr = kvImageInternalError;
        vImage_Error interimErr = kvImageInternalError;
        vImage_Error errCVtoCG = kvImageInternalError;
        vImage_Error errCGtoRGB12U = kvImageInternalError;
        {
            if (dlFormat == bmdFormat10BitYUV) {
                // conv: YUV10 <= either RGB8 or RGB16Q12; No RGB16U. See vImage/Conversion.h
                vImage_ARGBToYpCbCrMatrix matrix = matrixToYpCbCrFor(dlWidth, dlHeight);
                vImage_YpCbCrPixelRange pixelRange = videoRange10Clamped();
                vImage_ARGBToYpCbCr info = {0};
                vImageARGBType interimType = (dlDefault16Q12 ? kvImageARGB16Q12 : kvImageARGB8888);
                matrixErr = vImageConvert_ARGBToYpCbCr_GenerateConversion(&matrix,
                                                                          &pixelRange,
                                                                          &info,
                                                                          interimType,
                                                                          kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10,
                                                                          kvImageNoFlags);
                if (matrixErr == kvImageNoError) infoToYpCbCr = info;
            } else if (dlFormat == bmdFormat8BitYUV) {
                // conv: YUV8 <= RGB8 only; See vImage/Conversion.h
                vImage_ARGBToYpCbCrMatrix matrix = matrixToYpCbCrFor(dlWidth, dlHeight);
                vImage_YpCbCrPixelRange pixelRange = videoRange8Clamped();
                vImage_ARGBToYpCbCr info = {0};
                vImageARGBType interimType = (kvImageARGB8888);
                matrixErr = vImageConvert_ARGBToYpCbCr_GenerateConversion(&matrix,
                                                                          &pixelRange,
                                                                          &info,
                                                                          interimType,
                                                                          kvImage422CbYpCrYp8,
                                                                          kvImageNoFlags);
                if (matrixErr == kvImageNoError) {
                    infoToYpCbCr = info;
                    
                    // For dlUseXRGB16U: YUV8 <= RGB8 <= RGB16; See vImage/Conversion.h
                    if (dlUseXRGB16U) {
                        size_t rowBytes = (dlWidth * 4);
                        void* ptr = NULL;
                        size_t bufferSize = (rowBytes * dlHeight);
                        if (posix_memalign(&ptr, 16, bufferSize) == 0 && ptr != NULL) {
                            argb8888Buffer.data = ptr;
                            argb8888Buffer.width = dlWidth;
                            argb8888Buffer.height = dlHeight;
                            argb8888Buffer.rowBytes = rowBytes;
                        } else {
                            matrixErr = kvImageInternalError;
                        }
                    }
                }
            } else {
                // RGBtoTGB conversion
                matrixErr = kvImageNoError;
            }
            if (matrixErr) {
                NSLog(@"ERROR: vImageConvert_ARGBToYpCbCr_GenerateConversion() failed.");
            }
        }
        vImage_CGImageFormat interimFormat = {0};
        if (matrixErr == kvImageNoError) {
            void* ptr = NULL;
            size_t bufferSize = (dlRowBytes * dlHeight);
            if (posix_memalign(&ptr, 16, bufferSize) == 0 && ptr != NULL) {
                dlHostBuffer.data = ptr;
                dlHostBuffer.width = dlWidth;
                dlHostBuffer.height = dlHeight;
                dlHostBuffer.rowBytes = dlRowBytes;
                dlHostErr = kvImageNoError;
            }
        }
        if (dlHostErr == kvImageNoError) {
            CGColorSpaceRef cs = (useDLColorSpace? dlColorSpace : cvColorSpace);
            interimFormat = (dlUseXRGB16U ? formatXRGB16U(cs) :
                             (dlDefault16Q12 ? formatXRGB16Q12(cs) : formatXRGB8888(cs)));
            interimErr = vImageBuffer_Init(&interimBuffer,
                                           dlHeight, dlWidth, // rect of VideoFrame
                                           interimFormat.bitsPerPixel, kvImageNoFlags);
        }
        if (interimErr == kvImageNoError) {
            vImageCVImageFormatRef inFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer);
            if (inFormat) {
                assert(kvImageNoError == fillCVColorSpace(inFormat, cvColorSpace));
                assert(kvImageNoError == fillCVChromaSiting(inFormat, kCVImageBufferChromaLocation_Center));
                assert(kvImageNoError == fillCVConversionMatrix(inFormat, matrixToYpCbCrFor(dlWidth, dlHeight)));
                vImage_Flags flags = kvImageNoFlags; // kvImagePrintDiagnosticsToConsole
                CGFloat bgColor[3] = {0,0,0};
                convCVtoCG = vImageConverter_CreateForCVToCGImageFormat(inFormat,
                                                                        &interimFormat,
                                                                        bgColor,
                                                                        flags,
                                                                        &errCVtoCG);
                if (errCVtoCG || !convCVtoCG) {
                    NSLog(@"ERROR: vImageConverter_CreateForCVToCGImageFormat() failed.(%ld)", errCVtoCG);
                }
                vImageCVImageFormat_Release(inFormat);
                
                queryTempBuffer = TRUE;
                free(tempBuffer); tempBuffer = NULL;
            } else {
                NSLog(@"ERROR: vImageCVImageFormat_CreateWithCVPixelBuffer() failed.");
            }
        }
        if (errCVtoCG == kvImageNoError) {
            if (dlFormat == bmdFormat12BitRGB || dlFormat == bmdFormat12BitRGBLE) {
                CGColorSpaceRef cs = (useDLColorSpace? dlColorSpace : cvColorSpace);
                vImage_CGImageFormat outFormat = formatRGB12U(cs);
                CGFloat bgColor[3] = {0,0,0};
                convCGtoRGB12U = vImageConverter_CreateWithCGImageFormat(&interimFormat,
                                                                         &outFormat,
                                                                         bgColor,
                                                                         kvImageNoFlags,
                                                                         &errCGtoRGB12U);
                
                queryTemp1216Buffer = TRUE;
                free(temp1216Buffer); temp1216Buffer = NULL;
            } else {
                errCGtoRGB12U = kvImageNoError;
            }
        }
        
        BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCVtoCG != NULL);
        converterOK = converterOK && (errCGtoRGB12U == kvImageNoError);
        if (!converterOK) {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            free(argb8888Buffer.data); argb8888Buffer = {0};
            vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
            vImageConverter_Release(convCGtoRGB12U); convCGtoRGB12U = NULL;
        }
        return converterOK;
    }
}

- (BOOL)convertCV:(CVPixelBufferRef)pixelBuffer toDL:(IDeckLinkMutableVideoFrame*)videoFrame
{
    NSParameterAssert(pixelBuffer != NULL && videoFrame != NULL);
    
    //
    BOOL formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCVtoCG != NULL);
    if (!(formatOK && converterOK)) {
        return FALSE; // unsupported conversion
    }
    
    @synchronized (self) {
        /* ================================================================ */
        // CVPixelBuffer (convCVtoCG) interimBuffer (xfer) [dlHostBuffer (permute)] VideoFrame
        /* ================================================================ */
        
        vImage_Error convErr = kvImageNoError;
        {
            // Convert CVPixelBuffer format to interimBuffer
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            
            // source vImage_Buffer
            vImage_Buffer sourceBuffer = {0};
            vImage_Flags sourceFlags = kvImageNoAllocate;
            convErr = vImageBuffer_InitForCopyFromCVPixelBuffer(&sourceBuffer, convCVtoCG,
                                                                pixelBuffer, sourceFlags);
            if (convErr == kvImageNoError) {
                if (queryTempBuffer) {
                    queryTempBuffer = FALSE;
                    free(tempBuffer); tempBuffer = NULL;
                    vImage_Error size = vImageConvert_AnyToAny(convCVtoCG,
                                                               &sourceBuffer, &interimBuffer,
                                                               tempBuffer, kvImageGetTempBufferSize);
                    if (size > 0) {
                        void *ptr = NULL;
                        if (posix_memalign(&ptr, 16, (size_t)size) == 0 && ptr != NULL) {
                            tempBuffer = ptr;
                        } else {
                            return FALSE;
                        }
                    }
                }
                convErr = vImageConvert_AnyToAny(convCVtoCG,
                                                 &sourceBuffer, &interimBuffer,
                                                 tempBuffer, kvImageNoFlags);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        }
        if (convErr == kvImageNoError) {
            // target vImage_Buffer
            void* ptr = NULL;
            HRESULT result = videoFrame->GetBytes(&ptr);
            assert (result == S_OK && ptr != NULL);
            
            vImage_Buffer targetBuffer = {
                .data = ptr,
                .width = dlWidth,
                .height = dlHeight,
                .rowBytes = dlRowBytes
            };
            
            // Write into VideoFrame
            if (dlEndianSwap) {
                // Convert interimBuffer to VideoFrame format (in hostEndian)
                {
                    // bmdFormat10BitRGBX
                    // bmdFormat10BitRGB
                    // bmdFormat12BitRGB
                    convErr = [self vImageConvertInterim:&interimBuffer
                                                 toDLRGB:&dlHostBuffer
                                                   flags:kvImageNoFlags];
                }
                // Permute HostToBig
                if (convErr == kvImageNoError) {
                    uint8_t permuteMap[4] = {3,2,1,0};
                    convErr = vImagePermuteChannels_ARGB8888(&dlHostBuffer, &targetBuffer,
                                                             permuteMap, kvImageNoFlags);
                }
            } else {
                // Convert interimBuffer to VideoFrame format
                if (dlFormat == bmdFormat10BitYUV) { // v210
                    if (dlUseXRGB16U) {
                        // conv: YUV10 <= XRGB16Q12 <= XRGB16U
                        {
                            vImage_Buffer inPlace = interimBuffer;
                            inPlace.width = inPlace.width * 4;
                            convErr = vImageConvert_16Uto16Q12(&inPlace, &inPlace, kvImageNoFlags);
                        }
                        if (convErr == kvImageNoError) {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            convErr = vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(&interimBuffer,
                                                                                             &targetBuffer,
                                                                                             &infoToYpCbCr,
                                                                                             permuteMap,
                                                                                             kvImageNoFlags);
                        }
                    } else {
                        // conv: YUV10 <= XRGB16Q12
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(&interimBuffer,
                                                                                         &targetBuffer,
                                                                                         &infoToYpCbCr,
                                                                                         permuteMap,
                                                                                         kvImageNoFlags);
                    }
                } else if (dlFormat == bmdFormat8BitYUV) { // 2vuy
                    if (dlUseXRGB16U) {
                        // conv: YUV8 <= XRGB8 <= XRGB16U
                        {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            uint8_t copyMask = 0;
                            Pixel_8888 bgColor = {0,0,0,0};
                            convErr = vImageConvert_ARGB16UToARGB8888(&interimBuffer, &argb8888Buffer,
                                                                      permuteMap, copyMask, bgColor,
                                                                      kvImageNoFlags);
                        }
                        if (convErr == kvImageNoError) {
                            uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                            convErr = vImageConvert_ARGB8888To422CbYpCrYp8(&argb8888Buffer, &targetBuffer,
                                                                           &infoToYpCbCr, permuteMap,
                                                                           kvImageNoFlags);
                        }
                    } else {
                        // conv: YUV8 <= XRGB8
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_ARGB8888To422CbYpCrYp8(&interimBuffer, &targetBuffer,
                                                                       &infoToYpCbCr, permuteMap,
                                                                       kvImageNoFlags);
                    }
                } else {
                    // bmdFormat8BitARGB
                    // bmdFormat8BitBGRA
                    // bmdFormat10BitRGBXLE
                    // bmdFormat12BitRGBLE
                    convErr = [self vImageConvertInterim:&interimBuffer
                                                 toDLRGB:&targetBuffer
                                                   flags:kvImageNoFlags];
                }
            }
        }
        
        return (convErr == kvImageNoError);
    }
}

@end
