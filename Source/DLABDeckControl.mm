//
//  DLABDeckControl.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDeckControl+Internal.h>
#import <DLABBridgingSupport.h>

const char* kDeckQueue = "DLABDeckControl.deckQueue";

NSString* const kCurrentModeKey = @"currentMode";
NSString* const kCurrentVTRControlStateKey = @"currentState";
NSString* const kCurrentStatusFlagsKey = @"currentFlags";

NS_INLINE BOOL DLABPerformDeckCommand(DLABDeckControl *self,
                                      NSError **error,
                                      const char *functionName,
                                      int lineNumber,
                                      NSString *failureReason,
                                      HRESULT (^command)(IDeckLinkDeckControl *control))
{
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl *control = self.deckControl;
    if (control) {
        DLABDispatchSyncIfNeeded(self.deckQueue, self.deckQueueKey, ^{
            result = command(control);
        });
    }
    if (result == S_OK) {
        return YES;
    }
    
    [self post:DLABFunctionLineDescription(functionName, lineNumber)
        reason:failureReason
          code:result
            to:error];
    return NO;
}

NS_INLINE BOOL DLABPerformDeckCommandWithStatusError(DLABDeckControl *self,
                                                     NSError **error,
                                                     const char *functionName,
                                                     int lineNumber,
                                                     NSString *failureReason,
                                                     HRESULT (^command)(IDeckLinkDeckControl *control, BMDDeckControlError *deckError))
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError deckError = bmdDeckControlNoError;
    IDeckLinkDeckControl *control = self.deckControl;
    if (control) {
        DLABDispatchSyncIfNeeded(self.deckQueue, self.deckQueueKey, ^{
            result = command(control, &deckError);
        });
    }
    if (result == S_OK) {
        return YES;
    }
    
    [self post:DLABFunctionLineDescription(functionName, lineNumber)
        reason:failureReason
          code:(NSInteger)deckError
            to:error];
    return NO;
}

@implementation DLABDeckControl

- (instancetype) init
{
    DLABRaiseUnavailableInit(self, @selector(initWithDeckLink:));
    return nil;
}

- (nullable instancetype) initWithDeckLink:(IDeckLink *)deckLink
{
    NSParameterAssert(deckLink);
    
    self = [super init];
    if (self) {
        // validate DeckControl support
        HRESULT result = E_FAIL;
        IDeckLinkDeckControl *control = NULL;
        
        result = deckLink->QueryInterface(IID_IDeckLinkDeckControl, (void**)&control);
        if (result == S_OK && control) {
            IDeckLinkDeckControlStatusCallback *callback = NULL;
            callback = new DLABDeckControlStatusCallback(self);
            if (callback) {
                result = control->SetCallback(callback);
                callback->Release();
            }
        }
        if (result == S_OK) {
            _deckControl = control;
        } else {
            if (control) control->Release();
            self = nil;
        }
    }
    return self;
}

- (void) dealloc
{
    if (_deckControl) _deckControl->Release();
}

/* =================================================================================== */
// MARK: - (Public/Private) - property accessors
/* =================================================================================== */

// Public
@synthesize delegate = _delegate;

// Private
@synthesize deckControl = _deckControl;
@synthesize deckQueueKey = deckQueueKey;
@synthesize deckQueue = _deckQueue;

/* =================================================================================== */
// MARK: - (Private) - block helper
/* =================================================================================== */

- (dispatch_queue_t) deckQueue
{
    @synchronized (self) {
        if (!_deckQueue) {
            _deckQueue = dispatch_queue_create(kDeckQueue, DISPATCH_QUEUE_SERIAL);
            deckQueueKey = &deckQueueKey;
            void *unused = (__bridge void*)self;
            dispatch_queue_set_specific(_deckQueue, deckQueueKey, unused, NULL);
        }
        return _deckQueue;
    }
}

- (void) deck_sync:(dispatch_block_t)block
{
    dispatch_queue_t queue = self.deckQueue;
    DLABDispatchSyncIfNeeded(queue, deckQueueKey, block);
}

- (void) deck_async:(dispatch_block_t)block
{
    dispatch_queue_t queue = self.deckQueue;
    DLABDispatchAsyncIfNeeded(queue, deckQueueKey, block);
}

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

- (BOOL) post:(NSString*)description
       reason:(NSString*)failureReason
         code:(NSInteger)result
           to:(NSError**)error;
{
    return DLABPostError(error, description, failureReason, result);
}

/* =================================================================================== */
// MARK: - DLABDeckControlStatusCallbackPrivateDelegate
/* =================================================================================== */

- (void) deckControlTimecodeUpdate:(BMDTimecodeBCD)currentTimecode
{
    id obj = self.delegate;
    if ([obj respondsToSelector:@selector(deckControlTimecodeUpdate:)]) {
        [obj deckControlTimecodeUpdate:(DLABTimecodeBCD)currentTimecode];
    }
}

- (void) deckControlVTRControlStateChanged:(BMDDeckControlVTRControlState)newState
                              controlError:(BMDDeckControlError)error
{
    id obj = self.delegate;
    if ([obj respondsToSelector:@selector(deckControlVTRControlStateChanged:controlError:)]) {
        [obj deckControlVTRControlStateChanged:(DLABDeckControlVTRControlState)newState
                                  controlError:(DLABDeckControlError)error];
    }
}

- (void) deckControlEventReceived:(BMDDeckControlEvent)event
                     controlError:(BMDDeckControlError)error
{
    id obj = self.delegate;
    if ([obj respondsToSelector:@selector(deckControlEventReceived:controlError:)]) {
        [obj deckControlEventReceived:(DLABDeckControlEvent)event
                         controlError:(DLABDeckControlError)error];
    }
}

- (void) deckControlStatusChanged:(BMDDeckControlStatusFlags)flags
                             mask:(uint32_t)mask
{
    id obj = self.delegate;
    if ([obj respondsToSelector:@selector(deckControlStatusChanged:mask:)]) {
        [obj deckControlStatusChanged:flags mask:mask];
    }
}

/* =================================================================================== */
// MARK: - Wrapper for IDeckLinkControl functions
/* =================================================================================== */

- (BOOL) openWithTimebase:(CMTime)timebase dropFrame:(BOOL)dropFrame error:(NSError**)error
{
    BMDTimeScale timeScale = (BMDTimeScale)timebase.timescale;
    BMDTimeValue timeValue = (BMDTimeValue)timebase.value;
    
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Open failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Open(timeScale, timeValue, dropFrame, deckError);
    });
}

- (BOOL) closeWithStandby:(BOOL)standby error:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::Close failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->Close(standby);
    });
}

- (nullable NSNumber*) currentModeWithError:(NSError**)error
{
    DLABDeckControlMode currentMode = DLABDeckControlModeNotOpened;
    DLABDeckControlVTRControlState currentState = DLABDeckControlVTRControlStateNotInVTRControlMode;
    DLABDeckControlStatusFlag currentFlags = DLABDeckControlStatusFlagDeckConnected;
    NSError* err = nil;
    BOOL result = [self currentStateOfControlMode:&currentMode
                                  vtrControlState:&currentState
                                      statusFlags:&currentFlags
                                            error:&err];
    if (result) {
        return @(currentMode);
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (nullable NSNumber*) currentVTRControlStateWithError:(NSError**)error
{
    DLABDeckControlMode currentMode = DLABDeckControlModeNotOpened;
    DLABDeckControlVTRControlState currentState = DLABDeckControlVTRControlStateNotInVTRControlMode;
    DLABDeckControlStatusFlag currentFlags = DLABDeckControlStatusFlagDeckConnected;
    NSError* err = nil;
    BOOL result = [self currentStateOfControlMode:&currentMode
                                  vtrControlState:&currentState
                                      statusFlags:&currentFlags
                                            error:&err];
    if (result) {
        return @(currentState);
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (nullable NSNumber*) currentStatusFlagsWithError:(NSError**)error
{
    DLABDeckControlMode currentMode = DLABDeckControlModeNotOpened;
    DLABDeckControlVTRControlState currentState = DLABDeckControlVTRControlStateNotInVTRControlMode;
    DLABDeckControlStatusFlag currentFlags = DLABDeckControlStatusFlagDeckConnected;
    NSError* err = nil;
    BOOL result = [self currentStateOfControlMode:&currentMode
                                  vtrControlState:&currentState
                                      statusFlags:&currentFlags
                                            error:&err];
    if (result) {
        return @(currentFlags);
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (nullable NSDictionary<NSString*, NSNumber*>*) currentStateDictionaryWithError:(NSError**)error
{
    DLABDeckControlMode currentMode = DLABDeckControlModeNotOpened;
    DLABDeckControlVTRControlState currentState = DLABDeckControlVTRControlStateNotInVTRControlMode;
    DLABDeckControlStatusFlag currentFlags = DLABDeckControlStatusFlagDeckConnected;
    NSError* err = nil;
    BOOL result = [self currentStateOfControlMode:&currentMode
                                  vtrControlState:&currentState
                                      statusFlags:&currentFlags
                                            error:&err];
    if (result) {
        NSDictionary<NSString*, NSNumber*>* dict = @{
            kCurrentModeKey:@(currentMode),
            kCurrentVTRControlStateKey:@(currentState),
            kCurrentStatusFlagsKey:@(currentFlags)
        };
        return dict;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (BOOL) currentStateOfControlMode:(DLABDeckControlMode*)mode
                   vtrControlState:(DLABDeckControlVTRControlState*)state
                       statusFlags:(DLABDeckControlStatusFlag*)flags
                             error:(NSError**)error
{
    NSParameterAssert(mode && state && flags);
    
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlMode currentMode = bmdDeckControlNotOpened;
    __block BMDDeckControlVTRControlState currentState = bmdDeckControlNotInVTRControlMode;
    __block BMDDeckControlStatusFlags currentFlags = bmdDeckControlStatusDeckConnected;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->GetCurrentState(&currentMode,
                                                       &currentState,
                                                       &currentFlags);
        }];
    }
    if (result == S_OK) {
        *mode = (DLABDeckControlMode)currentMode;
        *state = (DLABDeckControlVTRControlState)currentState;
        *flags = (DLABDeckControlStatusFlag)currentFlags;
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetCurrentState failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) standby:(BOOL)standbyOn error:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::SetStandby failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->SetStandby(standbyOn);
    });
}

- (BOOL) sendCommand:(NSData*)commandBuffer
            response:(NSMutableData*)responseBuffer
        responseSize:(uint32_t*)size
               error:(NSError**)error
{
    NSParameterAssert(commandBuffer && responseBuffer && size);
    
    uint8_t* inBuffer = (uint8_t*)commandBuffer.bytes;
    uint32_t inBufferSize = (uint32_t)commandBuffer.length;
    uint8_t* outBuffer = (uint8_t*)responseBuffer.bytes;
    uint32_t outBufferSize = (uint32_t)responseBuffer.length;
    __block uint32_t outDataSize = 0;
    
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::SendCommand failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->SendCommand(inBuffer, inBufferSize,
                                    outBuffer, &outDataSize,
                                    outBufferSize, deckError);
    });
}

- (BOOL) playWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Play failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Play(deckError);
    });
}

- (BOOL) stopWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Stop failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Stop(deckError);
    });
}

- (BOOL) togglePlayStopWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::TogglePlayStop failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->TogglePlayStop(deckError);
    });
}

- (BOOL) ejectWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Eject failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Eject(deckError);
    });
}

- (BOOL) goToTimecode:(DLABTimecodeBCD)timecode error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::GoToTimecode failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->GoToTimecode(timecode, deckError);
    });
}

- (BOOL) fastForwardWithViewTape:(BOOL)viewTape error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::FastForward failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->FastForward(viewTape, deckError);
    });
}

- (BOOL) rewindWithViewTape:(BOOL)viewTape error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Rewind failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Rewind(viewTape, deckError);
    });
}

- (BOOL) stepForwardWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::StepForward failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->StepForward(deckError);
    });
}

- (BOOL) stepBackWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::StepBack failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->StepBack(deckError);
    });
}

- (BOOL) jogWithRate:(double)rate error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Jog failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Jog(rate, deckError);
    });
}

- (BOOL) shuttleWithRate:(double)rate error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::Shuttle failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->Shuttle(rate, deckError);
    });
}

- (nullable NSString*) timecodeStringWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    __block CFStringRef currentTimeCode = NULL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetTimecodeString(&currentTimeCode, &err);
        }];
    }
    if (result == S_OK && currentTimeCode) {
        return CFBridgingRelease(currentTimeCode);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Shuttle failed."
              code:(NSInteger)err // result
                to:error];
        return nil;
    }
}

- (nullable DLABTimecodeSetting*) timecodeSettingWithError:(NSError**)error
{
    DLABTimecodeSetting* setting = NULL;
    
    __block HRESULT result = E_FAIL;
    __block IDeckLinkTimecode* currentTimeCode = NULL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetTimecode(&currentTimeCode, &err);
        }];
    }
    if (result == S_OK && currentTimeCode) {
        BMDTimecodeFormat format = bmdTimecodeSerial; // dummy
        setting = [[DLABTimecodeSetting alloc] initWithTimecodeFormat:format
                                                          timecodeObj:currentTimeCode];
        currentTimeCode->Release();
        if (setting) {
            return setting;
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"Failed to instantiate DLABTimecodeSetting."
                  code:paramErr
                    to:error];
            return nil;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetTimecode failed."
              code:(NSInteger)err // result
                to:error];
        return nil;
    }
}

- (nullable NSNumber*) timecodeBCDWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDTimecodeBCD currentTimeCode = 0;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetTimecodeBCD(&currentTimeCode, &err);
        }];
    }
    if (result == S_OK) {
        return @(currentTimeCode);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetTimecodeBCD failed."
              code:(NSInteger)err // result
                to:error];
        return nil;
    }
}

- (BOOL) setPrerollSeconds:(uint32_t)prerollInSec error:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::SetPreroll failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->SetPreroll(prerollInSec);
    });
}

- (nullable NSNumber*) prerollSecondsWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block uint32_t prerollInSec = 0;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetPreroll(&prerollInSec);
        }];
    }
    if (result == S_OK) {
        return @(prerollInSec);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetPreroll failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) setCaptureOffset:(int32_t)offsetFields error:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::SetCaptureOffset failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->SetCaptureOffset(offsetFields);
    });
}

- (nullable NSNumber*) captureOffsetWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block int32_t offsetFields = 0;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetCaptureOffset(&offsetFields);
        }];
    }
    if (result == S_OK) {
        return @(offsetFields);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetCaptureOffset failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) setExportOffset:(int32_t)offsetFields error:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::SetExportOffset failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->SetExportOffset(offsetFields);
    });
}

- (nullable NSNumber*) exportOffsetWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block int32_t offsetFields = 0;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetExportOffset(&offsetFields);
        }];
    }
    if (result == S_OK) {
        return @(offsetFields);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetExportOffset failed."
              code:result
                to:error];
        return nil;
    }
}

- (nullable NSNumber*) manualExportOffsetWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block int32_t offsetFields = 0;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetManualExportOffset(&offsetFields);
        }];
    }
    if (result == S_OK) {
        return @(offsetFields);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetManualExportOffset failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) startExportFrom:(DLABTimecodeBCD)inTimecode
                      to:(DLABTimecodeBCD)outTimecode
            modeOpsFlags:(DLABDeckControlExportModeOps)flags
                   error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::StartExport failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->StartExport(inTimecode, outTimecode, flags, deckError);
    });
}

- (BOOL) startCaptureFrom:(DLABTimecodeBCD)inTimecode
                       to:(DLABTimecodeBCD)outTimecode
                  useVITC:(BOOL)useVITC
                    error:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::StartCapture failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->StartCapture(useVITC, inTimecode, outTimecode, deckError);
    });
}

- (nullable NSNumber*) deviceIDWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block uint16_t deviceID = 0;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->GetDeviceID(&deviceID, &err);
        }];
    }
    if (result == S_OK) {
        return @(deviceID);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GetDeviceID failed."
              code:(NSInteger)result
                to:error];
        return nil;
    }
}

- (BOOL) abortWithError:(NSError**)error
{
    return DLABPerformDeckCommand(self,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkDeckControl::Abort failed.",
                                  ^HRESULT(IDeckLinkDeckControl *control) {
        return control->Abort();
    });
}

- (BOOL) crashRecordStartWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::CrashRecordStart failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->CrashRecordStart(deckError);
    });
}

- (BOOL) crashRecordStopWithError:(NSError**)error
{
    return DLABPerformDeckCommandWithStatusError(self,
                                                 error,
                                                 __PRETTY_FUNCTION__,
                                                 __LINE__,
                                                 @"IDeckLinkDeckControl::CrashRecordStop failed.",
                                                 ^HRESULT(IDeckLinkDeckControl *control, BMDDeckControlError *deckError) {
        return control->CrashRecordStop(deckError);
    });
}

@end
