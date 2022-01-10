//
//  DLABDeckControl.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020-2022 MyCometG3. All rights reserved.
//

#import "DLABDeckControl+Internal.h"

const char* kDeckQueue = "DLABDeckControl.deckQueue";

NSString* const kCurrentModeKey = @"currentMode";
NSString* const kCurrentVTRControlStateKey = @"currentState";
NSString* const kCurrentStatusFlagsKey = @"currentFlags";

@implementation DLABDeckControl

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithDeckLink:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
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
    if (!_deckQueue) {
        _deckQueue = dispatch_queue_create(kDeckQueue, DISPATCH_QUEUE_SERIAL);
        deckQueueKey = &deckQueueKey;
        void *unused = (__bridge void*)self;
        dispatch_queue_set_specific(_deckQueue, deckQueueKey, unused, NULL);
    }
    return _deckQueue;
}

- (void) deck_sync:(dispatch_block_t)block
{
    dispatch_queue_t queue = self.deckQueue;
    if (queue) {
        if (deckQueueKey && dispatch_get_specific(deckQueueKey)) {
            block(); // do sync operation
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

- (void) deck_async:(dispatch_block_t)block
{
    dispatch_queue_t queue = self.deckQueue;
    if (queue) {
        if (deckQueueKey && dispatch_get_specific(deckQueueKey)) {
            block(); // do sync operation instead of async
        } else {
            dispatch_async(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
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
    __block HRESULT result = E_FAIL;
    BMDTimeScale timeScale = (BMDTimeScale)timebase.timescale;
    BMDTimeValue timeValue = (BMDTimeValue)timebase.value;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->Open(timeScale, timeValue, dropFrame, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Open failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) closeWithStandby:(BOOL)standby error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->Close(standby);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Close failed."
              code:result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->SetStandby(standbyOn);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::SetStandby failed."
              code:result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    __block uint32_t outDataSize = 0;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->SendCommand(inBuffer, inBufferSize,
                                                   outBuffer, &outDataSize,
                                                   outBufferSize, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::SendCommand failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) playWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->Play(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Play failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) stopWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->Stop(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Stop failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) togglePlayStopWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->TogglePlayStop(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::TogglePlayStop failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) ejectWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->Eject(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Eject failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) goToTimecode:(DLABTimecodeBCD)timecode error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = self.deckControl->GoToTimecode(timecode, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::GoToTimecode failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) fastForwardWithViewTape:(BOOL)viewTape error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->FastForward(viewTape, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::FastForward failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) rewindWithViewTape:(BOOL)viewTape error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->Rewind(viewTape, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Rewind failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) stepForwardWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->StepForward(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::StepForward failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) stepBackWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->StepBack(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::StepBack failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) jogWithRate:(double)rate error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->Jog(rate, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Jog failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) shuttleWithRate:(double)rate error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->Shuttle(rate, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Shuttle failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->SetPreroll(prerollInSec);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::SetPreroll failed."
              code:result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->SetCaptureOffset(offsetFields);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::SetCaptureOffset failed."
              code:result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->SetExportOffset(offsetFields);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::SetExportOffset failed."
              code:result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->StartExport(inTimecode, outTimecode, flags, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::StartExport failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) startCaptureFrom:(DLABTimecodeBCD)inTimecode
                       to:(DLABTimecodeBCD)outTimecode
                  useVITC:(BOOL)useVITC
                    error:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->StartCapture(useVITC, inTimecode, outTimecode, &err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::StartCapture failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
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
    __block HRESULT result = E_FAIL;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->Abort();
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::Abort failed."
              code:(NSInteger)result
                to:error];
        return NO;
    }
}

- (BOOL) crashRecordStartWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->CrashRecordStart(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::CrashRecordStart failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

- (BOOL) crashRecordStopWithError:(NSError**)error
{
    __block HRESULT result = E_FAIL;
    __block BMDDeckControlError err = bmdDeckControlNoError;
    IDeckLinkDeckControl* control = self.deckControl;
    if (control) {
        [self deck_sync:^{
            result = control->CrashRecordStop(&err);
        }];
    }
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkDeckControl::CrashRecordStop failed."
              code:(NSInteger)err // result
                to:error];
        return NO;
    }
}

@end
