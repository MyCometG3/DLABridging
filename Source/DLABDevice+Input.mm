//
//  DLABDevice+Input.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDevice+Internal.h"

/* =================================================================================== */
// MARK: - input (internal)
/* =================================================================================== */

@implementation DLABDevice (InputInternal)

/* =================================================================================== */
// MARK: DLABInputCallbackDelegate
/* =================================================================================== */

- (void) didChangeVideoInputFormat:(BMDVideoInputFormatChangedEvents)events
                       displayMode:(IDeckLinkDisplayMode*)displayModeObj
                             flags:(BMDDetectedVideoInputFormatFlags)flags
{
    NSParameterAssert(events && displayModeObj && flags);
    
    id<DLABInputCaptureDelegate> delegate = self.inputDelegate;
    if (!delegate)
        return;
    
    // get current inputSetting parameters
    BMDPixelFormat pixelFormat = self.inputVideoSettingW.pixelFormat;
    BMDVideoInputFlags inputFlag = self.inputVideoSettingW.inputFlag;
    
    // decide new color space
    BOOL yuvColorSpaceNow = (pixelFormat == bmdFormat8BitYUV || pixelFormat == bmdFormat10BitYUV);
    BOOL yuv422Ready = (flags & bmdDetectedVideoInputYCbCr422);
    BOOL rgb444Ready = (flags & bmdDetectedVideoInputRGB444);
    if (yuvColorSpaceNow) {
        if (yuv422Ready) {
            // keep original yuv color space
        } else if (rgb444Ready) {
            pixelFormat = bmdFormat8BitARGB; // color space switch occured
        } else {
            pixelFormat = 0; // unexpected error - should suspend stream
        }
    } else {
        if (rgb444Ready) {
            // keep original rgb color space
        } else if (yuv422Ready) {
            pixelFormat = bmdFormat8BitYUV; // color space switch occured
        } else {
            pixelFormat = 0; // unexpected error - should suspend stream
        }
    }
    
    // Prepare new inputVideoSetting object
    DLABVideoSetting* tmpSetting = nil;
    if (pixelFormat) {
        tmpSetting = [[DLABVideoSetting alloc] initWithDisplayModeObj:displayModeObj
                                                          pixelFormat:pixelFormat
                                                       videoInputFlag:inputFlag];
        [tmpSetting buildVideoFormatDescriptionWithError:nil]; // TODO Handle error
    } else {
        // do nothing. let delegate handle the error.
    }
    
    // NOTE: tmpSetting could be nil.
    if (tmpSetting) {
        self.needsInputVideoConfigurationRefresh = TRUE;
    } else {
        // do nothing. let delegate handle the error.
    }
    
    // delegate will handle ChangeVideoInputFormatEvent
    __weak typeof(self) wself = self;
    [self delegate_async:^{
        [delegate processInputFormatChangeWithVideoSetting:tmpSetting
                                                    events:events
                                                     flags:flags
                                                  ofDevice:wself]; // async
    }];
}

- (void) didReceiveVideoInputFrame:(IDeckLinkVideoInputFrame*)videoFrame
                  audioInputPacket:(IDeckLinkAudioInputPacket*)audioPacket
{
    id<DLABInputCaptureDelegate> delegate = self.inputDelegate;
    if (!delegate)
        return;
    
    // Retain objects first - possible lengthy operation
    if (videoFrame) videoFrame->AddRef();
    if (audioPacket) audioPacket->AddRef();
    
    if (videoFrame) {
        // Create video sampleBuffer
        CMSampleBufferRef sampleBuffer = [self createVideoSampleForVideoFrame:videoFrame];
        
        // Create timecodeSetting
        DLABTimecodeSetting* setting = [self createTimecodeSettingOf:videoFrame];
        
        // Callback VANCHandler block
        if (sampleBuffer && setting && self.inputVANCHandler) {
            [self callbackInputVANCHandler:videoFrame];
        }
        
        // Callback VANCPacketHandler block
        if (sampleBuffer && setting && self.inputVANCPacketHandler) {
            [self callbackInputVANCPacketHandler:videoFrame];
        }
        
        // Callback InputFrameMetadataHandler block
        if (sampleBuffer && setting && self.inputFrameMetadataHandler) {
            [self callbackInputFrameMetadataHandler:videoFrame];
        }
        
        // delegate will handle InputVideoSampleBuffer
        if (sampleBuffer && setting) {
            __weak typeof(self) wself = self;
            [self delegate_async:^{
                [delegate processCapturedVideoSample:sampleBuffer
                                     timecodeSetting:setting
                                            ofDevice:wself]; // async
                CFRelease(sampleBuffer);
            }];
        } else if (sampleBuffer) {
            __weak typeof(self) wself = self;
            [self delegate_async:^{
                [delegate processCapturedVideoSample:sampleBuffer
                                            ofDevice:wself]; // async
                CFRelease(sampleBuffer);
            }];
        } else {
            // do nothing
        }
    }
    if (audioPacket) {
        // Create audio sampleBuffer
        CMSampleBufferRef sampleBuffer = [self createAudioSampleForAudioPacket:audioPacket];
        
        // delegate will handle InputAudioSampleBuffer
        if (sampleBuffer) {
            __weak typeof(self) wself = self;
            [self delegate_async:^{
                [delegate processCapturedAudioSample:sampleBuffer
                                            ofDevice:wself]; // async
                CFRelease(sampleBuffer);
            }];
        } else {
            // do nothing
        }
    }
    
    // Release objects
    if (videoFrame) videoFrame->Release();
    if (audioPacket) audioPacket->Release();
}

/* =================================================================================== */
// MARK: Process Input videoFrame/audioPacket
/* =================================================================================== */

NS_INLINE size_t pixelSizeForDL(IDeckLinkVideoFrame* videoFrame) {
    size_t pixelSize = 0;   // For vImageCopyBuffer()
    
    BMDPixelFormat format = videoFrame->GetPixelFormat();
    switch (format) {
        case bmdFormat8BitYUV:
            pixelSize = ceil( 4.0/2); break; // 4 bytes 2 pixels block
        case bmdFormat10BitYUV:
            pixelSize = ceil(16.0/6); break; // 16 bytes 6 pixels block
        case bmdFormat8BitARGB:
            pixelSize = ceil( 4.0/1); break; // 4 bytes 1 pixel block
        case bmdFormat8BitBGRA:
            pixelSize = ceil( 4.0/1); break; // 4 bytes 1 pixel block
        case bmdFormat10BitRGB:
            pixelSize = ceil( 4.0/1); break; // 4 bytes 1 pixel block
        case bmdFormat12BitRGB:
            pixelSize = ceil(36.0/8); break; // 36 bytes 8 pixel block
        case bmdFormat12BitRGBLE:
            pixelSize = ceil(36.0/8); break; // 36 bytes 8 pixel block
        case bmdFormat10BitRGBXLE:
            pixelSize = ceil( 4.0/1); break; // 4 bytes 1 pixel block
        case bmdFormat10BitRGBX:
            pixelSize = ceil( 4.0/1); break; // 4 bytes 1 pixel block
        default:
            break;
    }
    return pixelSize;
}

NS_INLINE size_t pixelSizeForCV(CVPixelBufferRef pixelBuffer) {
    size_t pixelSize = 0;   // For vImageCopyBuffer()
    {
        NSString* kBitsPerBlock = (__bridge NSString*)kCVPixelFormatBitsPerBlock;
        NSString* kBlockWidth = (__bridge NSString*)kCVPixelFormatBlockWidth;
        NSString* kBlockHeight = (__bridge NSString*)kCVPixelFormatBlockHeight;
        
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CFDictionaryRef pfDict = CVPixelFormatDescriptionCreateWithPixelFormatType(kCFAllocatorDefault, pixelFormat);
        NSDictionary* dict = CFBridgingRelease(pfDict);
        
        int numBitsPerBlock = ((NSNumber*)dict[kBitsPerBlock]).intValue;
        int numWidthPerBlock = MAX(1,((NSNumber*)dict[kBlockWidth]).intValue);
        int numHeightPerBlock = MAX(1,((NSNumber*)dict[kBlockHeight]).intValue);
        int numPixelPerBlock = numWidthPerBlock * numHeightPerBlock;
        pixelSize = ceil(numBitsPerBlock / numPixelPerBlock / 8.0);
    }
    return pixelSize;
}

NS_INLINE BOOL copyBufferDLtoCV(DLABDevice* self, IDeckLinkVideoFrame* videoFrame, CVPixelBufferRef pixelBuffer) {
    assert(videoFrame && pixelBuffer);
    
    bool result = FALSE;
    CVReturn err = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (!err) {
        void* src = NULL;
        void* dst = CVPixelBufferGetBaseAddress(pixelBuffer);
        videoFrame->GetBytes(&src);
        
        vImage_Buffer sourceBuffer = {0};
        sourceBuffer.data = src;
        sourceBuffer.width = videoFrame->GetWidth();
        sourceBuffer.height = videoFrame->GetHeight();
        sourceBuffer.rowBytes = videoFrame->GetRowBytes();
        
        vImage_Buffer targetBuffer = {0};
        targetBuffer.data = dst;
        targetBuffer.width = CVPixelBufferGetWidth(pixelBuffer);
        targetBuffer.height = CVPixelBufferGetHeight(pixelBuffer);
        targetBuffer.rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
        
        if (src && dst) {
            size_t pixelSize = 0;
            if (self.debugCalcPixelSizeFast) {
                pixelSize = pixelSizeForDL(videoFrame);
            } else {
                pixelSize = pixelSizeForCV(pixelBuffer);
            }
            assert(pixelSize > 0);
            
            vImage_Error convErr = kvImageNoError;
            convErr = vImageCopyBuffer(&sourceBuffer, &targetBuffer,
                                       pixelSize, kvImageNoFlags);
            result = (convErr == kvImageNoError);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    return result;
}

- (DLABTimecodeSetting*) createTimecodeSettingOf:(IDeckLinkVideoInputFrame*)videoFrame
                                          format:(BMDTimecodeFormat)format
{
    NSParameterAssert(videoFrame && format);
    
    HRESULT result = E_FAIL;
    
    IDeckLinkTimecode* timecodeObj = NULL;
    DLABTimecodeSetting* setting = nil;
    
    result = videoFrame->GetTimecode(format, &timecodeObj);
    if (!result && timecodeObj) {
        setting = [[DLABTimecodeSetting alloc] initWithTimecodeFormat:format
                                                          timecodeObj:timecodeObj];
    }
    return setting;
}

- (DLABTimecodeSetting*) createTimecodeSettingOf:(IDeckLinkVideoInputFrame*)videoFrame
{
    NSParameterAssert(videoFrame);
    
    // Check videoFrame
    DLABTimecodeSetting* setting = nil;
    
    BOOL useVITC = self.outputVideoSettingW.useVITC;
    BOOL useRP188 = self.outputVideoSettingW.useRP188;
    
    if (useVITC) {
        setting = [self createTimecodeSettingOf:videoFrame format:DLABTimecodeFormatVITC];
        if (setting) return setting;
        
        setting = [self createTimecodeSettingOf:videoFrame format:DLABTimecodeFormatVITCField2];
        if (setting) return setting;
    }
    if (useRP188) {
        setting = [self createTimecodeSettingOf:videoFrame format:DLABTimecodeFormatRP188VITC1];
        if (setting) return setting;
        
        setting = [self createTimecodeSettingOf:videoFrame format:DLABTimecodeFormatRP188VITC2];
        if (setting) return setting;
        
        setting = [self createTimecodeSettingOf:videoFrame format:DLABTimecodeFormatRP188LTC];
        if (setting) return setting;
    }
    return nil;
}

- (CVPixelBufferRef) createPixelBufferForVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame
{
    NSParameterAssert(videoFrame);
    
    BOOL ready = false;
    OSType cvPixelFormat = self.inputVideoSettingW.cvPixelFormatType;
    assert(cvPixelFormat);

    // Check pool, and create if required
    CVPixelBufferPoolRef pool = self.inputPixelBufferPool;
    if (pool == NULL) {
        // create new one using videoFrame parameters (lazy instatiation)
        NSString* minimunCountKey = (__bridge NSString *)kCVPixelBufferPoolMinimumBufferCountKey;
        NSDictionary *poolAttributes = @{minimunCountKey : @(4)};
        
        NSString* pixelFormatKey = (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey;
        NSString* widthKey = (__bridge NSString *)kCVPixelBufferWidthKey;
        NSString* heightKey = (__bridge NSString *)kCVPixelBufferHeightKey;
        NSString* bytesPerRowAlignmentKey = (__bridge NSString *)kCVPixelBufferBytesPerRowAlignmentKey;
        NSMutableDictionary* pbAttributes = [NSMutableDictionary dictionary];
        pbAttributes[pixelFormatKey] = @(cvPixelFormat);
        pbAttributes[widthKey] = @(videoFrame->GetWidth());
        pbAttributes[heightKey] = @(videoFrame->GetHeight());
        pbAttributes[bytesPerRowAlignmentKey] = @(16); // = 2^4 = 2 * sizeof(void*)
        
        CVReturn err = kCVReturnError;
        err = CVPixelBufferPoolCreate(NULL, (__bridge CFDictionaryRef)poolAttributes,
                                      (__bridge CFDictionaryRef)pbAttributes,
                                      &pool);
        if (err)
            return NULL;
        
        self.inputPixelBufferPool = pool;
        CVPixelBufferPoolRelease(pool);
    }
    
    // Create new pixelBuffer and copy image
    CVPixelBufferRef pixelBuffer = NULL;
    if (pool) {
        CVReturn err = kCVReturnError;
        err = CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &pixelBuffer);
        if (!err && pixelBuffer) {
            // Attach formatDescriptionExtensions to new PixelBuffer
            CFDictionaryRef dict = (__bridge CFDictionaryRef)self.inputVideoSettingW.extensions;
            assert(dict);
            CVBufferSetAttachments(pixelBuffer, dict, kCVAttachmentMode_ShouldPropagate);
        }
        if (!err && pixelBuffer) {
            // Simply check if width, height are same
            size_t pbWidth = CVPixelBufferGetWidth(pixelBuffer);
            size_t pbHeight = CVPixelBufferGetHeight(pixelBuffer);
            size_t ifWidth = videoFrame->GetWidth();
            size_t ifHeight = videoFrame->GetHeight();
            BOOL sizeOK = (pbWidth == ifWidth && pbHeight == ifHeight);
            
            BMDPixelFormat pixelFormat = videoFrame->GetPixelFormat();
            BOOL sameFormat = (pixelFormat == cvPixelFormat);
            if (sameFormat && sizeOK) {
                if (self.debugUsevImageCopyBuffer) {
                    ready = copyBufferDLtoCV(self, videoFrame, pixelBuffer);
                } else {
                    // Simply check if stride is same
                    size_t pbRowByte = CVPixelBufferGetBytesPerRow(pixelBuffer);
                    size_t ifRowByte = videoFrame->GetRowBytes();
                    BOOL rowByteOK = (pbRowByte == ifRowByte);
                    
                    // Copy pixel data from inputVideoFrame to CVPixelBuffer
                    err = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                    if (!err) {
                        // get buffer address for src and dst
                        void* dst = CVPixelBufferGetBaseAddress(pixelBuffer);
                        void* src = NULL;
                        videoFrame->GetBytes(&src);
                        
                        if (dst && src) {
                            if (rowByteOK) { // bulk copy
                                memcpy(dst, src, ifRowByte * ifHeight);
                            } else { // line copy with different stride
                                size_t length = MIN(pbRowByte, ifRowByte);
                                for (size_t line = 0; line < ifHeight; line++) {
                                    char* srcAddr = (char*)src + pbRowByte * line;
                                    char* dstAddr = (char*)dst + ifRowByte * line;
                                    memcpy(dstAddr, srcAddr, length);
                                }
                            }
                            ready = true;
                        }
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                    }
                }
            } else {
                // Use DLABVideoConverter/vImage to convert video image
                DLABVideoConverter *converter = self.inputVideoConverter;
                if (!converter) {
                    converter = [[DLABVideoConverter alloc] initWithDL:videoFrame
                                                                  toCV:pixelBuffer];
                    self.inputVideoConverter = converter;
                }
                if (converter) {
                    ready = [converter convertDL:videoFrame toCV:pixelBuffer];
                }
            }
        }
    }
    
    if (pixelBuffer && ready) {
        return pixelBuffer;
    } else {
        if (pixelBuffer)
            CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
}

- (CMSampleBufferRef) createVideoSampleForVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame
{
    NSParameterAssert(videoFrame);
    
    BMDFrameFlags flags = videoFrame->GetFlags();
    if ((flags & bmdFrameHasNoInputSource) != 0)
        return NULL;
    
    BMDTimeValue frameTime = 0;
    BMDTimeValue frameDuration = 0;
    BMDTimeScale timeScale = self.inputVideoSetting.timeScale;
    HRESULT result = videoFrame->GetStreamTime(&frameTime, &frameDuration, timeScale);
    
    if (result)
        return NULL;
    
    // unused
    // videoFrame->GetTimecode(...)
    // videoFrame->GetAncillaryData(...)
    // videoFrame->GetHardwareReferenceTimestamp(...)
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    
    // Check if refreshing pool is required (prior to create pixelbuffer)
    if (self.needsInputVideoConfigurationRefresh) {
        // Update InputVideoFormmatDescription using videoFrame
        BOOL result = [self.inputVideoSettingW updateInputVideoFormatDescriptionUsingVideoFrame:videoFrame];
        if (!result)
            return NULL;
        
        // Reset existing inputPixelBufferPool
        self.inputPixelBufferPool = nil;
        
        // Reset refresh flag
        self.needsInputVideoConfigurationRefresh = FALSE;
    }
    
    // Prepare format description (No ownership transfer)
    CMFormatDescriptionRef formatDescription = self.inputVideoSettingW.videoFormatDescription;
    if (!formatDescription)
        return NULL;
    
    // Create new pixelBuffer, copy image from videoFrame, and create sampleBuffer
    OSStatus err = noErr;
    CMSampleBufferRef sampleBuffer = NULL;
    CVPixelBufferRef pixelBuffer = [self createPixelBufferForVideoFrame:videoFrame];
    if (pixelBuffer) {
        // Copy formatDescription extensions to ImageBuffer attachments
        CMSetAttachments(pixelBuffer,
                         CMFormatDescriptionGetExtensions(formatDescription),
                         kCMAttachmentMode_ShouldPropagate);
        
        // Create CMSampleBuffer for videoFrame
        err = CMSampleBufferCreateReadyWithImageBuffer(NULL,
                                                       pixelBuffer,
                                                       formatDescription,
                                                       &timingInfo,
                                                       &sampleBuffer);
        
        // Free pixelBuffer
        CVPixelBufferRelease(pixelBuffer);
    }
    
    // Return Result
    if (!err && sampleBuffer) {
        return sampleBuffer;
    } else {
        NSLog(@"CMSampleBufferCreateReadyWithImageBuffer() returned %d", err);
        if (sampleBuffer)
            CFRelease(sampleBuffer);
        return NULL;
    }
}

- (CMSampleBufferRef) createAudioSampleForAudioPacket:(IDeckLinkAudioInputPacket*)audioPacket
{
    NSParameterAssert(audioPacket);
    
    // Validate audioPacket
    long frameCount = audioPacket->GetSampleFrameCount();
    
    void* buffer = NULL;
    HRESULT result1 = audioPacket->GetBytes(&buffer);
    
    BMDTimeValue packetTime = 0;
    BMDTimeScale timeScale = bmdAudioSampleRate48kHz;
    HRESULT result2 = audioPacket->GetPacketTime(&packetTime, timeScale);
    
    if (result1 || !buffer || result2)
        return NULL;
    
    // Prepare timinginfo struct
    CMTime duration = CMTimeMake(1, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(packetTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    // Prepare block info
    size_t numSamples = (size_t)frameCount;
    size_t sampleSize = (size_t)self.inputAudioSettingW.sampleSize;
    size_t blockLength = numSamples * sampleSize;
    CMBlockBufferFlags flags = (kCMBlockBufferAssureMemoryNowFlag);
    
    // Prepare format description (No ownership transfer)
    CMFormatDescriptionRef formatDescription = self.inputAudioSettingW.audioFormatDescriptionW;
    if (!formatDescription)
        return NULL;
    
    // Create CMBlockBuffer for audioPacket, copy sample data, and create sampleBuffer
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus err = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                      NULL,
                                                      blockLength,
                                                      NULL,
                                                      NULL,
                                                      0,
                                                      blockLength,
                                                      flags,
                                                      &blockBuffer);
    if (!err && blockBuffer) {
        // Copy sample data into blockBuffer
        err = CMBlockBufferReplaceDataBytes(buffer, blockBuffer, 0, blockLength);
        if (!err) {
            // Create CMSampleBuffer for audioPacket
            err = CMSampleBufferCreate(NULL,
                                       blockBuffer,
                                       TRUE,
                                       NULL,
                                       NULL,
                                       formatDescription,
                                       numSamples,
                                       1,
                                       &timingInfo,
                                       1,
                                       &sampleSize,
                                       &sampleBuffer);
        }
        
        // Free blockBuffer
        CFRelease(blockBuffer);
    }
    
    // Return Result
    if (!err && sampleBuffer) {
        return sampleBuffer;
    } else {
        if (sampleBuffer)
            CFRelease(sampleBuffer);
        return NULL;
    }
}

/* =================================================================================== */
// MARK: VANC support
/* =================================================================================== */

// private experimental - VANC Capture support

- (IDeckLinkVideoFrameAncillary*) prepareInputFrameAncillary:(IDeckLinkVideoInputFrame*)inFrame
{
    NSParameterAssert(inFrame);
    
    IDeckLinkVideoFrameAncillary *ancillaryData = NULL;
    inFrame->GetAncillaryData(&ancillaryData);
    
    return ancillaryData; // Nullable
}

- (void*) bufferOfInputFrameAncillary:(IDeckLinkVideoFrameAncillary*)ancillaryData
                                 line:(uint32_t)lineNumber
{
    NSParameterAssert(ancillaryData);
    
    void* buffer = NULL;
    ancillaryData->GetBufferForVerticalBlankingLine(lineNumber, &buffer);
    if (buffer) {
        return buffer;
    } else {
        NSLog(@"ERROR: VANC for lineNumber %d is not supported.", lineNumber);
        return NULL;
    }
}

- (void) callbackInputVANCHandler:(IDeckLinkVideoInputFrame*)inFrame
{
    NSParameterAssert(inFrame);
    
    // Validate input frame
    BMDFrameFlags flags = inFrame->GetFlags();
    if ((flags & bmdFrameHasNoInputSource) != 0) return;
    
    BMDTimeValue frameTime = 0;
    BMDTimeValue frameDuration = 0;
    BMDTimeScale timeScale = self.inputVideoSetting.timeScale;
    HRESULT result = inFrame->GetStreamTime(&frameTime, &frameDuration, timeScale);
    if (result) return;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    VANCHandler inHandler = self.inputVANCHandler;
    if (inHandler) {
        IDeckLinkVideoFrameAncillary* frameAncillary = [self prepareInputFrameAncillary:inFrame];
        if (frameAncillary) {
            // Callback in delegate queue
            [self delegate_sync:^{
                NSArray<NSNumber*>* lines = self.inputVANCLines;
                for (NSNumber* num in lines) {
                    int32_t lineNumber = num.intValue;
                    void* buffer = [self bufferOfInputFrameAncillary:frameAncillary line:lineNumber];
                    if (buffer) {
                        BOOL result = inHandler(timingInfo, lineNumber, buffer);
                        if (!result) break;
                    }
                }
            }];

            frameAncillary->Release();
        }
    }
}

// private experimental - VANC Packet Capture support

- (void) callbackInputVANCPacketHandler:(IDeckLinkVideoInputFrame*)inFrame
{
    NSParameterAssert(inFrame);
    
    // Validate input frame
    BMDFrameFlags flags = inFrame->GetFlags();
    if ((flags & bmdFrameHasNoInputSource) != 0) return;
    
    BMDTimeValue frameTime = 0;
    BMDTimeValue frameDuration = 0;
    BMDTimeScale timeScale = self.inputVideoSetting.timeScale;
    HRESULT result = inFrame->GetStreamTime(&frameTime, &frameDuration, timeScale);
    if (result) return;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    InputVANCPacketHandler inHandler = self.inputVANCPacketHandler;
    if (inHandler) {
        // Prepare for callback
        IDeckLinkVideoFrameAncillaryPackets* frameAncillaryPackets = NULL;
        inFrame->QueryInterface(IID_IDeckLinkVideoFrameAncillaryPackets,
                                (void**)&frameAncillaryPackets);
        if (frameAncillaryPackets) {
            IDeckLinkAncillaryPacketIterator* iterator = NULL;
            frameAncillaryPackets->GetPacketIterator(&iterator);
            if (iterator) {
                [self delegate_sync:^{
                    // Callback in delegate queue
                    while (TRUE) {
                        BOOL ready = FALSE;
                        IDeckLinkAncillaryPacket* packet = NULL;
                        iterator->Next(&packet);
                        if (packet) {
                            NSData* data = nil;
                            BMDAncillaryPacketFormat format = bmdAncillaryPacketFormatUInt8;
                            const void* ptr = NULL;
                            uint32_t size = 0;
                            packet->GetBytes(format, &ptr, &size);
                            if (ptr && size) {
                                data = [NSData dataWithBytesNoCopy:(void*)ptr
                                                            length:(NSUInteger)size
                                                      freeWhenDone:NO];
                            }
                            if (data) {
                                uint8_t did = packet->GetDID();
                                uint8_t sdid = packet->GetSDID();
                                uint32_t lineNumber = packet->GetLineNumber();
                                uint8_t dataStreamIndex = packet->GetDataStreamIndex();
                                ready = inHandler(timingInfo,
                                                  did, sdid, lineNumber, dataStreamIndex,
                                                  data);
                            }
                        }
                        if (!ready) break;
                    }
                }];
                
                iterator->Release();
            }
            
            frameAncillaryPackets->Release();
        }
    }
}

/* =================================================================================== */
// MARK: HDR Metadata support
/* =================================================================================== */

// private experimental - Input FrameMetadata support
- (DLABFrameMetadata*) callbackInputFrameMetadataHandler:(IDeckLinkVideoInputFrame*)inFrame
{
    NSParameterAssert(inFrame);
    
    BMDTimeValue frameTime = 0;
    BMDTimeValue frameDuration = 0;
    BMDTimeScale timeScale = self.inputVideoSetting.timeScale;
    HRESULT result = inFrame->GetStreamTime(&frameTime, &frameDuration, timeScale);
    if (result) return nil;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    InputFrameMetadataHandler inHandler = self.inputFrameMetadataHandler;
    if (inHandler) {
        // Create FrameMetadata for inFrame
        DLABFrameMetadata* frameMetadata = [[DLABFrameMetadata alloc] initWithInputFrame:inFrame];
        if (frameMetadata) {
            // Callback in delegate queue
            [self delegate_sync:^{
                inHandler(timingInfo, frameMetadata);
            }];
            return frameMetadata;
        }
    }
    return nil;
}

@end

/* =================================================================================== */
// MARK: - input (public)
/* =================================================================================== */

@implementation DLABDevice (Input)

/* =================================================================================== */
// MARK: Setting
/* =================================================================================== */

- (DLABVideoSetting*)createInputVideoSettingOfDisplayMode:(DLABDisplayMode)displayMode
                                              pixelFormat:(DLABPixelFormat)pixelFormat
                                                inputFlag:(DLABVideoInputFlag)videoInputFlag
                                                    error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    DLABVideoConnection videoConnection = DLABVideoConnectionUnspecified;
    DLABSupportedVideoModeFlag supportedVideoModeFlag = DLABSupportedVideoModeFlagDefault;
    DLABVideoSetting* setting = [self createInputVideoSettingOfDisplayMode:displayMode
                                                               pixelFormat:pixelFormat
                                                                 inputFlag:videoInputFlag
                                                                connection:videoConnection
                                                         supportedModeFlag:supportedVideoModeFlag
                                                                     error:error];
    
    return setting;
}

- (DLABVideoSetting*)createInputVideoSettingOfDisplayMode:(DLABDisplayMode)displayMode
                                              pixelFormat:(DLABPixelFormat)pixelFormat
                                                inputFlag:(DLABVideoInputFlag)videoInputFlag
                                               connection:(DLABVideoConnection)videoConnection
                                        supportedModeFlag:(DLABSupportedVideoModeFlag)supportedVideoModeFlag
                                                    error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    DLABVideoSetting* setting = nil;
    IDeckLinkInput *input = self.deckLinkInput;
    if (input) {
        __block HRESULT result = E_FAIL;
        __block BMDDisplayMode actualMode = 0;
        __block bool supported = false;
        __block bool pre1105 = (self.apiVersion < 0x0b050000); // 11.0-11.4; BLACKMAGIC_DECKLINK_API_VERSION
        [self capture_sync:^{
            if (!pre1105) {
                BMDVideoInputConversionMode convertMode = bmdNoVideoInputConversion;
                result = input->DoesSupportVideoMode(videoConnection,           // BMDVideoConnection = DLABVideoConnection
                                                     displayMode,               // BMDDisplayMode = DLABDisplayMode
                                                     pixelFormat,               // BMDPixelFormat = DLABPixelFormat
                                                     convertMode,               // BMDVideoInputConversionMode = DLABVideoInputConversionMode
                                                     supportedVideoModeFlag,    // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                     &actualMode,               // BMDDisplayMode = DLABDisplayMode
                                                     &supported);               // bool
            } else
            if (pre1105) {
                IDeckLinkInput_v11_4 *input1104 = (IDeckLinkInput_v11_4*)input;
                result = input1104->DoesSupportVideoMode(videoConnection,           // BMDVideoConnection = DLABVideoConnection
                                                         displayMode,               // BMDDisplayMode = DLABDisplayMode
                                                         pixelFormat,               // BMDPixelFormat = DLABPixelFormat
                                                         supportedVideoModeFlag,    // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                         &supported);               // bool
            }
        }];
        if (!result) {
            if (supported) {
                __block IDeckLinkDisplayMode* displayModeObj = NULL;
                [self capture_sync:^{
                    input->GetDisplayMode((actualMode > 0 ? actualMode : displayMode), &displayModeObj);
                }];
                setting = [[DLABVideoSetting alloc] initWithDisplayModeObj:displayModeObj
                                                               pixelFormat:pixelFormat
                                                            videoInputFlag:videoInputFlag];
                BOOL result = TRUE;
                result = [setting buildVideoFormatDescriptionWithError:error];
                displayModeObj->Release();
                if (!result) return nil;
            }
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkInput::DoesSupportVideoMode failed."
                  code:result
                    to:error];
            return nil;
        }
    }
    
    if (setting && setting.videoFormatDescription) {
        return setting;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported input video settings detected."
              code:E_INVALIDARG
                to:error];
        return nil;
    }
}

- (DLABAudioSetting*)createInputAudioSettingOfSampleType:(DLABAudioSampleType)sampleType
                                            channelCount:(uint32_t)channelCount
                                              sampleRate:(DLABAudioSampleRate)sampleRate
                                                   error:(NSError**)error
{
    NSParameterAssert(sampleType && channelCount && sampleRate);
    
    DLABAudioSetting* setting = nil;
    BOOL rateOK = (sampleRate == DLABAudioSampleRate48kHz);
    BOOL countOK = (channelCount > 0 && channelCount <= 16);
    BOOL typeOK = (sampleType == DLABAudioSampleType16bitInteger ||
                   sampleType == DLABAudioSampleType32bitInteger);
    
    if (rateOK && countOK && typeOK) {
        setting = [[DLABAudioSetting alloc] initWithSampleType:sampleType
                                                  channelCount:channelCount
                                                    sampleRate:sampleRate];
        BOOL result = [setting buildAudioFormatDescriptionWithError:error];
        if (!result) return nil;
    }
    
    if (setting && setting.audioFormatDescriptionW) {
        return setting;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported input audio settings detected."
              code:E_INVALIDARG
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: Video
/* =================================================================================== */

- (BOOL) setInputScreenPreviewToView:(NSView*)parentView
                               error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        if (parentView) {
            IDeckLinkScreenPreviewCallback* previewCallback = NULL;
            previewCallback = CreateCocoaScreenPreview((__bridge void*)parentView);
            
            if (previewCallback) {
                self.inputPreviewCallback = previewCallback;
                previewCallback->Release();
                
                [self capture_sync:^{
                    result = input->SetScreenPreviewCallback(previewCallback);
                }];
            }
        } else {
            if (self.inputPreviewCallback) {
                self.inputPreviewCallback = NULL;
                
                [self capture_sync:^{
                    result = input->SetScreenPreviewCallback(NULL);
                }];
            }
        }
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::SetScreenPreviewCallback failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableVideoInputWithVideoSetting:(DLABVideoSetting*)setting
                                    error:(NSError**)error
{
    NSParameterAssert(setting);
    
    __block HRESULT result = E_FAIL;
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        BMDDisplayMode displayMode = setting.displayMode;
        BMDVideoInputFlags inputFlag = setting.inputFlag;
        BMDPixelFormat format = setting.pixelFormat;
        
        [self capture_sync:^{
            result = input->EnableVideoInput(displayMode, format, inputFlag);
        }];
    }
    
    if (!result) {
        self.inputVideoSettingW = setting;
        self.needsInputVideoConfigurationRefresh = TRUE;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::EnableVideoInput failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableVideoInputWithVideoSetting:(DLABVideoSetting*)setting
                             onConnection:(DLABVideoConnection)connection
                                    error:(NSError **)error
{
    NSError *err = nil;
    BOOL result = [self setIntValue:connection
                   forConfiguration:DLABConfigurationVideoInputConnection
                              error:&err];
    if (!result) {
        *error = err;
        return NO;
    }
    return [self enableVideoInputWithVideoSetting:setting error:error];
}

- (NSNumber*) getAvailableVideoFrameCountWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block uint32_t availableFrameCount = 0;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->GetAvailableVideoFrameCount(&availableFrameCount);
        }];
    }
    
    if (!result) {
        return @(availableFrameCount);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::GetAvailableVideoFrameCount failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) disableVideoInputWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->DisableVideoInput();
        }];
    }
    
    if (!result) {
        self.inputVideoSettingW = nil;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::DisableVideoInput failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: Audio
/* =================================================================================== */

- (BOOL) enableAudioInputWithSetting:(DLABAudioSetting*)setting
                               error:(NSError**)error
{
    NSParameterAssert(setting);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        BMDAudioSampleRate sampleRate = setting.sampleRate;
        BMDAudioSampleType sampleType = setting.sampleType;
        uint32_t channelCount = setting.channelCount;
        
        [self capture_sync:^{
            result = input->EnableAudioInput(sampleRate, sampleType, channelCount);
        }];
    }
    
    if (!result) {
        self.inputAudioSettingW = setting;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::EnableAudioInput failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableAudioInputWithSetting:(DLABAudioSetting*)setting
                        onConnection:(DLABAudioConnection)connection
                               error:(NSError **)error
{
    NSError *err = nil;
    BOOL result = [self setIntValue:connection
                   forConfiguration:DLABConfigurationAudioInputConnection
                              error:&err];
    if (!result) {
        *error = err;
        return NO;
    }
    return [self enableAudioInputWithSetting:setting error:error];
}

- (BOOL) disableAudioInputWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->DisableAudioInput();
        }];
    }
    
    if (!result) {
        self.inputAudioSettingW = nil;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::DisableAudioInput failed."
              code:result
                to:error];
        return NO;
    }
}

- (NSNumber*) getAvailableAudioSampleFrameCountWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block uint32_t availableFrameCount = 0;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->GetAvailableAudioSampleFrameCount(&availableFrameCount);
        }];
    }
    
    if (!result) {
        return @(availableFrameCount);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::GetAvailableAudioSampleFrameCount failed."
              code:result
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: Stream
/* =================================================================================== */

- (BOOL) startStreamsWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self subscribeInput:YES];
        
        [self capture_sync:^{
            result = input->StartStreams();
        }];
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::StartStreams failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) stopStreamsWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->StopStreams();
        }];
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::StopStreams failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) flushStreamsWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->FlushStreams();
        }];
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::FlushStreams failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) pauseStreamsWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->PauseStreams();
        }];
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::PauseStreams failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: Clock
/* =================================================================================== */

- (BOOL) getInputHardwareReferenceClockInTimeScale:(NSInteger)timeScale
                                      hardwareTime:(NSInteger*)hardwareTime
                                       timeInFrame:(NSInteger*)timeInFrame
                                     ticksPerFrame:(NSInteger*)ticksPerFrame
                                             error:(NSError**)error
{
    NSParameterAssert(timeScale && hardwareTime && timeInFrame && ticksPerFrame);
    
    __block HRESULT result = E_FAIL;
    __block BMDTimeValue hwTime = 0;
    __block BMDTimeValue timeIF = 0;
    __block BMDTimeValue tickPF = 0;
    
    IDeckLinkInput* input = self.deckLinkInput;
    if (input) {
        [self capture_sync:^{
            result = input->GetHardwareReferenceClock(timeScale, &hwTime, &timeIF, &tickPF);
        }];
    }
    
    if (!result) {
        *hardwareTime = hwTime;
        *timeInFrame = timeIF;
        *ticksPerFrame = tickPF;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkInput::GetHardwareReferenceClock failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: HDMIInputEDID
/* =================================================================================== */

- (NSNumber*) intValueForHDMIInputEDID:(DLABDeckLinkHDMIInputEDID) hdmiInputEDID
                                 error:(NSError**)error
{
    IDeckLinkHDMIInputEDID *inputEDID = self.deckLinkHDMIInputEDID;
    if (inputEDID) {
        HRESULT result = E_FAIL;
        BMDDeckLinkHDMIInputEDIDID edid = hdmiInputEDID;
        int64_t newIntValue = 0;
        result = inputEDID->GetInt(edid, &newIntValue);
        if (!result) {
            return @(newIntValue);
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkHDMIInputEDID::GetInt failed."
                  code:result
                    to:error];
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkHDMIInputEDID is not supported."
              code:E_NOINTERFACE
                to:error];
    }
    return nil;
}

- (BOOL) setIntValue:(NSInteger)value
    forHDMIInputEDID:(DLABDeckLinkHDMIInputEDID) hdmiInputEDID
               error:(NSError**)error
{
    IDeckLinkHDMIInputEDID *inputEDID = self.deckLinkHDMIInputEDID;
    if (inputEDID) {
        HRESULT result = E_FAIL;
        BMDDeckLinkHDMIInputEDIDID edid = hdmiInputEDID;
        int64_t newIntValue = (int64_t)value;
        result = inputEDID->SetInt(edid, newIntValue);
        if (!result) {
            return YES;
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkHDMIInputEDID::SetInt failed."
                  code:result
                    to:error];
            return NO;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkHDMIInputEDID is not supported."
              code:E_NOINTERFACE
                to:error];
    }
    return FALSE;
}

- (BOOL) writeToHDMIInputEDIDWithError:(NSError**)error
{
    IDeckLinkHDMIInputEDID *inputEDID = self.deckLinkHDMIInputEDID;
    if (inputEDID) {
        HRESULT result = E_FAIL;
        result = inputEDID->WriteToEDID();
        if (!result) {
            return YES;
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkHDMIInputEDID::WriteToEDID failed."
                  code:result
                    to:error];
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkHDMIInputEDID is not supported."
              code:E_NOINTERFACE
                to:error];
    }
    return FALSE;
}

@end
