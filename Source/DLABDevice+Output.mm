//
//  DLABDevice+Output.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDevice+Internal.h>
#import <DLABBridgingSupport.h>
#import <DLABVideoFramePool.h>
#import <DLABQueryInterfaceAny.h>
#import <DLABVideoBufferSupport.h>

NS_INLINE BOOL DLABPerformOutputCommand(DLABDevice *self,
                                        NSError **error,
                                        const char *functionName,
                                        int lineNumber,
                                        NSString *failureReason,
                                        HRESULT (^command)(IDeckLinkOutput *output))
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (!output) {
        [self post:DLABFunctionLineDescription(functionName, lineNumber)
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    [self playback_sync:^{
        result = command(output);
    }];
    if (result == S_OK) {
        return YES;
    }
    
    [self post:DLABFunctionLineDescription(functionName, lineNumber)
        reason:failureReason
          code:result
            to:error];
    return NO;
}

NS_INLINE NSNumber * DLABOutputUInt32Value(DLABDevice *self,
                                           NSError **error,
                                           const char *functionName,
                                           int lineNumber,
                                           NSString *failureReason,
                                           HRESULT (^command)(IDeckLinkOutput *output, uint32_t *value))
{
    __block HRESULT result = E_FAIL;
    __block uint32_t value = 0;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (!output) {
        [self post:DLABFunctionLineDescription(functionName, lineNumber)
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    [self playback_sync:^{
        result = command(output, &value);
    }];
    if (result == S_OK) {
        return @(value);
    }
    
    [self post:DLABFunctionLineDescription(functionName, lineNumber)
        reason:failureReason
          code:result
            to:error];
    return nil;
}

NS_INLINE NSNumber * DLABOutputBoolValue(DLABDevice *self,
                                         NSError **error,
                                         const char *functionName,
                                         int lineNumber,
                                         NSString *failureReason,
                                         HRESULT (^command)(IDeckLinkOutput *output, bool *value))
{
    __block HRESULT result = E_FAIL;
    __block bool value = false;
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (!output) {
        [self post:DLABFunctionLineDescription(functionName, lineNumber)
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    [self playback_sync:^{
        result = command(output, &value);
    }];
    if (result == S_OK) {
        return @(value);
    }
    
    [self post:DLABFunctionLineDescription(functionName, lineNumber)
        reason:failureReason
          code:result
            to:error];
    return nil;
}

NS_INLINE void DLABResetOutputVideoResources(DLABDevice *self)
{
    [self.outputVideoFramePool freeFrames];
    self.outputVideoConverter = nil;
}

/* =================================================================================== */
// MARK: - output (internal)
/* =================================================================================== */

NS_INLINE BMDAncillaryDataSpace DLABBMDAncillaryDataSpaceFromPublic(DLABAncillaryDataSpace dataSpace)
{
    return (BMDAncillaryDataSpace)dataSpace;
}

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
    [self.outputVideoFramePool releaseFrame:(IDeckLinkMutableVideoFrame *)frame];
    
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
        SEL selector = @selector(scheduledPlaybackHasStoppedOfDevice:);
        if ([delegate respondsToSelector:selector]) {
            [delegate scheduledPlaybackHasStoppedOfDevice:wself]; // async
        }
    }];
}

/* =================================================================================== */
/* =================================================================================== */
// MARK: Process Output videoFrame/timecode
/* =================================================================================== */

NS_INLINE BOOL copyBufferCVtoDL(DLABDevice* self, CVPixelBufferRef pixelBuffer, IDeckLinkMutableVideoFrame* videoFrame) {
    if (!pixelBuffer || !videoFrame) return FALSE;
    
    BOOL pre1403 = [DLABVersionChecker checkPre1403];
    
    IDeckLinkVideoBuffer* videoBuffer = NULL;
    BMDBufferAccessFlags accessFlags = bmdBufferAccessWrite;
    if (!pre1403) {
        if (!VideoBufferLockBaseAddress(videoFrame, accessFlags , &videoBuffer)) {
            return FALSE;
        }
    }
    
    bool result = FALSE;
    CVReturn err = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (!err) {
        void* src = CVPixelBufferGetBaseAddress(pixelBuffer);
        void* dst = NULL;
        
        if (!pre1403) {
            VideoBufferGetBaseAddress(videoBuffer, &dst);
        } else {
            IDeckLinkMutableVideoFrame_v14_2_1* videoFrame_v14_2_1 = (IDeckLinkMutableVideoFrame_v14_2_1*)videoFrame;
            videoFrame_v14_2_1->GetBytes(&dst);
        }
        
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
            if (pixelSize == 0) {
                result = false;
            } else {
                vImage_Error convErr = kvImageNoError;
                convErr = vImageCopyBuffer(&sourceBuffer, &targetBuffer,
                                           pixelSize, kvImageNoFlags);
                result = (convErr == kvImageNoError);
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
    
    if (!pre1403) {
        VideoBufferUnlockBaseAddress(videoBuffer, accessFlags);
    }
    
    return result;
}

NS_INLINE BOOL copyPlaneCVtoDL(DLABDevice* self, CVPixelBufferRef pixelBuffer, IDeckLinkMutableVideoFrame* videoFrame) {
    if (!pixelBuffer || !videoFrame) return FALSE;
    
    BOOL pre1403 = [DLABVersionChecker checkPre1403];
    
    IDeckLinkVideoBuffer* videoBuffer = NULL;
    BMDBufferAccessFlags accessFlags = bmdBufferAccessWrite;
    if (!pre1403) {
        if (!VideoBufferLockBaseAddress(videoFrame, accessFlags , &videoBuffer)) {
            return FALSE;
        }
    }
    
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
        
        if (!pre1403) {
            VideoBufferGetBaseAddress(videoBuffer, &dst);
        } else {
            IDeckLinkMutableVideoFrame_v14_2_1* videoFrame_v14_2_1 = (IDeckLinkMutableVideoFrame_v14_2_1*)videoFrame;
            videoFrame_v14_2_1->GetBytes(&dst);
        }
        
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
    
    if (!pre1403) {
        VideoBufferUnlockBaseAddress(videoBuffer, accessFlags);
    }
    
    return ready;
}

- (IDeckLinkMutableVideoFrame*) outputVideoFrameWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    NSParameterAssert(pixelBuffer);
    
    BOOL ready = false;
    OSType cvPixelFormat = self.outputVideoSetting.cvPixelFormatType;
    if (!cvPixelFormat) return NULL;
    
    // take out free output frame from frame pool
    [self.outputVideoFramePool prepareWithOutput:self.deckLinkOutput setting:self.outputVideoSetting];
    IDeckLinkMutableVideoFrame* videoFrame = [self.outputVideoFramePool reserveFrame];
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
                ready = copyPlaneCVtoDL(self, pixelBuffer, videoFrame);
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
            [self.outputVideoFramePool releaseFrame:videoFrame];
        return NULL;
    }
}

- (BOOL) validateTimecodeFormat:(DLABTimecodeFormat)format
                   videoSetting:(DLABVideoSetting*)outputVideoSetting
{
    BOOL validTimecode = NO;
    
    BOOL useSERIAL = outputVideoSetting.useSERIAL;
    BOOL useVITC = outputVideoSetting.useVITC;
    BOOL useRP188 = outputVideoSetting.useRP188;
    
    BOOL SERIAL = (format == DLABTimecodeFormatSerial);
    BOOL VITCF1 = (format == DLABTimecodeFormatVITC);
    BOOL VITCF2 = (format == DLABTimecodeFormatVITCField2);
    BOOL RP188VITC1 = (format == DLABTimecodeFormatRP188VITC1);
    BOOL RP188VITC2 = (format == DLABTimecodeFormatRP188VITC2);
    BOOL RP188LTC = (format == DLABTimecodeFormatRP188LTC);
    BOOL RP188ANY = (format == DLABTimecodeFormatRP188Any);
    
    if (useSERIAL && SERIAL)
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

// private experimental - VANC Playback support (deprecated)

- (IDeckLinkVideoFrameAncillary*) prepareOutputFrameAncillary:(IDeckLinkMutableVideoFrame*)outFrame // deprecated
{
    NSParameterAssert(outFrame);
    
    IDeckLinkVideoFrameAncillary *ancillaryData = NULL;
    outFrame->GetAncillaryData(&ancillaryData); // Deprecated. Use IDeckLinkVideoFrameAncillaryPackets
    
    if (!ancillaryData) {
        // Create new one and attach to outFrame
        IDeckLinkOutput *output = self.deckLinkOutput;
        if (output) {
            output->CreateAncillaryData(outFrame->GetPixelFormat(), &ancillaryData); // Deprecated. Use IDeckLinkVideoFrameAncillaryPackets
            if (ancillaryData) {
                outFrame->SetAncillaryData(ancillaryData);
                ancillaryData->Release();
                ancillaryData = NULL;   // Ensure nullify
            }
        }
        
        // Issue Another query.
        outFrame->GetAncillaryData(&ancillaryData); // Deprecated. Use IDeckLinkVideoFrameAncillaryPackets
    }
    
    return ancillaryData; // Nullable
}

- (void*) bufferOfOutputFrameAncillary:(IDeckLinkVideoFrameAncillary*)ancillaryData
                                  line:(uint32_t)lineNumber // deprecated
{
    NSParameterAssert(ancillaryData);
    
    void* buffer = NULL;
    ancillaryData->GetBufferForVerticalBlankingLine(lineNumber, &buffer); // deprecated
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
                       inTimeScale:(NSInteger)timeScale // deprecated
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
        IDeckLinkVideoFrameAncillary* frameAncillary = [self prepareOutputFrameAncillary:outFrame]; // deprecated
        if (frameAncillary) {
            // Callback in delegate queue
            [self delegate_sync:^{
                NSArray<NSNumber*>* lines = self.outputVANCLines;
                for (NSNumber* num in lines) {
                    int32_t lineNumber = num.intValue;
                    void* buffer = [self bufferOfOutputFrameAncillary:frameAncillary line:lineNumber]; // deprecated
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

// VANC Packet Playback support

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
        IDeckLinkVideoFrameAncillaryPackets_v15_2* frameAncillaryPackets = NULL;
        outFrame->QueryInterface(IID_IDeckLinkVideoFrameAncillaryPackets_v15_2,
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
                                                         bmdAncillaryDataSpaceVANC, data);
                            if (ret == S_OK) {
                                IDeckLinkAncillaryPacket_v15_2* legacyPacket = NULL;
                                ret = packet->QueryInterface(IID_IDeckLinkAncillaryPacket_v15_2,
                                                             (void**)&legacyPacket);
                                if (ret == S_OK && legacyPacket) {
                                    ret = frameAncillaryPackets->AttachPacket(legacyPacket);
                                    legacyPacket->Release();
                                }
                            }
                            ready = (ret == S_OK);
                        }
                        packet->Release();
                    }
                    if (!ready) break;
                }
            }];
            
            frameAncillaryPackets->Release();
        }
    }
}

- (void) callbackOutputAncillaryPacketHandler:(IDeckLinkMutableVideoFrame*)outFrame
                                       atTime:(NSInteger)displayTime
                                     duration:(NSInteger)frameDuration
                                  inTimeScale:(NSInteger)timeScale
{
    NSParameterAssert(outFrame && frameDuration && timeScale);
    
    int64_t frameTime = displayTime;
    
    CMTime duration = CMTimeMake(frameDuration, (int32_t)timeScale);
    CMTime presentationTimeStamp = CMTimeMake(frameTime, (int32_t)timeScale);
    CMTime decodeTimeStamp = kCMTimeInvalid;
    CMSampleTimingInfo timingInfo = {duration, presentationTimeStamp, decodeTimeStamp};
    
    OutputAncillaryPacketHandler outHandler = self.outputAncillaryPacketHandler;
    if (outHandler) {
        IDeckLinkVideoFrameAncillaryPackets* frameAncillaryPackets = NULL;
        DLABQueryInterfaceAny(outFrame, &frameAncillaryPackets,
                              IID_IDeckLinkVideoFrameAncillaryPackets,
                              IID_IDeckLinkVideoFrameAncillaryPackets_v15_2);
        if (frameAncillaryPackets) {
            [self delegate_sync:^{
                while (TRUE) {
                    BOOL ready = FALSE;
                    DLABAncillaryPacket* packet = new DLABAncillaryPacket();
                    if (packet) {
                        uint8_t did = 0;
                        uint8_t sdid = 0;
                        uint32_t lineNumber = 0;
                        uint8_t dataStreamIndex = 0;
                        DLABAncillaryDataSpace dataSpace = DLABAncillaryDataSpaceVANC;
                        NSData* data = outHandler(timingInfo,
                                                  &did, &sdid, &lineNumber, &dataStreamIndex, &dataSpace);
                        if (data) {
                            
                            // For SDK < 15.3, force dataSpace to VANC (only SDK 15.3+ supports dataSpace)
                            
                            DLABAncillaryDataSpace effectiveDataSpace = dataSpace;
                            
                            if ([DLABVersionChecker checkPre1503]) {
                                
                                effectiveDataSpace = DLABAncillaryDataSpaceVANC;
                                
                            }
                            
                            HRESULT ret = packet->Update(did, sdid, lineNumber, dataStreamIndex,
                                                         
                                                         DLABBMDAncillaryDataSpaceFromPublic(effectiveDataSpace), data);
                            if (ret == S_OK) {
                                ret = frameAncillaryPackets->AttachPacket(packet);
                            }
                            ready = (ret == S_OK);
                        }
                        packet->Release();
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
        __block bool pre1403 = [DLABVersionChecker checkPre1403];
        __block bool pre1105 = [DLABVersionChecker checkPre1105];
        [self playback_sync:^{
            if (pre1105) {
                IDeckLinkOutput_v11_4 *output1104 = (IDeckLinkOutput_v11_4*)output;
                result = output1104->DoesSupportVideoMode(videoConnection,          // BMDVideoConnection = DLABVideoConnection
                                                          displayMode,              // BMDDisplayMode = DLABDisplayMode
                                                          pixelFormat,              // BMDPixelFormat = DLABPixelFormat
                                                          supportedVideoModeFlag,   // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                          &actualMode,              // BMDDisplayMode = DLABDisplayMode
                                                          &supported);              // bool
            } else if (pre1403) {
                IDeckLinkOutput_v14_2_1 *output1402 = (IDeckLinkOutput_v14_2_1*)output;
                BMDVideoOutputConversionMode convertMode = bmdNoVideoOutputConversion;
                result = output1402->DoesSupportVideoMode(videoConnection,          // BMDVideoConnection = DLABVideoConnection
                                                          displayMode,              // BMDDisplayMode = DLABDisplayMode
                                                          pixelFormat,              // BMDPixelFormat = DLABPixelFormat
                                                          convertMode,              // BMDVideoOutputConversionMode = DLABVideoOutputConversionMode
                                                          supportedVideoModeFlag,   // BMDSupportedVideoModeFlags = DLABSupportedVideoModeFlag
                                                          &actualMode,              // BMDDisplayMode = DLABDisplayMode
                                                          &supported);              // bool
            } else {
                BMDVideoOutputConversionMode convertMode = bmdNoVideoOutputConversion;
                result = output->DoesSupportVideoMode(videoConnection,          // BMDVideoConnection = DLABVideoConnection
                                                      displayMode,              // BMDDisplayMode = DLABDisplayMode
                                                      pixelFormat,              // BMDPixelFormat = DLABPixelFormat
                                                      convertMode,              // BMDVideoOutputConversionMode = DLABVideoOutputConversionMode
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
    return DLABOutputBoolValue(self,
                               error,
                               __PRETTY_FUNCTION__,
                               __LINE__,
                               @"IDeckLinkOutput::IsScheduledPlaybackRunning failed.",
                               ^HRESULT(IDeckLinkOutput *output, bool *value) {
        return output->IsScheduledPlaybackRunning(value);
    });
}

- (BOOL) setOutputScreenPreviewToView:(NSView*)parentView
                                error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    
    IDeckLinkOutput* output = self.deckLinkOutput;
    if (output) {
        if (parentView) {
            IDeckLinkScreenPreviewCallback* previewCallback = DLABCreateScreenPreviewCallback(parentView);
            
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
    
    BMDDisplayMode displayMode = setting.displayMode;
    BMDVideoOutputFlags outputFlag = setting.outputFlag;
    BOOL succeeded = DLABPerformOutputCommand(self,
                                              error,
                                              __PRETTY_FUNCTION__,
                                              __LINE__,
                                              @"IDeckLinkOutput::EnableVideoOutput failed.",
                                              ^HRESULT(IDeckLinkOutput *output) {
        return output->EnableVideoOutput(displayMode, outputFlag);
    });
    if (succeeded) {
        DLABResetOutputVideoResources(self);
        self.outputVideoSettingW = setting;
    } else {
        self.outputVideoSettingW = nil;
    }
    return succeeded;
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
        if (error) *error = err;
        return NO;
    }
    return [self enableVideoOutputWithVideoSetting:setting error:error];
}

- (BOOL) disableVideoOutputWithError:(NSError**)error
{
    BOOL succeeded = DLABPerformOutputCommand(self,
                                              error,
                                              __PRETTY_FUNCTION__,
                                              __LINE__,
                                              @"IDeckLinkOutput::DisableVideoOutput failed.",
                                              ^HRESULT(IDeckLinkOutput *output) {
        return output->DisableVideoOutput();
    });
    if (succeeded) {
        DLABResetOutputVideoResources(self);
        self.outputVideoSettingW = nil;
    }
    return succeeded;
}

static DLABFrameMetadata * processCallbacks(DLABDevice *self, IDeckLinkMutableVideoFrame *outFrame, NSInteger displayTime, NSInteger frameDuration, NSInteger timeScale) {
    DLABFrameMetadata* frameMetadata = nil;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Callback VANCHandler block // deprecated
    if (self.outputVANCHandler) {
        [self callbackOutputVANCHandler:outFrame
                                 atTime:displayTime
                               duration:frameDuration
                            inTimeScale:timeScale];
    }
#pragma clang diagnostic pop
    
    // Callback VANCPacketHandler block
    if (self.outputVANCPacketHandler) {
        [self callbackOutputVANCPacketHandler:outFrame
                                       atTime:displayTime
                                     duration:frameDuration
                                  inTimeScale:timeScale];
    }
    
    // Callback ancillary packet handler block
    if (self.outputAncillaryPacketHandler) {
        [self callbackOutputAncillaryPacketHandler:outFrame
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

- (NSNumber*) getBufferedVideoFrameCountWithError:(NSError**)error
{
    return DLABOutputUInt32Value(self,
                                 error,
                                 __PRETTY_FUNCTION__,
                                 __LINE__,
                                 @"IDeckLinkOutput::GetBufferedVideoFrameCount failed.",
                                 ^HRESULT(IDeckLinkOutput *output, uint32_t *value) {
        return output->GetBufferedVideoFrameCount(value);
    });
}

/* =================================================================================== */
// MARK: Audio
/* =================================================================================== */

- (BOOL) enableAudioOutputWithAudioSetting:(DLABAudioSetting*)setting
                                     error:(NSError**)error
{
    NSParameterAssert(setting);
    
    if (self.swapHDMICh3AndCh4OnOutput != nil) {
        NSError *err = nil;
        BOOL newValue = self.swapHDMICh3AndCh4OnOutput.boolValue;
        DLABConfiguration key = DLABConfigurationSwapHDMICh3AndCh4OnOutput;
        
        // Verify if SwapHDMICh3AndCh4 flag is available on this device
        [self boolValueForConfiguration:key error:&err];
        if (!err) {
            // Update accordingly
            [self setBoolValue:newValue forConfiguration:key error:&err];
        }
        
        if (err) {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"bmdDeckLinkConfigSwapHDMICh3AndCh4OnOutput flag is not supported."
                  code:E_NOTIMPL
                    to:error];
            return NO;
        }
    }
    
    BMDAudioSampleType sampleType = setting.sampleType;
    uint32_t channelCount = setting.channelCount;
    BOOL succeeded = DLABPerformOutputCommand(self,
                                              error,
                                              __PRETTY_FUNCTION__,
                                              __LINE__,
                                              @"IDeckLinkOutput::EnableAudioOutput failed.",
                                              ^HRESULT(IDeckLinkOutput *output) {
        return output->EnableAudioOutput(DLABAudioSampleRate48kHz,
                                         sampleType,
                                         channelCount,
                                         DLABAudioOutputStreamTypeContinuous);
    });
    if (succeeded) {
        self.outputAudioSettingW = setting;
    }
    return succeeded;
}

- (BOOL) disableAudioOutputWithError:(NSError**)error
{
    BOOL succeeded = DLABPerformOutputCommand(self,
                                              error,
                                              __PRETTY_FUNCTION__,
                                              __LINE__,
                                              @"IDeckLinkOutput::DisableAudioOutput failed.",
                                              ^HRESULT(IDeckLinkOutput *output) {
        return output->DisableAudioOutput();
    });
    if (succeeded) {
        self.outputAudioSettingW = nil;
    }
    return succeeded;
}

- (NSNumber*) getBufferedAudioSampleFrameCountWithError:(NSError**)error;
{
    return DLABOutputUInt32Value(self,
                                 error,
                                 __PRETTY_FUNCTION__,
                                 __LINE__,
                                 @"IDeckLinkOutput::GetBufferedAudioSampleFrameCount failed.",
                                 ^HRESULT(IDeckLinkOutput *output, uint32_t *value) {
        return output->GetBufferedAudioSampleFrameCount(value);
    });
}

- (BOOL) flushBufferedAudioSamplesWithError:(NSError**)error
{
    return DLABPerformOutputCommand(self,
                                    error,
                                    __PRETTY_FUNCTION__,
                                    __LINE__,
                                    @"IDeckLinkOutput::FlushBufferedAudioSamples failed.",
                                    ^HRESULT(IDeckLinkOutput *output) {
        return output->FlushBufferedAudioSamples();
    });
}

- (BOOL) beginAudioPrerollWithError:(NSError**)error
{
    return DLABPerformOutputCommand(self,
                                    error,
                                    __PRETTY_FUNCTION__,
                                    __LINE__,
                                    @"IDeckLinkOutput::BeginAudioPreroll failed.",
                                    ^HRESULT(IDeckLinkOutput *output) {
        return output->BeginAudioPreroll();
    });
}

- (BOOL) endAudioPrerollWithError:(NSError**)error
{
    return DLABPerformOutputCommand(self,
                                    error,
                                    __PRETTY_FUNCTION__,
                                    __LINE__,
                                    @"IDeckLinkOutput::EndAudioPreroll failed.",
                                    ^HRESULT(IDeckLinkOutput *output) {
        return output->EndAudioPreroll();
    });
}

/* =================================================================================== */
// MARK: Stream
/* =================================================================================== */

- (BOOL) startScheduledPlaybackAtTime:(NSUInteger)startTime
                          inTimeScale:(NSUInteger)timeScale
                                error:(NSError**)error
{
    NSParameterAssert(timeScale);
    
    IDeckLinkOutput *output = self.deckLinkOutput;
    if (!output) {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    [self subscribeOutput:YES];
    __block HRESULT result = E_FAIL;
    [self playback_sync:^{
        result = output->StartScheduledPlayback(startTime, timeScale, 1.0);
    }];
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkOutput::StartScheduledPlayback failed."
              code:result
                to:error];
        return NO;
    }
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
        processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
        
        // sync display - blocking operation
        result = output->DisplayVideoFrameSync(outFrame);
        
        // free output frame
        [self.outputVideoFramePool releaseFrame:outFrame];
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
            [self.outputVideoFramePool releaseFrame:outFrame];
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
        processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
        
        // async display
        result = output->ScheduleVideoFrame(outFrame, displayTime, frameDuration, timeScale);
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
            [self.outputVideoFramePool releaseFrame:outFrame];
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
                processCallbacks(self, outFrame, displayTime, frameDuration, timeScale);
                
                // async display
                result = output->ScheduleVideoFrame(outFrame, displayTime, frameDuration, timeScale);
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
            [self.outputVideoFramePool releaseFrame:outFrame];
        }
        
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:reason
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
        if (error) *error = err;
        return NO;
    }
    return [self enableAudioOutputWithAudioSetting:setting error:error];
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
