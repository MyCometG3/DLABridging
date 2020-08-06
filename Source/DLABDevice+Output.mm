//
//  DLABDevice+Output.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDevice+Internal.h"

/* =================================================================================== */
// MARK: - output (internal)
/* =================================================================================== */

@implementation DLABDevice (OutputInternal)

/* =================================================================================== */
// MARK: DLABOutputCallbackDelegate
/* =================================================================================== */

- (void)scheduledFrameCompleted:(IDeckLinkVideoFrame *)frame
                         result:(BMDOutputFrameCompletionResult)result
{
    NSParameterAssert(frame);
    
    // TODO eval BMDOutputFrameCompletionResult here
    // TODO eval GetFrameCompletionReferenceTimestamp() here
    
    // free output frame
    [self releaseOutputVideoFrame:(IDeckLinkMutableVideoFrame *)frame];
    
    // delegate can schedule next frame here
    __weak typeof(self) wself = self;
    id<DLABOutputPlaybackDelegate> delegate = self.outputDelegate;
    [self delegate_async:^{
        [delegate renderVideoFrameOfDevice:wself]; // async
    }];
}

- (void)renderAudioSamplesPreroll:(BOOL)preroll
{
    __weak typeof(self) wself = self;
    id<DLABOutputPlaybackDelegate> delegate = self.outputDelegate;
    [self delegate_async:^{
        [delegate renderAudioSamplesOfDevice:wself]; // async
    }];
}

- (void)scheduledPlaybackHasStopped
{
    // delegate can schedule next frame here
    __weak typeof(self) wself = self;
    id<DLABOutputPlaybackDelegate> delegate = self.outputDelegate;
    [self delegate_async:^{
        [delegate scheduledPlaybackHasStoppedOfDevice:wself]; // async
    }];
}

/* =================================================================================== */
// MARK: Manage output VideoFrame pool
/* =================================================================================== */

- (BOOL) prepareOutputVideoFramePool
{
    BOOL ret = NO;
    HRESULT result = E_FAIL;
    DLABVideoSetting* setting = self.outputVideoSetting;
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output && setting) {
        @synchronized (self) {
            // Set initial pool size as 4 frames
            BOOL initialSetup = (self.outputVideoFrameSet.count == 0);
            int expandingUnit = initialSetup ? 4 : 2;
            
            BOOL needsExpansion = (self.outputVideoFrameIdleSet.count == 0);
            if (needsExpansion) {
                // Get frame properties
                int32_t width = (int32_t)setting.width;
                int32_t height = (int32_t)setting.height;
                int32_t rowBytes = (int32_t)setting.rowBytes;
                BMDPixelFormat pixelFormat = setting.pixelFormat;
                BMDFrameFlags flags = setting.outputFlag;
                
                // Try expanding the OutputVideoFramePool
                for (int i = 0; i < expandingUnit; i++) {
                    // Check if pool size is at maximum value
                    BOOL poolIsFull = (self.outputVideoFrameSet.count >= maxOutputVideoFrameCount);
                    if (poolIsFull) break;
                    
                    // Create new output videoFrame object
                    IDeckLinkMutableVideoFrame *outFrame = NULL;
                    result = output->CreateVideoFrame(width, height, rowBytes,
                                                      pixelFormat, flags, &outFrame);
                    if (result) break;
                    
                    // register outputVideoFrame into the pool
                    NSValue* ptrValue = [NSValue valueWithPointer:(void*)outFrame];
                    [self.outputVideoFrameSet addObject:ptrValue];
                    [self.outputVideoFrameIdleSet addObject:ptrValue];
                }
            }
            ret = (self.outputVideoFrameIdleSet.count > 0);
        }
    }
    return ret;
}

- (void) freeOutputVideoFramePool
{
    @synchronized (self) {
        // Release all outputVideoFrame objects
        for (NSValue *ptrValue in self.outputVideoFrameSet) {
            IDeckLinkMutableVideoFrame *outFrame = (IDeckLinkMutableVideoFrame*)ptrValue.pointerValue;
            if (outFrame) {
                outFrame->Release();
            }
        }
        
        // unregister all of outputVideoFrame in the pool
        [self.outputVideoFrameIdleSet removeAllObjects];
        [self.outputVideoFrameSet removeAllObjects];
    }
}

- (IDeckLinkMutableVideoFrame*) reserveOutputVideoFrame
{
    // Check if all are in use (and try to expand the pool)
    [self prepareOutputVideoFramePool];
    
    IDeckLinkMutableVideoFrame *outFrame = NULL;
    @synchronized (self) {
        NSValue* ptrValue = [self.outputVideoFrameIdleSet anyObject];
        if (ptrValue) {
            [self.outputVideoFrameIdleSet removeObject:ptrValue];
            outFrame = (IDeckLinkMutableVideoFrame*)ptrValue.pointerValue;
        }
    }
    
    return outFrame;
}

- (BOOL) releaseOutputVideoFrame:(IDeckLinkMutableVideoFrame*)outFrame
{
    BOOL result = NO;
    @synchronized (self) {
        NSValue* ptrValue = [NSValue valueWithPointer:(void*)outFrame];
        NSValue* orgValue = [self.outputVideoFrameSet member:ptrValue];
        if (orgValue) {
            [self.outputVideoFrameIdleSet addObject:orgValue];
            result = YES;
        }
    }
    return result;
}

/* =================================================================================== */
// MARK: Process Output videoFrame/timecode
/* =================================================================================== */

NS_INLINE size_t pixelSizeForDL(IDeckLinkMutableVideoFrame* videoFrame) {
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
        if (numPixelPerBlock) {
            pixelSize = ceil(numBitsPerBlock / numPixelPerBlock / 8.0);
        }
    }
    return pixelSize;
}

NS_INLINE BOOL copyBufferCVtoDL(DLABDevice* self, CVPixelBufferRef pixelBuffer, IDeckLinkMutableVideoFrame* videoFrame) {
    assert(pixelBuffer && videoFrame);
    
    bool result = FALSE;
    CVReturn err = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (!err) {
        void* src = CVPixelBufferGetBaseAddress(pixelBuffer);
        void* dst = NULL;
        videoFrame->GetBytes(&dst);
        
        vImage_Buffer sourceBuffer = {0};
        sourceBuffer.data = src;
        sourceBuffer.width = CVPixelBufferGetWidth(pixelBuffer);
        sourceBuffer.height = CVPixelBufferGetHeight(pixelBuffer);
        sourceBuffer.rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
        
        vImage_Buffer targetBuffer = {0};
        targetBuffer.data = dst;
        targetBuffer.width = videoFrame->GetWidth();
        targetBuffer.height = videoFrame->GetHeight();
        targetBuffer.rowBytes = videoFrame->GetRowBytes();
        
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
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
    return result;
}

NS_INLINE BOOL copyPlaneCVtoDL(CVPixelBufferRef pixelBuffer, IDeckLinkMutableVideoFrame* videoFrame) {
    assert(pixelBuffer && videoFrame);
    
    BOOL ready = FALSE;
    
    // Simply check if stride is same
    size_t pbRowByte = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t ofRowByte = (size_t)videoFrame->GetRowBytes();
    size_t ofHeight = videoFrame->GetHeight();
    BOOL rowByteOK = (pbRowByte == ofRowByte);
    
    // Copy pixel data from CVPixelBuffer to outputVideoFrame
    CVReturn err = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (!err) {
        // get buffer address for src and dst
        void* dst = NULL;
        void* src = CVPixelBufferGetBaseAddress(pixelBuffer);
        videoFrame->GetBytes(&dst);
        
        if (dst && src) {
            if (rowByteOK) { // bulk copy
                memcpy(dst, src, ofRowByte * ofHeight);
            } else { // line copy with different stride
                size_t length = MIN(pbRowByte, ofRowByte);
                for (size_t line = 0; line < ofHeight; line++) {
                    char* srcAddr = (char*)src + pbRowByte * line;
                    char* dstAddr = (char*)dst + ofRowByte * line;
                    memcpy(dstAddr, srcAddr, length);
                }
            }
            ready = true;
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
    return ready;
}

- (IDeckLinkMutableVideoFrame*) outputVideoFrameWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(pixelBuffer);
    
    BOOL ready = false;
    OSType cvPixelFormat = self.inputVideoSetting.cvPixelFormatType;
    assert(cvPixelFormat);
    
    // take out free output frame from frame pool
    IDeckLinkMutableVideoFrame* videoFrame = [self reserveOutputVideoFrame];
    if (videoFrame) {
        // Simply check if width, height are same
        size_t pbWidth = CVPixelBufferGetWidth(pixelBuffer);
        size_t pbHeight = CVPixelBufferGetHeight(pixelBuffer);
        size_t ofWidth = videoFrame->GetWidth();
        size_t ofHeight = videoFrame->GetHeight();
        BOOL sizeOK = (pbWidth == ofWidth && pbHeight == ofHeight);
        
        BMDPixelFormat pixelFormat = videoFrame->GetPixelFormat();
        BOOL sameFormat = (pixelFormat == cvPixelFormat);
        if (sameFormat && sizeOK) {
            if (self.debugUsevImageCopyBuffer) {
                ready = copyBufferCVtoDL(self, pixelBuffer, videoFrame);
            } else {
                ready = copyPlaneCVtoDL(pixelBuffer, videoFrame);
            }
        } else {
            // Use DLABVideoConverter/vImage to convert video image
            DLABVideoConverter *converter = self.outputVideoConverter;
            if (!converter) {
                converter = [[DLABVideoConverter alloc] initWithCV:pixelBuffer
                                                              toDL:videoFrame];
                self.outputVideoConverter = converter;
            }
            if (converter) {
                ready = [converter convertCV:pixelBuffer toDL:videoFrame];
            }
        }
    }
    
    if (videoFrame && ready) {
        return videoFrame;
    } else {
        if (videoFrame)
            [self releaseOutputVideoFrame:videoFrame];
        return NULL;
    }
}

- (BOOL) validateTimecodeFormat:(DLABTimecodeFormat)format
                   videoSetting:(DLABVideoSetting*)outputVideoSetting
{
    BOOL validTimecode = NO;
    
    BOOL useVITC = outputVideoSetting.useVITC;
    BOOL useRP188 = outputVideoSetting.useRP188;
    
    BOOL SERIAL = (format == DLABTimecodeFormatSerial);
    BOOL VITCF1 = (format == DLABTimecodeFormatVITC);
    BOOL VITCF2 = (format == DLABTimecodeFormatVITCField2);
    BOOL RP188VITC1 = (format == DLABTimecodeFormatRP188VITC1);
    BOOL RP188VITC2 = (format == DLABTimecodeFormatRP188VITC2);
    BOOL RP188LTC = (format == DLABTimecodeFormatRP188LTC);
    BOOL RP188ANY = (format == DLABTimecodeFormatRP188Any);
    
    if ((useVITC || useRP188) && SERIAL)
        validTimecode = YES;        // Accept any serial timecode
    if (useVITC && (VITCF1 || VITCF2) )
        validTimecode = YES;        // SD uses VITC
    if (useRP188 && (RP188VITC1 || RP188VITC2 || RP188LTC || RP188ANY) )
        validTimecode = YES;        // HD uses RP188
    
    if (!validTimecode) {
        NSLog(@"ERROR: Invalid timecode setting found.");
    }
    
    return validTimecode;
}

/* =================================================================================== */
// MARK: VANC support
/* =================================================================================== */

// private experimental - VANC Playback support

- (IDeckLinkVideoFrameAncillary*) prepareOutputFrameAncillary:(IDeckLinkMutableVideoFrame*)outFrame
{
    NSParameterAssert(outFrame);
    
    IDeckLinkVideoFrameAncillary *ancillaryData = NULL;
    outFrame->GetAncillaryData(&ancillaryData);
    
    if (!ancillaryData) {
        // Create new one and attach to outFrame
        IDeckLinkOutput *output = self.deckLinkOutput;
        if (output) {
            output->CreateAncillaryData(outFrame->GetPixelFormat(), &ancillaryData);
            if (ancillaryData) {
                outFrame->SetAncillaryData(ancillaryData);
                ancillaryData->Release();
                ancillaryData = NULL;   // Ensure nullify
            }
        }
        
        // Issue Another query.
        outFrame->GetAncillaryData(&ancillaryData);
    }
    
    return ancillaryData; // Nullable
}

- (void*) bufferOfOutputFrameAncillary:(IDeckLinkVideoFrameAncillary*)ancillaryData
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

- (void) callbackOutputVANCHandler:(IDeckLinkMutableVideoFrame*)outFrame
                            atTime:(NSInteger)displayTime
                          duration:(NSInteger)frameDuration
                       inTimeScale:(NSInteger)timeScale
{
    NSParameterAssert(outFrame && frameDuration && timeScale);
    
    int64_t frameTime = displayTime;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    VANCHandler outHandler = self.outputVANCHandler;
    if (outHandler) {
        IDeckLinkVideoFrameAncillary* frameAncillary = [self prepareOutputFrameAncillary:outFrame];
        if (frameAncillary) {
            // Callback in delegate queue
            [self delegate_sync:^{
                NSArray<NSNumber*>* lines = self.outputVANCLines;
                for (NSNumber* num in lines) {
                    int32_t lineNumber = num.intValue;
                    void* buffer = [self bufferOfOutputFrameAncillary:frameAncillary line:lineNumber];
                    if (buffer) {
                        BOOL result = outHandler(timingInfo, lineNumber, buffer);
                        if (!result) break;
                    }
                }
            }];
            
            frameAncillary->Release();
        }
    }
}

// private experimental - VANC Packet Playback support

- (void) callbackOutputVANCPacketHandler:(IDeckLinkMutableVideoFrame*)outFrame
                                  atTime:(NSInteger)displayTime
                                duration:(NSInteger)frameDuration
                             inTimeScale:(NSInteger)timeScale
{
    NSParameterAssert(outFrame && frameDuration && timeScale);
    
    //
    int64_t frameTime = displayTime;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    OutputVANCPacketHandler outHandler = self.outputVANCPacketHandler;
    if (outHandler) {
        // Prepare for callback
        IDeckLinkVideoFrameAncillaryPackets* frameAncillaryPackets = NULL;
        outFrame->QueryInterface(IID_IDeckLinkVideoFrameAncillaryPackets,
                                 (void**)&frameAncillaryPackets);
        if (frameAncillaryPackets) {
            [self delegate_sync:^{
                // Callback in delegate queue
                while (TRUE) {
                    BOOL ready = FALSE;
                    DLABAncillaryPacket* packet = new DLABAncillaryPacket();
                    if (packet) {
                        uint8_t did = 0;
                        uint8_t sdid = 0;
                        uint32_t lineNumber = 0;
                        uint8_t dataStreamIndex = 0;
                        NSData* data = outHandler(timingInfo,
                                                  &did, &sdid, &lineNumber, &dataStreamIndex);
                        if (data) {
                            HRESULT ret = packet->Update(did, sdid, lineNumber, dataStreamIndex,
                                                         data);
                            if (ret == S_OK) {
                                ret = frameAncillaryPackets->AttachPacket(packet);
                            }
                            ready = (ret == S_OK);
                        }
                        delete packet;
                    }
                    if (!ready) break;
                }
            }];
            
            frameAncillaryPackets->Release();
        }
    }
}

/* =================================================================================== */
// MARK: HDR Metadata support
/* =================================================================================== */

// private experimental - Output FrameMetadata support
- (DLABFrameMetadata*) callbackOutputFrameMetadataHandler:(IDeckLinkMutableVideoFrame*)outFrame
                                                   atTime:(NSInteger)displayTime
                                                 duration:(NSInteger)frameDuration
                                              inTimeScale:(NSInteger)timeScale
{
    NSParameterAssert(outFrame && frameDuration && timeScale);
    
    int64_t frameTime = displayTime;
    
    // Create timinginfo struct
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    //
    OutputFrameMetadataHandler outHandler = self.outputFrameMetadataHandler;
    if (outHandler) {
        // Create FrameMetadata for outFrame
        __block BOOL apply = FALSE;
        DLABFrameMetadata* frameMetadata = [[DLABFrameMetadata alloc] initWithOutputFrame:outFrame];
        if (frameMetadata) {
            // Callback in delegate queue
            [self delegate_sync:^{
                apply = outHandler(timingInfo, frameMetadata);
            }];
        }
        if (apply) {
            return frameMetadata;
        }
    }
    return nil;
}

@end

/* =================================================================================== */
// MARK: - output (public)
/* =================================================================================== */

@implementation DLABDevice (Output)

/* =================================================================================== */
// MARK: Setting
/* =================================================================================== */

- (DLABVideoSetting*)createOutputVideoSettingOfDisplayMode:(DLABDisplayMode)displayMode
                                               pixelFormat:(DLABPixelFormat)pixelFormat
                                                outputFlag:(DLABVideoOutputFlag)videoOutputFlag
                                                     error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    DLABVideoConnection videoConnection = DLABVideoConnectionUnspecified;
    DLABSupportedVideoModeFlag supportedVideoModeFlag = DLABSupportedVideoModeFlagDefault;
    DLABVideoSetting* setting = [self createOutputVideoSettingOfDisplayMode:displayMode
                                                                pixelFormat:pixelFormat
                                                                 outputFlag:videoOutputFlag
                                                                 connection:videoConnection
                                                          supportedModeFlag:supportedVideoModeFlag
                                                                      error:error];
    
    return setting;
}

- (DLABVideoSetting*)createOutputVideoSettingOfDisplayMode:(DLABDisplayMode)displayMode
                                               pixelFormat:(DLABPixelFormat)pixelFormat
                                                outputFlag:(DLABVideoOutputFlag)videoOutputFlag
                                                connection:(DLABVideoConnection)videoConnection
                                         supportedModeFlag:(DLABSupportedVideoModeFlag)supportedVideoModeFlag
                                                     error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    DLABVideoSetting* setting = nil;
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        __block HRESULT result = E_FAIL;
        __block BMDDisplayMode actualMode = 0;
        __block bool supported = false;
        __block bool pre1105 = (self.apiVersion < 0x0b050000); // 11.0-11.4; BLACKMAGIC_DECKLINK_API_VERSION
        [self playback_sync:^{
            if (!pre1105) {
                BMDVideoOutputConversionMode convertMode = bmdNoVideoOutputConversion;
                result = output->DoesSupportVideoMode(videoConnection,          // BMDVideoConnection = DLABVideoConnection
                                                      displayMode,              // BMDDisplayMode = DLABDisplayMode
                                                      pixelFormat,              // BMDPixelFormat = DLABPixelFormat
                                                      convertMode,              // BMDVideoOutputConversionMode = DLABVideoOutputConversionMode
                                                      supportedVideoModeFlag,   // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                      &actualMode,              // BMDDisplayMode = DLABDisplayMode
                                                      &supported);              // bool
            }
            if (pre1105) {
                IDeckLinkOutput_v11_4 *output1104 = (IDeckLinkOutput_v11_4*)output;
                result = output1104->DoesSupportVideoMode(videoConnection,          // BMDVideoConnection = DLABVideoConnection
                                                          displayMode,              // BMDDisplayMode = DLABDisplayMode
                                                          pixelFormat,              // BMDPixelFormat = DLABPixelFormat
                                                          supportedVideoModeFlag,   // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                          &actualMode,              // BMDDisplayMode = DLABDisplayMode
                                                          &supported);              // bool
            }
        }];
        if (result) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkOutput::DoesSupportVideoMode failed."
                  code:result
                    to:error];
            return nil;
        }
        if (supported) {
            __block IDeckLinkDisplayMode* displayModeObj = NULL;
            [self playback_sync:^{
                output->GetDisplayMode((actualMode > 0 ? actualMode : displayMode), &displayModeObj);
            }];
            if (displayModeObj) {
                setting = [[DLABVideoSetting alloc] initWithDisplayModeObj:displayModeObj
                                                               pixelFormat:pixelFormat
                                                           videoOutputFlag:videoOutputFlag];
                if (setting) {
                    [setting buildVideoFormatDescriptionWithError:error];
                }
                displayModeObj->Release();
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    if (setting && setting.videoFormatDescription) {
        return setting;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported output video settings detected."
              code:E_INVALIDARG
                to:error];
        return setting;
    }
}

- (DLABAudioSetting*)createOutputAudioSettingOfSampleType:(DLABAudioSampleType)sampleType
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
        if (setting) {
            [setting buildAudioFormatDescriptionWithError:error];
        }
    }
    
    if (setting && setting.audioFormatDescriptionW) {
        return setting;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Unsupported output audio settings detected."
              code:E_INVALIDARG
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: Video
/* =================================================================================== */

- (NSNumber*) isScheduledPlaybackRunningWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block bool newBoolValue = FALSE;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->IsScheduledPlaybackRunning(&newBoolValue);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    if (!result) {
        return @(newBoolValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::IsScheduledPlaybackRunning failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) setOutputScreenPreviewToView:(NSView*)parentView
                                error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        if (parentView) {
            IDeckLinkScreenPreviewCallback* previewCallback = NULL;
            previewCallback = CreateCocoaScreenPreview((__bridge void*)parentView);
            
            if (previewCallback) {
                self.outputPreviewCallback = previewCallback;
                previewCallback->Release();
                
                [self playback_sync:^{
                    result = output->SetScreenPreviewCallback(previewCallback);
                }];
            }
        } else {
            if (self.outputPreviewCallback) {
                self.outputPreviewCallback = NULL;
                
                [self playback_sync:^{
                    result = output->SetScreenPreviewCallback(NULL);
                }];
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::SetScreenPreviewCallback failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableVideoOutputWithVideoSetting:(DLABVideoSetting*)setting
                                     error:(NSError **)error
{
    NSParameterAssert(setting);
    
    __block HRESULT result = E_FAIL;
    BMDDisplayMode displayMode = setting.displayMode;
    BMDVideoOutputFlags outputFlag = setting.outputFlag;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->EnableVideoOutput(displayMode, outputFlag);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        self.outputVideoSettingW = setting;
        return YES;
    } else {
        self.outputVideoSettingW = nil;
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::EnableVideoOutput failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableVideoOutputWithVideoSetting:(DLABVideoSetting*)setting
                              onConnection:(DLABVideoConnection)connection
                                     error:(NSError **)error
{
    NSError *err = nil;
    BOOL result = [self setIntValue:connection
                   forConfiguration:DLABConfigurationVideoOutputConnection
                              error:&err];
    if (!result) {
        *error = err;
        return NO;
    }
    return [self enableVideoOutputWithVideoSetting:setting error:error];
}

- (BOOL) disableVideoOutputWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->DisableVideoOutput();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        self.outputVideoSettingW = nil;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::DisableVideoOutput failed."
              code:result
                to:error];
        return NO;
    }
}

static DLABFrameMetadata * processCallbacks(DLABDevice *self, IDeckLinkMutableVideoFrame *outFrame, NSInteger displayTime, NSInteger frameDuration, NSInteger timeScale) {
    DLABFrameMetadata* frameMetadata = nil;
    
    // Callback VANCHandler block
    if (self.outputVANCHandler) {
        [self callbackOutputVANCHandler:outFrame
                                 atTime:displayTime
                               duration:frameDuration
                            inTimeScale:timeScale];
    }
    
    // Callback VANCPacketHandler block
    if (self.outputVANCPacketHandler) {
        [self callbackOutputVANCPacketHandler:outFrame
                                       atTime:displayTime
                                     duration:frameDuration
                                  inTimeScale:timeScale];
    }
    
    // Callback OutputFrameMetadataHandler block
    if (self.outputFrameMetadataHandler) {
        frameMetadata = [self callbackOutputFrameMetadataHandler:outFrame
                                                          atTime:displayTime
                                                        duration:frameDuration
                                                     inTimeScale:timeScale];
    }
    
    return frameMetadata;
}

- (BOOL) instantPlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                error:(NSError**)error
{
    NSParameterAssert(pixelBuffer);
    
    HRESULT result = E_FAIL;
    IDeckLinkMutableVideoFrame* outFrame = NULL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        // Copy pixel data into output frame
        CFRetain(pixelBuffer);
        outFrame = [self outputVideoFrameWithPixelBuffer:pixelBuffer];
        CFRelease(pixelBuffer);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (outFrame) {
        // dummy Time/Duration/TimeScale values
        NSInteger displayTime = 0;
        NSInteger frameDuration = self.outputVideoSetting.duration;
        NSInteger timeScale = self.outputVideoSetting.timeScale;
        
        // process callbacks
        DLABFrameMetadata* frameMetadata = processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
        
        // sync display - blocking operation
        if (!frameMetadata) {
            result = output->DisplayVideoFrameSync(outFrame);
        } else {
            result = output->DisplayVideoFrameSync(frameMetadata.metaframe);
        }
        
        // free output frame
        [self releaseOutputVideoFrame:outFrame];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABDevice - outputVideoFrameWithPixelBuffer: failed."
              code:paramErr
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        if (outFrame) {
            [self releaseOutputVideoFrame:outFrame];
        }
        
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::DisplayVideoFrameSync failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                atTime:(NSInteger)displayTime
                              duration:(NSInteger)frameDuration
                           inTimeScale:(NSInteger)timeScale
                                 error:(NSError**)error
{
    NSParameterAssert(pixelBuffer && frameDuration && timeScale);
    
    // Copy pixel data into output frame
    IDeckLinkMutableVideoFrame* outFrame = NULL;
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        CFRetain(pixelBuffer);
        outFrame = [self outputVideoFrameWithPixelBuffer:pixelBuffer];
        CFRelease(pixelBuffer);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    HRESULT result = E_FAIL;
    if (outFrame) {
        // process callbacks
        DLABFrameMetadata* frameMetadata = processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
        
        // async display
        if (!frameMetadata) {
            result = output->ScheduleVideoFrame(outFrame, displayTime, frameDuration, timeScale);
        } else {
            result = output->ScheduleVideoFrame(frameMetadata.metaframe, displayTime, frameDuration, timeScale);
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABDevice - outputVideoFrameWithPixelBuffer: failed."
              code:paramErr
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        if (outFrame) {
            [self releaseOutputVideoFrame:outFrame];
        }
        
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::ScheduleVideoFrame failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                atTime:(NSInteger)displayTime
                              duration:(NSInteger)frameDuration
                           inTimeScale:(NSInteger)timeScale
                       timecodeSetting:(DLABTimecodeSetting*)timecodeSetting
                                 error:(NSError* _Nullable *)error
{
    NSParameterAssert(pixelBuffer && frameDuration && timeScale && timecodeSetting);
    
    // Validate timecode format and outputVideoSetting combination
    DLABVideoSetting *videoSetting = self.outputVideoSetting;
    if (videoSetting) {
        BOOL validTimecode = NO;
        DLABTimecodeFormat format = timecodeSetting.format;
        validTimecode = [self validateTimecodeFormat:format
                                        videoSetting:videoSetting];
        
        // Reject other combination
        if (!validTimecode) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Unsupported timecode settings detected."
                  code:E_INVALIDARG
                    to:error];
            return NO;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABVideoSetting is not available."
              code:paramErr
                to:error];
        return NO;
    }
    
    // Copy pixel data into output frame
    IDeckLinkMutableVideoFrame* outFrame = NULL;
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        CFRetain(pixelBuffer);
        outFrame = [self outputVideoFrameWithPixelBuffer:pixelBuffer];
        CFRelease(pixelBuffer);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    NSString* reason = nil;
    HRESULT result = E_FAIL;
    if (outFrame) {
        // write timecode into outFrame
        result = outFrame->SetTimecodeFromComponents(timecodeSetting.format,
                                                     timecodeSetting.hour,
                                                     timecodeSetting.minute,
                                                     timecodeSetting.second,
                                                     timecodeSetting.frame,
                                                     timecodeSetting.flags);
        if (!result) {
            // write userBits into outFrame
            result = outFrame->SetTimecodeUserBits(timecodeSetting.format, timecodeSetting.userBits);
            if (!result) {
                // process callbacks
                DLABFrameMetadata* frameMetadata = processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
                
                // async display
                if (!frameMetadata) {
                    result = output->ScheduleVideoFrame(outFrame, displayTime, frameDuration, timeScale);
                } else {
                    result = output->ScheduleVideoFrame(frameMetadata.metaframe, displayTime, frameDuration, timeScale);
                }
                if (result) {
                    reason = @"IDeckLinkOutput::ScheduleVideoFrame failed";
                }
            } else {
                reason = @"IDeckLinkMutableVideoFrame::SetTimecodeUserBits failed";
            }
        } else {
            reason = @"IDeckLinkMutableVideoFrame::SetTimecodeFromComponents failed.";
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABDevice - outputVideoFrameWithPixelBuffer: failed."
              code:paramErr
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        if (outFrame) {
            [self releaseOutputVideoFrame:outFrame];
        }
        
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:reason
              code:result
                to:error];
        return NO;
    }
}

- (NSNumber*) getBufferedVideoFrameCountWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block uint32_t bufferedFrameCount = 0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->GetBufferedVideoFrameCount(&bufferedFrameCount);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    if (!result) {
        return @(bufferedFrameCount);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::GetBufferedVideoFrameCount failed."
              code:result
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: Audio
/* =================================================================================== */

- (BOOL) enableAudioOutputWithAudioSetting:(DLABAudioSetting*)setting
                                     error:(NSError**)error
{
    NSParameterAssert(setting);
    
    __block HRESULT result = E_FAIL;
    BMDAudioSampleType sampleType = setting.sampleType;
    uint32_t channelCount = setting.channelCount;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->EnableAudioOutput(DLABAudioSampleRate48kHz,
                                               sampleType,
                                               channelCount,
                                               DLABAudioOutputStreamTypeContinuous);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        self.outputAudioSettingW = setting;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::EnableAudioOutput failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableAudioOutputWithAudioSetting:(DLABAudioSetting*)setting
                                  onSwitch:(DLABAudioOutputSwitch)audioOutputSwitch
                                     error:(NSError**)error
{
    NSError *err = nil;
    BOOL result = [self setIntValue:audioOutputSwitch
                   forConfiguration:DLABConfigurationAudioOutputAESAnalogSwitch
                              error:&err];
    if (!result) {
        *error = err;
        return NO;
    }
    return [self enableAudioOutputWithAudioSetting:setting error:error];
}


- (BOOL) disableAudioOutputWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->DisableAudioOutput();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        self.outputAudioSettingW = nil;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::DisableAudioOutput failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) instantPlaybackOfAudioBufferList:(AudioBufferList*)audioBufferList
                             writtenCount:(NSUInteger*)sampleFramesWritten
                                    error:(NSError**)error
{
    NSParameterAssert(audioBufferList && sampleFramesWritten);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    DLABAudioSetting *setting = self.outputAudioSetting;
    if (output && setting) {
        __block uint32_t writtenTotal = 0;
        uint32_t mBytesPerFrame = setting.sampleSize;
        uint32_t mNumChannels = setting.channelCount;
        uint32_t mNumberBuffers = audioBufferList->mNumberBuffers;
        
        if (mNumberBuffers) {
            // Support multiple audioBuffers
            [self playback_sync:^{
                for (int index = 0; index < mNumberBuffers; index++) {
                    // Accept only interleaved buffer
                    AudioBuffer ab = audioBufferList->mBuffers[index];
                    if (!ab.mDataByteSize || !ab.mData) break;
                    if (ab.mNumberChannels != mNumChannels) break;
                    
                    // Queue audioSampleFrames
                    void* dataPointer = ab.mData;
                    uint32_t sampleFrameCount = ab.mDataByteSize / mBytesPerFrame;
                    uint32_t written = 0;
                    result = output->WriteAudioSamplesSync(dataPointer, sampleFrameCount, &written);
                    
                    // Update queuing status
                    writtenTotal += written;
                    
                    // Validate all available sampleFrames are queued or not
                    if (!result && sampleFrameCount != written) {
                        // result = E_ABORT; // TODO Queuing buffer is full
                    }
                    if (result) break;
                }
            }];
            
            if (writtenTotal) {
                *sampleFramesWritten = writtenTotal;
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Either IDeckLinkOutput or DLABAudioSetting is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::WriteAudioSamplesSync failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) instantPlaybackOfAudioBlockBuffer:(CMBlockBufferRef)blockBuffer
                                    offset:(size_t)byteOffset
                              writtenCount:(NSUInteger*)sampleFramesWritten
                                     error:(NSError**)error
{
    NSParameterAssert(blockBuffer && sampleFramesWritten);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    DLABAudioSetting *setting = self.outputAudioSetting;
    if (output && setting) {
        __block uint32_t writtenTotal = 0;
        uint32_t mBytesPerFrame = setting.sampleSize;
        size_t totalLength = 0;
        
        if (blockBuffer) {
            // validate blockBuffer is accessible
            OSStatus err = CMBlockBufferAssureBlockMemory(blockBuffer);
            if (!err) {
                totalLength = CMBlockBufferGetDataLength(blockBuffer);
            }
        }
        if (totalLength) {
            // Support non-contiguous CMBlockBuffer
            [self playback_sync:^{
                size_t offset = byteOffset;
                while (offset < totalLength) {
                    // Get data pointer and available length at offset
                    size_t lengthAtOffset = 0;
                    char* dataPointer = NULL;
                    OSStatus err = CMBlockBufferGetDataPointer(blockBuffer,
                                                               offset,
                                                               &lengthAtOffset,
                                                               NULL,
                                                               &dataPointer);
                    
                    result = E_INVALIDARG;
                    if (err || lengthAtOffset == 0 || !dataPointer) {
                        break; // Offset of memory in BlockBuffer is not ready
                    }
                    if ((lengthAtOffset % mBytesPerFrame) != 0) {
                        break; // AudioSampleFrame alignment error detected
                    }
                    
                    // Queue audioSampleFrames
                    uint32_t sampleFrameCount = ((uint32_t)lengthAtOffset / mBytesPerFrame);
                    uint32_t written = 0;
                    result = output->WriteAudioSamplesSync((void*)dataPointer,
                                                           sampleFrameCount,
                                                           &written);
                    
                    // Update queuing status
                    offset += (written * mBytesPerFrame);
                    writtenTotal += written;
                    
                    // Validate all available sampleFrames are queued or not
                    if (!result && sampleFrameCount != written) {
                        // result = E_ABORT; // TODO Queuing buffer is full
                    }
                    if (result) break;
                }
            }];
            
            if (writtenTotal) {
                *sampleFramesWritten = writtenTotal;
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Either IDeckLinkOutput or DLABAudioSetting is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::WriteAudioSamplesSync failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) beginAudioPrerollWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->BeginAudioPreroll();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::BeginAudioPreroll failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) endAudioPrerollWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->EndAudioPreroll();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::EndAudioPreroll failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) schedulePlaybackOfAudioBufferList:(AudioBufferList*)audioBufferList
                                    atTime:(NSInteger)streamTime
                               inTimeScale:(NSInteger)timeScale
                              writtenCount:(NSUInteger*)sampleFramesWritten
                                     error:(NSError**)error
{
    NSParameterAssert(audioBufferList && timeScale && sampleFramesWritten);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    DLABAudioSetting *setting = self.outputAudioSetting;
    if (output && setting) {
        __block BMDTimeValue timeValue = streamTime;
        __block uint32_t writtenTotal = 0;
        uint32_t mBytesPerFrame = setting.sampleSize;
        uint32_t mNumChannels = setting.channelCount;
        uint32_t mNumberBuffers = audioBufferList->mNumberBuffers;
        
        if (mNumberBuffers) {
            // Support multiple audioBuffers
            [self playback_sync:^{
                for (int index = 0; index < mNumberBuffers; index++) {
                    // Accept only interleaved buffer
                    AudioBuffer ab = audioBufferList->mBuffers[index];
                    if (!ab.mDataByteSize || !ab.mData) break;
                    if (ab.mNumberChannels != mNumChannels) break;
                    
                    // Queue audioSampleFrames
                    void* dataPointer = ab.mData;
                    uint32_t sampleFrameCount = ab.mDataByteSize / mBytesPerFrame;
                    uint32_t written = 0;
                    result = output->ScheduleAudioSamples(dataPointer,
                                                          sampleFrameCount,
                                                          timeValue,
                                                          timeScale,
                                                          &written);
                    
                    // Update queuing status
                    writtenTotal += written;
                    timeValue += written;
                    
                    // Validate all available sampleFrames are queued or not
                    if (!result && sampleFrameCount != written) {
                        // result = E_ABORT; // TODO Queuing buffer is full
                    }
                    if (result) break;
                }
            }];
            
            if (writtenTotal) {
                *sampleFramesWritten = writtenTotal;
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Either IDeckLinkOutput or DLABAudioSetting is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::ScheduleAudioSamples failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) schedulePlaybackOfAudioBlockBuffer:(CMBlockBufferRef)blockBuffer
                                     offset:(size_t)byteOffset
                                     atTime:(NSInteger)streamTime
                                inTimeScale:(NSInteger)timeScale
                               writtenCount:(NSUInteger*)sampleFramesWritten
                                      error:(NSError**)error
{
    NSParameterAssert(blockBuffer && timeScale && sampleFramesWritten);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    DLABAudioSetting *setting = self.outputAudioSetting;
    if (output && setting) {
        __block BMDTimeValue timeValue = streamTime;
        __block uint32_t writtenTotal = 0;
        uint32_t mBytesPerFrame = setting.sampleSize;
        size_t totalLength = 0;
        
        if (blockBuffer) {
            // validate blockBuffer is accessible
            OSStatus err = CMBlockBufferAssureBlockMemory(blockBuffer);
            if (!err) {
                totalLength = CMBlockBufferGetDataLength(blockBuffer);
            }
        }
        if (totalLength) {
            // Support non-contiguous CMBlockBuffer
            [self playback_sync:^{
                size_t offset = byteOffset;
                while (offset < totalLength) {
                    // Get data pointer and available length at offset
                    size_t lengthAtOffset = 0;
                    char* dataPointer = NULL;
                    OSStatus err = CMBlockBufferGetDataPointer(blockBuffer,
                                                               offset,
                                                               &lengthAtOffset,
                                                               NULL,
                                                               &dataPointer);
                    
                    result = E_INVALIDARG;
                    if (err || lengthAtOffset == 0 || !dataPointer) {
                        break; // Offset of memory in BlockBuffer is not ready
                    }
                    if ((lengthAtOffset % mBytesPerFrame) != 0) {
                        break; // AudioSampleFrame alignment error detected
                    }
                    
                    // Queue audioSampleFrames
                    uint32_t sampleFrameCount = ((uint32_t)lengthAtOffset / mBytesPerFrame);
                    uint32_t written = 0;
                    result = output->ScheduleAudioSamples((void*)dataPointer,
                                                          sampleFrameCount,
                                                          timeValue,
                                                          timeScale,
                                                          &written);
                    
                    // Update queuing status
                    offset += (written * mBytesPerFrame);
                    writtenTotal += written;
                    timeValue += written;
                    
                    // Validate all available sampleFrames are queued or not
                    if (!result && sampleFrameCount != written) {
                        // result = E_ABORT; // TODO Queuing buffer is full
                    }
                    if (result) break;
                }
            }];
            
            if (writtenTotal) {
                *sampleFramesWritten = writtenTotal;
            }
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Either IDeckLinkOutput or DLABAudioSetting is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::ScheduleAudioSamples failed."
              code:result
                to:error];
        return NO;
    }
}

- (NSNumber*) getBufferedAudioSampleFrameCountWithError:(NSError**)error;
{
    __block HRESULT result = E_FAIL;
    __block uint32_t bufferedFrameCount = 0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->GetBufferedAudioSampleFrameCount(&bufferedFrameCount);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    if (!result) {
        return @(bufferedFrameCount);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::GetBufferedAudioSampleFrameCount failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) flushBufferedAudioSamplesWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->FlushBufferedAudioSamples();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::FlushBufferedAudioSamples failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: Stream
/* =================================================================================== */

- (BOOL) startScheduledPlaybackAtTime:(NSUInteger)startTime
                          inTimeScale:(NSUInteger)timeScale
                                error:(NSError**)error
{
    NSParameterAssert(timeScale);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        [self subscribeOutput:YES];
        
        [self playback_sync:^{
            result = output->StartScheduledPlayback(startTime, timeScale, 1.0);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::StartScheduledPlayback failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL)stopScheduledPlaybackWithError:(NSError**)error
{
    // stop immediately
    return [self stopScheduledPlaybackInTimeScale:0 atTime:0 actualStopTimeAt:NULL error:error];
}

- (BOOL) stopScheduledPlaybackInTimeScale:(NSInteger)timeScale
                                   atTime:(NSInteger)stopPlayBackAtTime
                         actualStopTimeAt:(NSInteger*)actualStopTime
                                    error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDTimeValue timeValue = 0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->StopScheduledPlayback((BMDTimeValue)stopPlayBackAtTime, &timeValue, (BMDTimeScale)timeScale);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        if (actualStopTime) {
            *actualStopTime = (NSInteger)timeValue;
        }
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::StopScheduledPlayback failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) getScheduledStreamTimeInTimeScale:(NSInteger)timeScale
                                streamTime:(NSInteger*)streamTime
                             playbackSpeed:(double*)playbackSpeed
                                     error:(NSError**)error
{
    NSParameterAssert(timeScale && streamTime && playbackSpeed);
    
    __block HRESULT result = E_FAIL;
    __block BMDTimeValue timeValue = 0;
    __block double speedValue = 0.0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->GetScheduledStreamTime(timeScale, &timeValue, &speedValue);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        *streamTime = timeValue;
        *playbackSpeed = speedValue;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::GetScheduledStreamTime failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: Clock
/* =================================================================================== */

- (BOOL) getReferenceStatus:(DLABReferenceStatus*)referenceStatus
                      error:(NSError**)error
{
    NSParameterAssert(referenceStatus);
    
    __block HRESULT result = E_FAIL;
    __block BMDReferenceStatus referenceStatusValue = 0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->GetReferenceStatus(&referenceStatusValue);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        *referenceStatus = referenceStatusValue;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::GetReferenceStatus failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) getOutputHardwareReferenceClockInTimeScale:(NSInteger)timeScale
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
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (output) {
        [self playback_sync:^{
            result = output->GetHardwareReferenceClock(timeScale, &hwTime, &timeIF, &tickPF);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        *hardwareTime = hwTime;
        *timeInFrame = timeIF;
        *ticksPerFrame = tickPF;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::GetHardwareReferenceClock failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: Keying
/* =================================================================================== */

- (BOOL) enableKeyerAsInternalWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->Enable(false); // isExternal = false
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::Enable failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) enableKeyerAsExternalWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->Enable(true); // isExternal = true
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::Enable failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) updateKeyerLevelWith:(uint8_t)level error:(NSError**)error
{
    NSParameterAssert(level <= 255);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->SetLevel(level);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::SetLevel failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) updateKeyerRampUpWith:(uint32_t)numFrames error:(NSError**)error
{
    NSParameterAssert(numFrames <= 255);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->RampUp(numFrames);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::RampUp failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) updateKeyerRampDownWith:(uint32_t)numFrames error:(NSError**)error
{
    NSParameterAssert(numFrames <= 255);
    
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->RampDown(numFrames);
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::RampDown failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) disableKeyerWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkKeyer *keyer = self.deckLinkKeyer;
    if (keyer) {
        [self playback_sync:^{
            result = keyer->Disable();
        }];
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkKeyer::Disable failed."
              code:result
                to:error];
        return NO;
    }
}

@end
