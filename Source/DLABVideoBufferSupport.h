#pragma once

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <DeckLinkAPI.h>

#include <math.h>

NS_INLINE size_t pixelSizeForDL(IDeckLinkVideoFrame* videoFrame)
{
    size_t pixelSize = 0;   // For vImageCopyBuffer()
    
    BMDPixelFormat format = videoFrame->GetPixelFormat();
    switch (format) {
        case bmdFormat8BitYUV:
            pixelSize = ceil(4.0 / 2); break; // 4 bytes 2 pixels block
        case bmdFormat10BitYUV:
            pixelSize = ceil(16.0 / 6); break; // 16 bytes 6 pixels block
        case bmdFormat8BitARGB:
            pixelSize = ceil(4.0 / 1); break; // 4 bytes 1 pixel block
        case bmdFormat8BitBGRA:
            pixelSize = ceil(4.0 / 1); break; // 4 bytes 1 pixel block
        case bmdFormat10BitRGB:
            pixelSize = ceil(4.0 / 1); break; // 4 bytes 1 pixel block
        case bmdFormat12BitRGB:
            pixelSize = ceil(36.0 / 8); break; // 36 bytes 8 pixel block
        case bmdFormat12BitRGBLE:
            pixelSize = ceil(36.0 / 8); break; // 36 bytes 8 pixel block
        case bmdFormat10BitRGBXLE:
            pixelSize = ceil(4.0 / 1); break; // 4 bytes 1 pixel block
        case bmdFormat10BitRGBX:
            pixelSize = ceil(4.0 / 1); break; // 4 bytes 1 pixel block
        default:
            break;
    }
    return pixelSize;
}

NS_INLINE size_t pixelSizeForCV(CVPixelBufferRef pixelBuffer)
{
    size_t pixelSize = 0;   // For vImageCopyBuffer()
    {
        NSString* kBitsPerBlock = (__bridge NSString*)kCVPixelFormatBitsPerBlock;
        NSString* kBlockWidth = (__bridge NSString*)kCVPixelFormatBlockWidth;
        NSString* kBlockHeight = (__bridge NSString*)kCVPixelFormatBlockHeight;
        
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CFDictionaryRef pfDict = CVPixelFormatDescriptionCreateWithPixelFormatType(kCFAllocatorDefault, pixelFormat);
        NSDictionary* dict = CFBridgingRelease(pfDict);
        
        int numBitsPerBlock = ((NSNumber*)dict[kBitsPerBlock]).intValue;
        int numWidthPerBlock = MAX(1, ((NSNumber*)dict[kBlockWidth]).intValue);
        int numHeightPerBlock = MAX(1, ((NSNumber*)dict[kBlockHeight]).intValue);
        int numPixelPerBlock = numWidthPerBlock * numHeightPerBlock;
        if (numPixelPerBlock) {
            pixelSize = ceil(numBitsPerBlock / numPixelPerBlock / 8.0);
        }
    }
    return pixelSize;
}

NS_INLINE BOOL VideoBufferLockBaseAddress(IDeckLinkVideoFrame* videoFrame,
                                          BMDBufferAccessFlags accessFlags,
                                          IDeckLinkVideoBuffer** outVideoBuffer)
{
    if (!videoFrame || !outVideoBuffer) return NO;
    *outVideoBuffer = NULL;
    
    IDeckLinkVideoBuffer* buf = NULL;
    HRESULT hr = videoFrame->QueryInterface(IID_IDeckLinkVideoBuffer, (void**)&buf);
    if (FAILED(hr)) return NO;
    
    hr = buf->StartAccess(accessFlags);
    if (FAILED(hr)) {
        buf->Release();
        return NO;
    }
    
    *outVideoBuffer = buf; // caller owns one ref
    return YES;
}

NS_INLINE BOOL VideoBufferGetBaseAddress(IDeckLinkVideoBuffer* videoBuffer, void** pointer)
{
    if (!videoBuffer || !pointer) return NO;
    *pointer = NULL;
    
    HRESULT hr = videoBuffer->GetBytes(pointer);
    return SUCCEEDED(hr) && (*pointer != NULL);
}

NS_INLINE void VideoBufferUnlockBaseAddress(IDeckLinkVideoBuffer* videoBuffer,
                                            BMDBufferAccessFlags accessFlags)
{
    if (!videoBuffer) return;
    (void)videoBuffer->EndAccess(accessFlags);
    videoBuffer->Release();
}
