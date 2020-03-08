//
//  DLABDevice.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDevice+Internal.h"

const char* kCaptureQueue = "DLABDevice.captureQueue";
const char* kPlaybackQueue = "DLABDevice.playbackQueue";
const char* kDelegateQueue = "DLABDevice.delegateQueue";

@implementation DLABDevice

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithDeckLink:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
    return nil;
}

- (instancetype) initWithDeckLink:(IDeckLink *)newDeckLink
{
    NSParameterAssert(newDeckLink);
    
    if (self = [super init]) {
        // validate property support (attributes/configuration/status/notification)
        HRESULT err1 = newDeckLink->QueryInterface(IID_IDeckLinkProfileAttributes,
                                                   (void **)&_deckLinkProfileAttributes);
        HRESULT err2 = newDeckLink->QueryInterface(IID_IDeckLinkConfiguration,
                                                   (void **)&_deckLinkConfiguration);
        HRESULT err3 = newDeckLink->QueryInterface(IID_IDeckLinkStatus,
                                                   (void**)&_deckLinkStatus);
        HRESULT err4 = newDeckLink->QueryInterface(IID_IDeckLinkNotification,
                                                   (void**)&_deckLinkNotification);
        
        if (err2) { // 10.11
            err2 = newDeckLink->QueryInterface(IID_IDeckLinkConfiguration_v10_11, //IID_IDeckLinkConfiguration,
            (void **)&_deckLinkConfiguration);
        }
        if (err4) { // 10.11
            err4 = newDeckLink->QueryInterface(IID_IDeckLinkNotification_v10_11, //IID_IDeckLinkNotification,
            (void**)&_deckLinkNotification);
        }
        
        if (err1 || err2 || err3 || err4) {
            if (_deckLinkProfileAttributes) _deckLinkProfileAttributes->Release();
            if (_deckLinkConfiguration) _deckLinkConfiguration->Release();
            if (_deckLinkStatus) _deckLinkStatus->Release();
            if (_deckLinkNotification) _deckLinkNotification->Release();
            return nil;
        }
        
        // Retain IDeckLink and each Interfaces
        _deckLink = newDeckLink;
        _deckLink->AddRef();
        
        //
        outputVideoFrameSet = [NSMutableSet set];
        outputVideoFrameIdleSet = [NSMutableSet set];
        
        //
        [self validate];
    }
    return self;
}

- (void) validate
{
    HRESULT error = E_FAIL;
    
    // Validate support feature (capture/playback)
    BOOL supportsCapture = FALSE;
    BOOL supportsPlayback = FALSE;
    {
        int64_t support = 0;
        error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkVideoIOSupport, &support);
        if (!error) {
            supportsCapture = (support & bmdDeviceSupportsCapture);
            supportsPlayback = (support & bmdDeviceSupportsPlayback);
        }
    }
    
    // Optional c++ objects
    {
        // Validate support feature (Capture)
        if (!_deckLinkInput && supportsCapture) {
            error = _deckLink->QueryInterface(IID_IDeckLinkInput, (void **)&_deckLinkInput);
            if (error) { // 11.4
                error = _deckLink->QueryInterface(IID_IDeckLinkInput_v11_4, (void **)&_deckLinkInput);
            }
            if (error) { // 10.11
                error = _deckLink->QueryInterface(IID_IDeckLinkInput_v10_11, (void **)&_deckLinkInput);
            }
            if (error) {
                if (_deckLinkInput) _deckLinkInput->Release();
                _deckLinkInput = NULL;
                supportsCapture = FALSE;
            }
        }
        
        // Validate support feature (Playback)
        if (!_deckLinkOutput && supportsPlayback) {
            error = _deckLink->QueryInterface(IID_IDeckLinkOutput, (void **)&_deckLinkOutput);
            if (error) { // 11.4
                error = _deckLink->QueryInterface(IID_IDeckLinkOutput_v11_4, (void **)&_deckLinkOutput);
            }
            if (error) { // 10.11
                error = _deckLink->QueryInterface(IID_IDeckLinkOutput_v10_11, (void **)&_deckLinkOutput);
            }
            if (error) {
                if (_deckLinkOutput) _deckLinkOutput->Release();
                _deckLinkOutput = NULL;
                supportsPlayback = FALSE;
            }
        }
        
        // Validate HDMIInputEDID support (optional)
        if (!_deckLinkHDMIInputEDID && supportsCapture) {
            error = _deckLink->QueryInterface(IID_IDeckLinkHDMIInputEDID, (void **)&_deckLinkHDMIInputEDID);
            if (error) {
                if (_deckLinkHDMIInputEDID) _deckLinkHDMIInputEDID->Release();
                _deckLinkHDMIInputEDID = NULL;
            }
        }
        
        // Validate Keyer support (optional)
        if (!_deckLinkKeyer && supportsPlayback) {
            error = _deckLink->QueryInterface(IID_IDeckLinkKeyer, (void **)&_deckLinkKeyer);
            if (error) {
                if (_deckLinkKeyer) _deckLinkKeyer->Release();
                _deckLinkKeyer = NULL;
            }
        }
    }
    
    // Validate support feature
    _supportFlagW = DLABVideoIOSupportNone;
    _supportCaptureW = FALSE;
    _supportPlaybackW = FALSE;
    _supportKeyingW = FALSE;
    
    if (supportsCapture) {
        _supportFlagW = (_supportFlagW | DLABVideoIOSupportCapture);
        _supportCaptureW = TRUE;
    }
    if (supportsPlayback) {
        _supportFlagW = (_supportFlagW | DLABVideoIOSupportPlayback);
        _supportPlaybackW = TRUE;
    }
    if (_deckLinkKeyer) {
        bool keyingInternal = false;
        error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsInternalKeying, &keyingInternal);
        if (!error && keyingInternal)
            _supportFlagW = (_supportFlagW | DLABVideoIOSupportInternalKeying);
        
        bool keyingExternal = false;
        error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsExternalKeying, &keyingExternal);
        if (!error && keyingExternal)
            _supportFlagW = (_supportFlagW | DLABVideoIOSupportExternalKeying);
        
        _supportKeyingW = (keyingInternal || keyingExternal);
    }
    
    // Validate attributes
    _modelNameW = @"Unknown modelName";
    CFStringRef newModelName = nil;
    error = _deckLink->GetModelName(&newModelName);
    if (!error) _modelNameW = CFBridgingRelease(newModelName);
    
    _displayNameW = @"Unknown displayName";
    CFStringRef newDisplayName = nil;
    error = _deckLink->GetDisplayName(&newDisplayName);
    if (!error) _displayNameW = CFBridgingRelease(newDisplayName);
    
    _persistentIDW = 0;
    int64_t newPersistentID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkPersistentID, &newPersistentID);
    if (!error) _persistentIDW = newPersistentID;
    
    _deviceGroupIDW = 0;
    int64_t newDeviceGroupID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkDeviceGroupID, &newDeviceGroupID);
    if (!error) _deviceGroupIDW = newDeviceGroupID;
    
    _topologicalIDW = 0;
    int64_t newTopologicalID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkTopologicalID, &newTopologicalID);
    if (!error) _topologicalIDW = newTopologicalID;
    
    _numberOfSubDevicesW = 0;
    int64_t newNumberOfSubDevices = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkNumberOfSubDevices, &newNumberOfSubDevices);
    if (!error) _numberOfSubDevicesW = newNumberOfSubDevices;
    
    _subDeviceIndexW = 0;
    int64_t newSubDeviceIndex = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkSubDeviceIndex, &newSubDeviceIndex);
    if (!error) _subDeviceIndexW = newSubDeviceIndex;
    
    _profileIDW = 0;
    int64_t newProfileID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkProfileID, &newProfileID);
    if (!error) _profileIDW = newProfileID;
    
    _duplexW = 0;
    int64_t newDuplex = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkDuplex, &newDuplex);
    if (!error) _duplexW = newDuplex;
    
    _supportInputFormatDetectionW = false;
    bool newSupportsInputFormatDetection = false;
    error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsInputFormatDetection,
                                         &newSupportsInputFormatDetection);
    if (!error) _supportInputFormatDetectionW = newSupportsInputFormatDetection;
}

- (void) shutdown
{
    // TODO stop output/input streams
    
    // Release OutputVideoFramePool
    [self freeOutputVideoFramePool];
    
    // Release CFObjects
    if (_inputPixelBufferPool) {
        CVPixelBufferPoolRelease(_inputPixelBufferPool);
        _inputPixelBufferPool = NULL;
    }
    
    // Release c++ objects
    if (_prefsChangeCallback) {
        [self subscribePrefsChangeNotification:NO];
    }
    if (_statusChangeCallback) {
        [self subscribeStatusChangeNotification:NO];
    }
    if (_outputPreviewCallback) {
        _outputPreviewCallback->Release();
        _outputPreviewCallback = NULL;
    }
    if (_inputPreviewCallback) {
        _inputPreviewCallback->Release();
        _inputPreviewCallback = NULL;
    }
    if (_outputCallback) {
        _outputCallback->Release();
        _outputCallback = NULL;
    }
    if (_inputCallback) {
        _inputCallback->Release();
        _inputCallback = NULL;
    }
    
    if (_deckLinkOutput) {
        _deckLinkOutput->Release();
        _deckLinkOutput = NULL;
    }
    if (_deckLinkInput) {
        _deckLinkInput->Release();
        _deckLinkInput = NULL;
    }
    if (_deckLinkKeyer) {
        _deckLinkKeyer->Release();
        _deckLinkKeyer = NULL;
    }
    if (_deckLinkHDMIInputEDID) {
        _deckLinkHDMIInputEDID->Release();
        _deckLinkHDMIInputEDID = NULL;
    }
}

- (void) dealloc
{
    // Shutdown
    [self shutdown];
    
    // Release c++ objects
    if (_deckLinkStatus) {
        _deckLinkStatus->Release();
        //_deckLinkStatus = NULL;
    }
    if (_deckLinkConfiguration) {
        _deckLinkConfiguration->Release();
        //_deckLinkConfiguration = NULL;
    }
    if (_deckLinkProfileAttributes) {
        _deckLinkProfileAttributes->Release();
        //_deckLinkAttributes = NULL;
    }
    if (_deckLink) {
        _deckLink->Release();
        //_deckLink = NULL;
    }
}

/* =================================================================================== */
// MARK: - (Private) - Paired with public readonly
/* =================================================================================== */

@synthesize modelNameW = _modelNameW;
@synthesize displayNameW = _displayNameW;
@synthesize persistentIDW = _persistentIDW;
@synthesize deviceGroupIDW = _deviceGroupIDW;
@synthesize topologicalIDW = _topologicalIDW;
@synthesize numberOfSubDevicesW = _numberOfSubDevicesW;
@synthesize subDeviceIndexW = _subDeviceIndexW;
@synthesize profileIDW = _profileIDW;
@synthesize duplexW = _duplexW;
@synthesize supportFlagW = _supportFlagW;
@synthesize supportCaptureW = _supportCaptureW;
@synthesize supportPlaybackW = _supportPlaybackW;
@synthesize supportKeyingW = _supportKeyingW;
@synthesize supportInputFormatDetectionW = _supportInputFormatDetectionW;

@synthesize outputVideoSettingArrayW = _outputVideoSettingArrayW;
@synthesize inputVideoSettingArrayW = _inputVideoSettingArrayW;
@synthesize outputVideoSettingW = _outputVideoSettingW;
@synthesize inputVideoSettingW = _inputVideoSettingW;
@synthesize outputAudioSettingW = _outputAudioSettingW;
@synthesize inputAudioSettingW = _inputAudioSettingW;

- (NSString*) modelName { return _modelNameW; }
- (NSString*) displayName { return _displayNameW; }
- (int64_t) persistentID { return _persistentIDW; }
- (int64_t) deviceGroupID { return _deviceGroupIDW; }
- (int64_t) topologicalID { return _topologicalIDW; }
- (int64_t) numberOfSubDevices { return _numberOfSubDevicesW; }
- (int64_t) subDeviceIndex { return _subDeviceIndexW; }
- (int64_t) profileID { return _profileIDW; }
- (int64_t) duplex { return _duplexW; }
- (DLABVideoIOSupport) supportFlag { return _supportFlagW; }
- (BOOL) supportCapture { return _supportCaptureW; }
- (BOOL) supportPlayback { return _supportPlaybackW; }
- (BOOL) supportKeying { return _supportKeyingW; }
- (BOOL) supportInputFormatDetection { return _supportInputFormatDetectionW; }

//- (NSArray*) outputVideoSettingArray { return _outputVideoSettingArrayW; } // defined lator
//- (NSArray*) inputVideoSettingArray { return _inputVideoSettingArrayW; } // defined lator
- (DLABVideoSetting*) outputVideoSetting { return _outputVideoSettingW; }
- (DLABVideoSetting*) inputVideoSetting { return _inputVideoSettingW; }
- (DLABAudioSetting*) outputAudioSetting { return _outputAudioSettingW; }
- (DLABAudioSetting*) inputAudioSetting { return _inputAudioSettingW; }

/* =================================================================================== */
// MARK: - (Private) - block helper
/* =================================================================================== */

- (void) delegate_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.delegateQueue;
    if (queue) {
        if (delegateQueueKey && dispatch_get_specific(delegateQueueKey)) {
            block(); // do sync operation
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

- (void) delegate_async:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.delegateQueue;
    if (queue) {
        if (delegateQueueKey && dispatch_get_specific(delegateQueueKey)) {
            block(); // do sync operation instead of async
        } else {
            dispatch_async(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

- (void) playback_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.playbackQueue;
    if (queue) {
        if (playbackQueueKey && dispatch_get_specific(playbackQueueKey)) {
            block();
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

- (void) capture_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.captureQueue;
    if (queue) {
        if (captureQueueKey && dispatch_get_specific(captureQueueKey)) {
            block();
        } else {
            dispatch_sync(queue, block);
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
// MARK: - (Private/Public) - Subscription Status/Preferences Change
/* =================================================================================== */

// private DLABNotificationCallbackDelegate
- (void) notify:(BMDNotifications)topic param1:(uint64_t)param1 param2:(uint64_t)param2
{
    // check topic if it is statusChanged
    if (topic == bmdStatusChanged) {
        // delegate can handle status changed event here
        id<DLABStatusChangeDelegate> delegate = self.statusDelegate;
        if (delegate) {
            __weak typeof(self) wself = self;
            [self delegate_async:^{
                [delegate statusChanged:(DLABDeckLinkStatus)param1
                               ofDevice:wself]; // async
            }];
        }
    } else if (topic == bmdPreferencesChanged) {
        // delegate can handle prefs change event here
        id<DLABPrefsChangeDelegate> delegate = self.prefsDelegate;
        if (delegate) {
            __weak typeof(self) wself = self;
            [self delegate_async:^{
                [delegate prefsChangedOfDevice:wself]; // async
            }];
        }
    } else {
        NSLog(@"ERROR: Unsupported notification topic is detected.");
    }
}

// public setter
- (void) setStatusChangeDelegate:(id<DLABStatusChangeDelegate>)newDelegate
{
    if (_statusDelegate == newDelegate) return;
    if (_statusDelegate) {
        // Unsubscribe request from current delegate
        _statusDelegate = nil;
        
        [self subscribeStatusChangeNotification:NO];
    }
    if (newDelegate) {
        // Subscribe request from new delegate
        _statusDelegate = newDelegate;
        
        [self subscribeStatusChangeNotification:YES];
    }
}

// private setter helper
- (BOOL) subscribeStatusChangeNotification:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkNotification *notification = self.deckLinkNotification;
    if (flag) {
        if (_statusChangeCallback)
            return YES; // We are currently subscribing status change
        
        _statusChangeCallback = new DLABNotificationCallback((id)self);
        if (!_statusChangeCallback) {
            NSLog(@"ERROR: IDeckLinkNotificationCallback is not available.");
            return NO;
        }
        
        result = notification->Subscribe(bmdStatusChanged, _statusChangeCallback);
        if (!result) {
            return YES;
        } else {
            NSLog(@"ERROR: IDeckLinkNotification::Subscribe failed.");
            _statusChangeCallback->Release();
            _statusChangeCallback = NULL;
            return NO;
        }
    } else {
        if (!_statusChangeCallback)
            return YES; // We are not subscribing for now
        
        result = notification->Unsubscribe(bmdStatusChanged, _statusChangeCallback);
        if (!result) {
            _statusChangeCallback->Release();
            _statusChangeCallback = NULL;
            return YES;
        } else {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
            return NO;
        }
    }
}

// public setter
- (void) setPrefsChangeDelegate:(id<DLABPrefsChangeDelegate>)newDelegate
{
    if (_prefsDelegate == newDelegate) return;
    if (_prefsDelegate) {
        // Unsubscribe request from current delegate
        _prefsDelegate = nil;
        
        [self subscribePrefsChangeNotification:NO];
    }
    if (newDelegate) {
        // Subscribe request from new delegate
        _prefsDelegate = newDelegate;
        
        [self subscribePrefsChangeNotification:YES];
    }
}

// private setter helper
- (BOOL) subscribePrefsChangeNotification:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkNotification *notification = self.deckLinkNotification;
    if (flag) {
        if (_prefsChangeCallback)
            return YES; // We are currently subscribing prefs change
        
        _prefsChangeCallback = new DLABNotificationCallback((id)self);
        if (!_prefsChangeCallback) {
            NSLog(@"ERROR: IDeckLinkNotificationCallback is not available.");
            return NO;
        }
        
        result = notification->Subscribe(bmdPreferencesChanged, _prefsChangeCallback);
        if (!result) {
            return YES;
        } else {
            NSLog(@"ERROR: IDeckLinkNotification::Subscribe failed.");
            _prefsChangeCallback->Release();
            _prefsChangeCallback = NULL;
            return NO;
        }
    } else {
        if (!_prefsChangeCallback)
            return YES; // We are not subscribing for now
        
        result = notification->Unsubscribe(bmdPreferencesChanged, _prefsChangeCallback);
        if (!result) {
            _prefsChangeCallback->Release();
            _prefsChangeCallback = NULL;
            return YES;
        } else {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
            return NO;
        }
    }
}

/* =================================================================================== */
// MARK: - (Public) - accessor - lazy instantiation
/* =================================================================================== */

- (NSArray*) outputVideoSettingArray
{
    if (!_outputVideoSettingArrayW) {
        IDeckLinkOutput* output = self.deckLinkOutput;
        if (output) {
            // Get DisplayModeIterator
            HRESULT result = E_FAIL;
            IDeckLinkDisplayModeIterator* iterator = NULL;
            result = output->GetDisplayModeIterator(&iterator);
            if (!result) {
                // Iterate DisplayModeObj(s) and create dictionaries of them
                NSMutableArray *array = [[NSMutableArray alloc] init];
                IDeckLinkDisplayMode* displayModeObj = NULL;
                
                while (iterator->Next(&displayModeObj) == S_OK) {
                    DLABVideoSetting* setting = [[DLABVideoSetting alloc]
                                                 initWithDisplayModeObj:displayModeObj];
                    if (setting)
                        [array addObject:setting];
                    
                    displayModeObj->Release();
                }
                
                iterator->Release();
                
                _outputVideoSettingArrayW = [NSArray arrayWithArray:array];
            }
        }
    }
    return _outputVideoSettingArrayW;
}

- (NSArray*) inputVideoSettingArray
{
    if (!_inputVideoSettingArrayW) {
        IDeckLinkInput* input = self.deckLinkInput;
        if (input) {
            // Get DisplayModeIterator
            HRESULT result = E_FAIL;
            IDeckLinkDisplayModeIterator* iterator = NULL;
            result = input->GetDisplayModeIterator(&iterator);
            if (!result) {
                // Iterate DisplayModeObj(s) and create dictionaries of them
                NSMutableArray *array = [[NSMutableArray alloc] init];
                IDeckLinkDisplayMode* displayModeObj = NULL;
                
                while (iterator->Next(&displayModeObj) == S_OK) {
                    DLABVideoSetting* setting = [[DLABVideoSetting alloc]
                                                 initWithDisplayModeObj:displayModeObj];
                    if (setting)
                        [array addObject:setting];
                    
                    displayModeObj->Release();
                }
                
                iterator->Release();
                
                _inputVideoSettingArrayW = [NSArray arrayWithArray:array];
            }
        }
    }
    return _inputVideoSettingArrayW;
}

/* =================================================================================== */
// MARK: - (Private) - accessor - lazy instantiation
/* =================================================================================== */

- (int) apiVersion
{
    if (_apiVersion == 0) {
        IDeckLinkAPIInformation* api = CreateDeckLinkAPIInformationInstance();
        if (api != NULL) {
            HRESULT result = E_FAIL;
            BMDDeckLinkAPIInformationID cfgID = DLABDeckLinkAPIInformationVersion;
            int64_t newIntValue = false;
            result = api->GetInt(cfgID, &newIntValue);
            if (!result) {
                _apiVersion = (int)newIntValue;
            }
            api->Release();
        }
    }
    return _apiVersion;
}

- (DLABInputCallback *)inputCallback
{
    if (!_inputCallback) {
        IDeckLinkInput * input = self.deckLinkInput;
        if (input) {
            HRESULT result = E_FAIL;
            _inputCallback = new DLABInputCallback((id)self);
            result = input->SetCallback(_inputCallback);
            if (result) {
                NSLog(@"ERROR: IDeckLinkInput::SetCallback failed.");
                _inputCallback->Release();
                _inputCallback = NULL;
            }
        }
    }
    return _inputCallback;
}

- (DLABOutputCallback *)outputCallback
{
    if (!_outputCallback) {
        IDeckLinkOutput *output = self.deckLinkOutput;
        if (output) {
            HRESULT result = E_FAIL;
            _outputCallback = new DLABOutputCallback((id)self);
            result = output->SetScheduledFrameCompletionCallback(_outputCallback);
            if (result) {
                NSLog(@"ERROR: IDeckLinkOutput::SetScheduledFrameCompletionCallback failed.");
                _outputCallback->Release();
                _outputCallback = NULL;
            }
        }
    }
    return _outputCallback;
}

- (dispatch_queue_t) captureQueue
{
    if (!_captureQueue) {
        _captureQueue = dispatch_queue_create(kCaptureQueue, DISPATCH_QUEUE_SERIAL);
        captureQueueKey = &captureQueueKey;
        void *unused = (__bridge void*)self;
        dispatch_queue_set_specific(_captureQueue, captureQueueKey, unused, NULL);
    }
    return _captureQueue;
}

- (dispatch_queue_t) playbackQueue
{
    if (!_playbackQueue) {
        _playbackQueue = dispatch_queue_create(kPlaybackQueue, DISPATCH_QUEUE_SERIAL);
        playbackQueueKey = &playbackQueueKey;
        void *unused = (__bridge void*)self;
        dispatch_queue_set_specific(_playbackQueue, playbackQueueKey, unused, NULL);
    }
    return _playbackQueue;
}

- (dispatch_queue_t) delegateQueue
{
    if (!_delegateQueue) {
        _delegateQueue = dispatch_queue_create(kDelegateQueue, DISPATCH_QUEUE_SERIAL);
        delegateQueueKey = &delegateQueueKey;
        void *unused = (__bridge void*)self;
        dispatch_queue_set_specific(_delegateQueue, delegateQueueKey, unused, NULL);
    }
    return _delegateQueue;
}

- (void) setInputPixelBufferPool:(CVPixelBufferPoolRef)newPool
{
    if (_inputPixelBufferPool == newPool) return;
    if (_inputPixelBufferPool) {
        CVPixelBufferPoolRelease(_inputPixelBufferPool);
        _inputPixelBufferPool = NULL;
    }
    if (newPool) {
        CVPixelBufferPoolRetain(newPool);
        _inputPixelBufferPool = newPool;
    }
}

- (void) setOutputPreviewCallback:(IDeckLinkScreenPreviewCallback *)newPreviewCallback
{
    if (_outputPreviewCallback == newPreviewCallback) return;
    if (_outputPreviewCallback) {
        _outputPreviewCallback->Release();
        _outputPreviewCallback = NULL;
    }
    if (newPreviewCallback) {
        _outputPreviewCallback = newPreviewCallback;
        _outputPreviewCallback->AddRef();
    }
}

- (void) setInputPreviewCallback:(IDeckLinkScreenPreviewCallback *)newPreviewCallback
{
    if (_inputPreviewCallback == newPreviewCallback) return;
    if (_inputPreviewCallback) {
        _inputPreviewCallback->Release();
        _inputPreviewCallback = NULL;
    }
    if (newPreviewCallback) {
        _inputPreviewCallback = newPreviewCallback;
        _inputPreviewCallback->AddRef();
    }
}

/* =================================================================================== */
// MARK: - getter attributeID
/* =================================================================================== */

- (NSNumber*) boolValueForAttribute:(DLABAttribute) attributeID
                              error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    bool newBoolValue = false;
    result = _deckLinkProfileAttributes->GetFlag(attr, &newBoolValue);
    if (!result) {
        return @(newBoolValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetFlag failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                             error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    int64_t newIntValue = 0;
    result = _deckLinkProfileAttributes->GetInt(attr, &newIntValue);
    if (!result) {
        return @(newIntValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetInt failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    double newDoubleValue = 0;
    result = _deckLinkProfileAttributes->GetFloat(attr, &newDoubleValue);
    if (!result) {
        return @(newDoubleValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetFloat failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    CFStringRef newStringValue = NULL;
    result = _deckLinkProfileAttributes->GetString(attr, &newStringValue);
    if (!result) {
        return (NSString*)CFBridgingRelease(newStringValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetString failed."
              code:result
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: - getter configurationID
/* =================================================================================== */

- (NSNumber*) boolValueForConfiguration:(DLABConfiguration)configurationID
                                  error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    bool newBoolValue = false;
    result = _deckLinkConfiguration->GetFlag(conf, &newBoolValue);
    if (!result) {
        return @(newBoolValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::GetFlag failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) intValueForConfiguration:(DLABConfiguration)configurationID
                                 error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    int64_t newIntValue = 0;
    result = _deckLinkConfiguration->GetInt(conf, &newIntValue);
    if (!result) {
        return @(newIntValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::GetInt failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) doubleValueForConfiguration:(DLABConfiguration)configurationID
                                    error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    double newDoubleValue = 0;
    result = _deckLinkConfiguration->GetFloat(conf, &newDoubleValue);
    if (!result) {
        return @(newDoubleValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::GetFloat failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSString*) stringValueForConfiguration:(DLABConfiguration)configurationID
                                    error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    CFStringRef newStringValue = NULL;
    result = _deckLinkConfiguration->GetString(conf, &newStringValue);
    if (!result) {
        return (NSString*)CFBridgingRelease(newStringValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::GetString failed."
              code:result
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: - setter configrationID
/* =================================================================================== */

- (BOOL) setBoolValue:(BOOL)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    bool newBoolValue = (bool)value;
    result = _deckLinkConfiguration->SetFlag(conf, newBoolValue);
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::SetFlag failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) setIntValue:(NSInteger)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    int64_t newIntValue = (int64_t)value;
    result = _deckLinkConfiguration->SetInt(conf, newIntValue);
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::SetInt failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) setDoubleValue:(double_t)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    double newDoubleValue = (double)value;
    result = _deckLinkConfiguration->SetFloat(conf, newDoubleValue);
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::SetFloat failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) setStringValue:(NSString*)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkConfigurationID conf = configurationID;
    CFStringRef newStringValue = (CFStringRef)CFBridgingRetain(value);
    result = _deckLinkConfiguration->SetString(conf, newStringValue);
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::SetString failed."
              code:result
                to:error];
        return NO;
    }
}

- (BOOL) writeConfigurationToPreferencesWithError:(NSError**)error
{
    HRESULT result = E_FAIL;
    result = _deckLinkConfiguration->WriteConfigurationToPreferences();
    if (!result) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkConfiguration::WriteConfigurationToPreferences failed."
              code:result
                to:error];
        return NO;
    }
}

/* =================================================================================== */
// MARK: - getter statusID
/* =================================================================================== */

- (NSNumber*) boolValueForStatus:(DLABDeckLinkStatus)statusID
                           error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkStatusID stat = statusID;
    bool newBoolValue = false;
    result = _deckLinkStatus->GetFlag(stat, &newBoolValue);
    if (!result) {
        return @(newBoolValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetFlag failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) intValueForStatus:(DLABDeckLinkStatus)statusID
                          error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkStatusID stat = statusID;
    int64_t newIntValue = 0;
    result = _deckLinkStatus->GetInt(stat, &newIntValue);
    if (!result) {
        return @(newIntValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetInt failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) doubleValueForStatus:(DLABDeckLinkStatus)statusID
                             error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkStatusID stat = statusID;
    double newDoubleValue = 0;
    result = _deckLinkStatus->GetFloat(stat, &newDoubleValue);
    if (!result) {
        return @(newDoubleValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetFloat failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSString*) stringValueForStatus:(DLABDeckLinkStatus)statusID
                             error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkStatusID stat = statusID;
    CFStringRef newStringValue = NULL;
    result = _deckLinkStatus->GetString(stat, &newStringValue);
    if (!result) {
        return (NSString*)CFBridgingRelease(newStringValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetString failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSMutableData*) dataValueForStatus:(DLABDeckLinkStatus)statusID
                               ofSize:(NSUInteger)requestSize error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkStatusID stat = statusID;
    
    // Prepare bytes buffer
    NSMutableData* data = nil;
    if (requestSize == 0) {
        data = [NSMutableData data];
    } else {
        data = [NSMutableData dataWithLength:requestSize];
    }
    if (!data) {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"Failed to create NSMutableData."
              code:E_FAIL
                to:error];
        return nil;
    }
    
    // fill bytes with specified StatusID
    void* buffer = (void*)data.mutableBytes;
    uint32_t bufferSize = (uint32_t)data.length;
    result = _deckLinkStatus->GetBytes(stat, buffer, &bufferSize);
    if (!result) {
        if (requestSize == 0 && bufferSize > 0) {
            data = [self dataValueForStatus:statusID ofSize:(NSUInteger)bufferSize error:error];
        }
        if (data) {
            return data; // immutable deep copy
        } else {
            return nil;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetBytes failed."
              code:result
                to:error];
        return nil;
    }
}

@end
