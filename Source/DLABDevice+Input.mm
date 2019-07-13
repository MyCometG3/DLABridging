//
//  DLABDevice+Input.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017, 2019年 Takashi Mochizuki. All rights reserved.
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
    BMDPixelFormat pixelFormat = self.inputVideoSettingW.pixelFormatW;
    BMDVideoInputFlags inputFlag = self.inputVideoSettingW.inputFlagW;
    
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
        [tmpSetting buildVideoFormatDescription];
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

- (DLABTimecodeSetting*) createTimecodeSettingOf:(IDeckLinkVideoInputFrame*)videoFrame
                                          format:(BMDTimecodeFormat)format
{
    NSParameterAssert(videoFrame && format);
    
    HRESULT result = E_FAIL;
    
    IDeckLinkTimecode* timecodeObj = NULL;
    BMDTimecodeUserBits userBits = 0;
    DLABTimecodeSetting* setting = nil;
    
    result = videoFrame->GetTimecode(format, &timecodeObj);
    if (!result && timecodeObj) {
        result = timecodeObj->GetTimecodeUserBits(&userBits);
        if (!result) {
            setting = [[DLABTimecodeSetting alloc] initWithTimecodeFormat:format
                                                              timecodeObj:timecodeObj
                                                                 userBits:userBits];
        }
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
    
    // Check videoFrame
    long width = videoFrame->GetWidth();
    long height = videoFrame->GetHeight();
    long rowBytes = videoFrame->GetRowBytes();
    CMPixelFormatType pixelFormat = videoFrame->GetPixelFormat();
    
    // Check pool, and create if required
    CVReturn err = kCVReturnError;
    CVPixelBufferPoolRef pool = self.inputPixelBufferPool;
    
    if (pool == NULL) {
        // create new one using videoFrame parameters (lazy instatiation)
        NSString* minimunCountKey = (__bridge NSString *)kCVPixelBufferPoolMinimumBufferCountKey;
        NSDictionary *poolAttributes = @{minimunCountKey : @(4)};
        
        NSString* pixelFormatKey = (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey;
        NSString* widthKey = (__bridge NSString *)kCVPixelBufferWidthKey;
        NSString* heightKey = (__bridge NSString *)kCVPixelBufferHeightKey;
        NSString* bytesPerRowKey = (__bridge NSString *)kCVPixelBufferBytesPerRowAlignmentKey;
        NSMutableDictionary* pbAttributes = [NSMutableDictionary dictionary];
        pbAttributes[pixelFormatKey] = @(pixelFormat);
        pbAttributes[widthKey] = @(width);
        pbAttributes[heightKey] = @(height);
        pbAttributes[bytesPerRowKey] = @(rowBytes);
        
        err = CVPixelBufferPoolCreate(NULL, (__bridge CFDictionaryRef)poolAttributes,
                                      (__bridge CFDictionaryRef)pbAttributes,
                                      &pool);
        if (err)
            return NULL;
        
        self.inputPixelBufferPool = pool;
        CVPixelBufferPoolRelease(pool);
    }
    
    // Create new pixelBuffer and copy image
    BOOL ready = false;
    CVPixelBufferRef pixelBuffer = NULL;
    if (pool) {
        err = CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &pixelBuffer);
        if (!err && pixelBuffer) {
            // Simply check if width, height are same
            size_t pbWidth = CVPixelBufferGetWidth(pixelBuffer);
            size_t pbHeight = CVPixelBufferGetHeight(pixelBuffer);
            size_t ifWidth = width;
            size_t ifHeight = height;
            BOOL sizeOK = (pbWidth == ifWidth && pbHeight == ifHeight);
            
            // Simply check if stride is same
            size_t pbRowByte = CVPixelBufferGetBytesPerRow(pixelBuffer);
            size_t ifRowByte = rowBytes;
            BOOL rowByteOK = (pbRowByte == ifRowByte);
            
            // Copy pixel data from inputVideoFrame to CVPixelBuffer
            if (sizeOK) {
                CVReturn err = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                if (!err) {
                    // get buffer address for src and dst
                    void* dst = CVPixelBufferGetBaseAddress(pixelBuffer);
                    void* src = NULL;
                    videoFrame->GetBytes(&src);
                    
                    if (dst && src) {
                        if (rowByteOK) {
                            // bulk copy
                            memcpy(dst, src, ifRowByte * ifHeight);
                        } else {
                            // copy each line b/w different stride
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
        }
    }
    
    if (!err && pixelBuffer && ready) {
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
    BMDTimeScale timeScale = self.inputVideoSetting.timeScaleW;
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
    CMFormatDescriptionRef formatDescription = self.inputVideoSettingW.videoFormatDescriptionW;
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
    size_t sampleSize = (size_t)self.inputAudioSettingW.sampleSizeW;
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

// private experimental - VANC support
- (void*) getVancBufferOfInputFrame:(IDeckLinkVideoInputFrame*)inFrame
                               line:(uint32_t)lineNumber
{
    NSParameterAssert(inFrame);
    
    HRESULT result = E_FAIL;
    IDeckLinkVideoFrameAncillary *ancillaryData = NULL;
    result = inFrame->GetAncillaryData(&ancillaryData);
    
    if (!result) {
        void* buffer = NULL;
        result = ancillaryData->GetBufferForVerticalBlankingLine(lineNumber, &buffer);
        if (!result) {
            return buffer;
        } else {
            NSLog(@"ERROR: VANC for lineNumber %d is not supported.", lineNumber);
        }
    }
    return NULL;
}

// private experimental - VANC support
- (void) callbackInputVANCHandler:(IDeckLinkVideoInputFrame*)inFrame
{
    NSParameterAssert(inFrame);
    
    // Validate input frame
    BMDFrameFlags flags = inFrame->GetFlags();
    if ((flags & bmdFrameHasNoInputSource) != 0) return;
    
    BMDTimeValue frameTime = 0;
    BMDTimeValue frameDuration = 0;
    BMDTimeScale timeScale = self.inputVideoSetting.timeScaleW;
    HRESULT result = inFrame->GetStreamTime(&frameTime, &frameDuration, timeScale);
    if (result) return;
    
    //
    VANCHandler inHandler = self.inputVANCHandler;
    if (inHandler) {
        // Create timinginfo struct
        CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
        CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
        CMTime decodeTimeStamp = kCMTimeInvalid;
        CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
        
        // Callback in delegate queue
        [self delegate_sync:^{
            NSArray<NSNumber*>* lines = self.inputVANCLines;
            for (NSNumber* num in lines) {
                int32_t lineNumber = num.intValue;
                void* buffer = [self getVancBufferOfInputFrame:inFrame line:lineNumber];
                if (buffer) {
                    BOOL result = inHandler(timingInfo, lineNumber, buffer);
                    if (!result) break;
                }
            }
        }];
    }
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
                                              supportedAs:(DLABDisplayModeSupportFlag1011*)displayModeSupportFlag
                                                    error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    DLABVideoSetting* setting = [self createInputVideoSettingOfDisplayMode:displayMode
                                                               pixelFormat:pixelFormat
                                                                 inputFlag:videoInputFlag
                                                                     error:error];
    if (setting && displayModeSupportFlag) {
        *displayModeSupportFlag = DLABDisplayModeSupportFlag1011Supported;
    }
    
    return setting;
}

- (DLABVideoSetting*)createInputVideoSettingOfDisplayMode:(DLABDisplayMode)displayMode
                                              pixelFormat:(DLABPixelFormat)pixelFormat
                                                inputFlag:(DLABVideoInputFlag)videoInputFlag
                                                    error:(NSError**)error
{
    NSParameterAssert(displayMode && pixelFormat);
    
    __block HRESULT result = E_FAIL;
    DLABVideoSetting* setting = nil;
    IDeckLinkInput *input = self.deckLinkInput;
    if (input) {
        __block bool supported = false;
        [self capture_sync:^{
            result = input->DoesSupportVideoMode(bmdVideoConnectionUnspecified,
                                                 displayMode,
                                                 pixelFormat,
                                                 videoInputFlag,
                                                 &supported);
        }];
        if (!result) {
            if (supported) {
                IDeckLinkDisplayMode* displayModeObj = NULL;
                input->GetDisplayMode(displayMode, &displayModeObj);
                setting = [[DLABVideoSetting alloc] initWithDisplayModeObj:displayModeObj
                                                               pixelFormat:pixelFormat
                                                            videoInputFlag:videoInputFlag];
                [setting buildVideoFormatDescription];
                displayModeObj->Release();
            }
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkInput::DoesSupportVideoMode failed."
                  code:result
                    to:error];
            return nil;
        }
    }
    
    if (setting && setting.videoFormatDescriptionW) {
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
        [setting buildAudioFormatDescription];
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
        BMDDisplayMode displayMode = setting.displayModeW;
        BMDVideoInputFlags inputFlag = setting.inputFlagW;
        BMDPixelFormat format = setting.pixelFormatW;
        
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
        BMDAudioSampleType sampleType = setting.sampleTypeW;
        uint32_t channelCount = setting.channelCountW;
        
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
        [self inputCallback]; // allow lazy instantiation
        
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

@end
