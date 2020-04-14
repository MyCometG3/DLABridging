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
@property (nonatomic, assign) uint32_t cvPixelBits;
@property (nonatomic, assign) BOOL cvEndianBig;

@property (nonatomic, assign) BMDPixelFormat dlFormat;
@property (nonatomic, assign) vImagePixelCount dlWidth;
@property (nonatomic, assign) vImagePixelCount dlHeight;
@property (nonatomic, assign) uint32_t dlPixelBits;
@property (nonatomic, assign) BOOL dlEndianBig;

@property (nonatomic, assign) int32_t dlRangeMin;
@property (nonatomic, assign) int32_t dlRangeMax;

@property (nonatomic, assign) vImage_Buffer dlHostBuffer; // dlBuffer in HostEndian
@property (nonatomic, assign) vImage_Buffer interimBuffer; // interim XRGB16U format (RGB444)
@property (nonatomic, assign) vImageConverterRef convCVtoCG; // for output converter from CV to XRGB16U
@property (nonatomic, assign) vImageConverterRef convCGtoCV; // for input converter from XRGB16U to CV;
@property (nonatomic, assign) void* tempBuffer;
@property (nonatomic, assign) BOOL queryTempBuffer;

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
// MARK: - Public accessor
/* =================================================================================== */

@synthesize dlColorSpace = dlColorSpace, cvColorSpace = cvColorSpace;
@synthesize useDLColorSpace = useDLColorSpace;

/* =================================================================================== */
// MARK: - Private accessor
/* =================================================================================== */

@synthesize cvFormat = cvFormat, cvPixelBits = cvPixelBits, cvEndianBig = cvEndianBig;
@synthesize cvWidth = cvWidth,   cvHeight = cvHeight;
@synthesize dlFormat = dlFormat, dlPixelBits = dlPixelBits, dlEndianBig = dlEndianBig;
@synthesize dlWidth = dlWidth,   dlHeight = dlHeight;
@synthesize dlRangeMin = dlRangeMin, dlRangeMax = dlRangeMax;

@synthesize dlHostBuffer = dlHostBuffer, interimBuffer = interimBuffer;
@synthesize convCVtoCG = convCVtoCG, convCGtoCV = convCGtoCV;
@synthesize queryTempBuffer = queryTempBuffer, tempBuffer = tempBuffer;

@synthesize useGammaSubstitute = useGammaSubstitute;

/* =================================================================================== */
// MARK: - Private methods
/* =================================================================================== */

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
    vImage_CGImageFormat formatXRGB16U = {
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

// MARK: -

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
    // ITU-R 2020 12bit
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
    // ITU-R 709 8bit/10bit, ITU-R 2020 10bit
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
    // ITU-R 601
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

// MARK: -

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

/*
NS_INLINE CGColorSpaceRef createColorSpaceNamedFor(size_t w, size_t h)
{
    // Use predefined CGColorSpace in CGColorSpace.h.
    CGColorSpaceRef cs = NULL;
    {
        CFStringRef csName = NULL;
        if (h <= 525) {
            //csName = notAvailableInHeader; // SD-525
        } else if (h <= 625) {
            //csName = notAvailableInHeader; // SD-625
        } else if (h <= 1125) {
            csName = kCGColorSpaceITUR_709; // HD (2K), 8 or 10 bits
        } else { //if (w > 1920) {
            csName = kCGColorSpaceITUR_2020; // HDR (4K/8K), 10 or 12 bits
        }
        if (csName) {
            cs = CGColorSpaceCreateWithName(csName); // owned - inferred
        }
    }
    return cs;
}
*/

// MARK: -

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
        // cs = createColorSpaceNamedFor(w, h);
        // if (!cs)
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
            // cs = createColorSpaceNamedFor(w, h);
            // if (!cs)
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

- (BOOL)applyFormatCV:(CVPixelBufferRef)pixelBuffer
{
    BOOL error = false;
    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    uint32_t pixelBits = 32;
    BOOL endianBig = false;
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (format) {
        case kCVPixelFormatType_16LE555:
        case kCVPixelFormatType_16LE5551:
        case kCVPixelFormatType_16LE565:
            pixelBits = 16; endianBig = false;
            break;
        case kCVPixelFormatType_30RGBLEPackedWideGamut: // (384-895)
        case kCVPixelFormatType_ARGB2101010LEPacked:
            pixelBits = 32; endianBig = false;
            break;
        case kCVPixelFormatType_14Bayer_GRBG:
        case kCVPixelFormatType_14Bayer_RGGB:
        case kCVPixelFormatType_14Bayer_BGGR:
        case kCVPixelFormatType_14Bayer_GBRG:
            pixelBits = 32; endianBig = false;
            break;
        case kCVPixelFormatType_16BE555:
        case kCVPixelFormatType_16BE565:
            pixelBits = 16; endianBig = true;
            break;
        case kCVPixelFormatType_30RGB:
            pixelBits = 32; endianBig = true;
            break;
        case kCVPixelFormatType_48RGB:
            pixelBits = 48; endianBig = true;
            break;
        case kCVPixelFormatType_64ARGB:
        case kCVPixelFormatType_64RGBAHalf:
            pixelBits = 64; endianBig = true;
            break;
        case kCVPixelFormatType_128RGBAFloat:
            pixelBits = 128; endianBig = true;
            break;
        case kCVPixelFormatType_24RGB:
        case kCVPixelFormatType_24BGR:
            pixelBits = 24; // 8bits per component
            break;
        case kCVPixelFormatType_32ARGB:
        case kCVPixelFormatType_32BGRA:
        case kCVPixelFormatType_32ABGR:
        case kCVPixelFormatType_32RGBA:
            pixelBits = 32; // 8bits per component
            break;
        default:
            error = true;
            break;
    }
    if (!error && width * height > 0) {
        CGColorSpaceRef cs = createColorSpaceForPixelBuffer(pixelBuffer, useGammaSubstitute);
        if (cs) {
            CGColorSpaceRelease(cvColorSpace);
            cvColorSpace = cs;

            cvFormat = format;
            cvWidth = width;
            cvHeight = height;
            cvPixelBits = pixelBits;
            cvEndianBig = endianBig;
            
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)applyFormatDL:(IDeckLinkVideoFrame*)videoFrame
{
    BOOL error = false;
    long width  = videoFrame->GetWidth();
    long height = videoFrame->GetHeight();
    uint32_t pixelBits = 32;
    BOOL endianBig = false;
    int32_t rangeMin = 64;
    int32_t rangeMax = 940;
    BMDPixelFormat format = videoFrame->GetPixelFormat();
    switch (format) {
        case bmdFormat8BitARGB:
            pixelBits = 32; endianBig = false;
            rangeMin = 0; rangeMax = 255;
            break;
        case bmdFormat8BitBGRA:
            pixelBits = 32; endianBig = false;
            rangeMin = 0; rangeMax = 255;
            break;
        case bmdFormat10BitRGB:     // 2101010 xRGB BigEndian
            pixelBits = 32; endianBig = true;
            rangeMin = 64; rangeMax = 960;
            break;
        case bmdFormat10BitRGBX:    // 1010102 RGBx BigEndian
            pixelBits = 32; endianBig = true;
            rangeMin = 64; rangeMax = 940;
            break;
        case bmdFormat10BitRGBXLE:  // 1010102 RGBx LittleEndian
            pixelBits = 32; endianBig = false;
            rangeMin = 64; rangeMax = 940;
            break;
        default:
            error = true;
            break;
    }
    if (!error && width * height > 0) {
        CGColorSpaceRef cs = createColorSpaceForVideoFrame(videoFrame, useGammaSubstitute);
        if (cs) {
            CGColorSpaceRelease(dlColorSpace);
            dlColorSpace = cs;

            dlFormat = format;
            dlWidth = width;
            dlHeight = height;
            dlPixelBits = pixelBits;
            dlEndianBig = endianBig;
            dlRangeMin = rangeMin;
            dlRangeMax = rangeMax;
            
            return TRUE;
        }
    }
    return FALSE;
}

/* =================================================================================== */
// MARK: - Public methods
/* =================================================================================== */

- (void)cleanup
{
    @synchronized (self) {
        CGColorSpaceRelease(dlColorSpace); dlColorSpace = NULL;
        CGColorSpaceRelease(cvColorSpace); cvColorSpace = NULL;
        useDLColorSpace = FALSE;
        useGammaSubstitute = FALSE;
        
        free(dlHostBuffer.data); dlHostBuffer = {0};
        free(interimBuffer.data); interimBuffer = {0};
        vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
        vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
        free(tempBuffer); tempBuffer = NULL;
        queryTempBuffer = TRUE;
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
    
    BOOL formatOK = false;
    if (cvColorSpace && dlColorSpace) {
        formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    }
    if (!formatOK) return false;

    @synchronized (self) {
        {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
        }
        
        vImage_Error dlHostErr = kvImageInternalError;
        vImage_Error interimErr = kvImageInternalError;
        vImage_Error errCGtoCV = kvImageInternalError;
        vImage_CGImageFormat interimFormat = {0};
        if (useDLColorSpace) {
            interimFormat = formatXRGB16U(dlColorSpace); // colorspace conversion may occur
        } else {
            interimFormat = formatXRGB16U(cvColorSpace); // treat as same colorspace
        }
        {
            dlHostErr = vImageBuffer_Init(&dlHostBuffer,
                                          dlHeight, dlWidth,
                                          dlPixelBits, kvImageNoFlags);
        }
        if (dlHostErr == kvImageNoError) {
            interimErr = vImageBuffer_Init(&interimBuffer,
                                           dlHeight, dlWidth, // rect of VideoFrame
                                           interimFormat.bitsPerPixel, kvImageNoFlags);
        }
        if (interimErr == kvImageNoError) {
            vImageCVImageFormatRef outFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer);
            if (outFormat) {
                vImageCVImageFormat_SetColorSpace(outFormat, cvColorSpace);
                convCGtoCV = vImageConverter_CreateForCGToCVImageFormat(&interimFormat,
                                                                        outFormat,
                                                                        NULL, // CGFloat[3]
                                                                        kvImageNoFlags,
                                                                        &errCGtoCV);
                vImageCVImageFormat_Release(outFormat);
            }
        }
        
        BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCGtoCV != NULL);
        if (!converterOK) {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            vImageConverter_Release(convCGtoCV); convCGtoCV = NULL;
        }
        return converterOK;
    }
}

- (BOOL)convertDL:(IDeckLinkVideoFrame*)videoFrame toCV:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(videoFrame != NULL && pixelBuffer != NULL);

    //
    BOOL formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCVtoCG != NULL);
    if (!(formatOK && converterOK)) {
        return FALSE; // unsupported conversion
    }
    
    @synchronized (self) {
        /* ================================================================ */
        // VideoFrame (permute) dlHostBuffer (xfer) XRGB16U (convCGtoCV) CVPixelBuffer
        /* ================================================================ */
        
        vImage_Error convErr = kvImageNoError;
        {
            // source vImage_Buffer
            void* ptr = NULL;
            HRESULT result = videoFrame->GetBytes(&ptr);
            assert (result == S_OK && ptr != NULL);
            
            vImage_Buffer sourceBuffer = {0};
            sourceBuffer.data = ptr;
            sourceBuffer.width = (vImagePixelCount)videoFrame->GetWidth();
            sourceBuffer.height = (vImagePixelCount)videoFrame->GetHeight();
            sourceBuffer.rowBytes = (size_t)videoFrame->GetRowBytes();
            
            // Read from VideoFrame
            if (dlEndianBig) {
                {
                    // Permute BigToHost
                    uint8_t permuteMap[4] = {3,2,1,0};
                    convErr = vImagePermuteChannels_ARGB8888(&sourceBuffer, &dlHostBuffer,
                                                             permuteMap, kvImageNoFlags);
                }
                if (convErr == kvImageNoError) {
                    // Convert VideoFrame format (in hostEndian) to XRGB16U
                    if (dlFormat == bmdFormat10BitRGBX) { // 1010102 BE
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_RGBA1010102ToARGB16U(&dlHostBuffer, &interimBuffer,
                                                                     dlRangeMin, dlRangeMax,
                                                                     permuteMap, kvImageNoFlags);
                    } else if (dlFormat == bmdFormat10BitRGB) { // 2101010 BE
                        uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                        convErr = vImageConvert_ARGB2101010ToARGB16U(&dlHostBuffer, &interimBuffer,
                                                                     dlRangeMin, dlRangeMax,
                                                                     permuteMap, kvImageNoFlags);
                    } else {
                        convErr = kvImageInternalError;
                    }
                }
            } else {
                // Convert VideoFrame format to XRGB16U
                if (dlFormat == bmdFormat10BitRGBXLE) { // 1010102 LE
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    convErr = vImageConvert_RGBA1010102ToARGB16U(&sourceBuffer, &interimBuffer,
                                                                 dlRangeMin, dlRangeMax,
                                                                 permuteMap, kvImageNoFlags);
                } else if (dlFormat == bmdFormat8BitARGB) {
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    Pixel_ARGB_16U bgColor = {0,0,0,0};
                    convErr = vImageConvert_ARGB8888ToARGB16U(&sourceBuffer, &interimBuffer,
                                                              permuteMap, 0x0,
                                                              bgColor, kvImageNoFlags);
                } else if (dlFormat == bmdFormat8BitBGRA) {
                    uint8_t permuteMap[4] = {3,2,1,0}; // componentOrder: B3, G2, R1, A0
                    Pixel_ARGB_16U bgColor = {0,0,0,0};
                    convErr = vImageConvert_ARGB8888ToARGB16U(&sourceBuffer, &interimBuffer,
                                                              permuteMap, 0x0,
                                                              bgColor, kvImageNoFlags);
                } else {
                    convErr = kvImageInternalError;
                }
            }
        }
        if (convErr == kvImageNoError) {
            // Convert XRGB16U to CVPixelBuffer format
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
                    if (size > 0)
                        posix_memalign(&tempBuffer, 16, (size_t)size);
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
    
    BOOL formatOK = false;
    if (cvColorSpace && dlColorSpace) {
        formatOK = [self compatibleWithDL:videoFrame andCV:pixelBuffer];
    }
    if (!formatOK) return false;

    @synchronized (self) {
        {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
        }
        
        vImage_Error dlHostErr = kvImageInternalError;
        vImage_Error interimErr = kvImageInternalError;
        vImage_Error errCVtoCG = kvImageInternalError;
        vImage_CGImageFormat interimFormat = {0};
        if (useDLColorSpace) {
            interimFormat = formatXRGB16U(dlColorSpace); // colorspace conversion may occur
        } else {
            interimFormat = formatXRGB16U(cvColorSpace); // treat as same colorspace
        }
        {
            dlHostErr = vImageBuffer_Init(&dlHostBuffer,
                                          dlHeight, dlWidth,
                                          dlPixelBits, kvImageNoFlags);
        }
        if (dlHostErr == kvImageNoError) {
            interimErr = vImageBuffer_Init(&interimBuffer,
                                           cvHeight, cvWidth, // rect of pixelBuffer
                                           interimFormat.bitsPerPixel, kvImageNoFlags);
        }
        if (interimErr == kvImageNoError) {
            vImageCVImageFormatRef inFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer);
            if (inFormat) {
                vImageCVImageFormat_SetColorSpace(inFormat, cvColorSpace);
                convCVtoCG = vImageConverter_CreateForCVToCGImageFormat(inFormat,
                                                                        &interimFormat,
                                                                        NULL, // CGFloat[3],
                                                                        kvImageNoFlags,
                                                                        &errCVtoCG);
                vImageCVImageFormat_Release(inFormat);
            }
        }
        
        BOOL converterOK = (dlHostBuffer.data != NULL && interimBuffer.data != NULL && convCVtoCG != NULL);
        if (!converterOK) {
            free(dlHostBuffer.data); dlHostBuffer = {0};
            free(interimBuffer.data); interimBuffer = {0};
            vImageConverter_Release(convCVtoCG); convCVtoCG = NULL;
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
        // CVPixelBuffer (convCVtoCG) XRGB16U (xfer) dlHostBuffer (permute) VideoFrame
        /* ================================================================ */
        
        vImage_Error convErr = kvImageNoError;
        {
            // Convert CVPixelBuffer format to XRGB16U
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
                    if (size > 0)
                        posix_memalign(&tempBuffer, 16, (size_t)size);
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
            
            vImage_Buffer targetBuffer = {0};
            targetBuffer.data = ptr;
            targetBuffer.width = (vImagePixelCount)videoFrame->GetWidth();
            targetBuffer.height = (vImagePixelCount)videoFrame->GetHeight();
            targetBuffer.rowBytes = (size_t)videoFrame->GetRowBytes();
            
            // Write into VideoFrame
            if (dlEndianBig) {
                // Convert XRGB16U to VideoFrame format (in hostEndian)
                if (dlFormat == bmdFormat10BitRGBX) { // 1010102 BE
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    convErr = vImageConvert_ARGB16UToRGBA1010102(&interimBuffer, &dlHostBuffer,
                                                                 dlRangeMin, dlRangeMax,
                                                                 permuteMap, kvImageNoFlags);
                } else if (dlFormat == bmdFormat10BitRGB) { // 2101010 BE
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    convErr = vImageConvert_ARGB16UToARGB2101010(&interimBuffer, &dlHostBuffer,
                                                                 dlRangeMin, dlRangeMax,
                                                                 permuteMap, kvImageNoFlags);
                } else {
                    convErr = kvImageInternalError;
                }
                if (convErr == kvImageNoError) {
                    // Permute HostToBig
                    uint8_t permuteMap[4] = {3,2,1,0};
                    convErr = vImagePermuteChannels_ARGB8888(&dlHostBuffer, &targetBuffer,
                                                             permuteMap, kvImageNoFlags);
                }
            } else {
                // Convert XRGB16U to VideoFrame format
                if (dlFormat == bmdFormat10BitRGBXLE) { // 1010102 LE
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    convErr = vImageConvert_ARGB16UToRGBA1010102(&interimBuffer, &targetBuffer,
                                                                 dlRangeMin, dlRangeMax,
                                                                 permuteMap, kvImageNoFlags);
                } else if (dlFormat == bmdFormat8BitARGB) {
                    uint8_t permuteMap[4] = {0,1,2,3}; // componentOrder: A0, R1, G2, B3
                    Pixel_8888 bgColor = {0,0,0,0};
                    convErr = vImageConvert_ARGB16UToARGB8888(&interimBuffer, &targetBuffer,
                                                              permuteMap, 0x0,
                                                              bgColor, kvImageNoFlags);
                } else if (dlFormat == bmdFormat8BitBGRA) {
                    uint8_t permuteMap[4] = {3,2,1,0}; // componentOrder: B3, G2, R1, A0
                    Pixel_8888 bgColor = {0,0,0,0};
                    convErr = vImageConvert_ARGB16UToARGB8888(&interimBuffer, &targetBuffer,
                                                              permuteMap, 0x0,
                                                              bgColor, kvImageNoFlags);
                } else {
                    convErr = kvImageInternalError;
                }
            }
        }
        
        return (convErr == kvImageNoError);
    }
}

@end
