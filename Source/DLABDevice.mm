//
//  DLABDevice.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDevice+Internal.h>

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
            if (error) { // 14.2.1
                error = _deckLink->QueryInterface(IID_IDeckLinkInput_v14_2_1, (void **)&_deckLinkInput);
            }
            if (error) { // 11.5.1
                error = _deckLink->QueryInterface(IID_IDeckLinkInput_v11_5_1, (void **)&_deckLinkInput);
            }
            if (error) { // 11.4
                error = _deckLink->QueryInterface(IID_IDeckLinkInput_v11_4, (void **)&_deckLinkInput);
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
            if (error) { // 14.2.1
                error = _deckLink->QueryInterface(IID_IDeckLinkOutput_v14_2_1, (void **)&_deckLinkOutput);
            }
            if (error) { // 11.4
                error = _deckLink->QueryInterface(IID_IDeckLinkOutput_v11_4, (void **)&_deckLinkOutput);
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
        
        // Validate Profile support (optional)
        if (!_deckLinkProfileManager) {
            error = _deckLink->QueryInterface(IID_IDeckLinkProfileManager, (void **)&_deckLinkProfileManager);
            if (error) {
                if (_deckLinkProfileManager) _deckLinkProfileManager->Release();
                _deckLinkProfileManager = NULL;
            }
        }
    }
    
    // Validate support feature
    _supportFlag = DLABVideoIOSupportNone;
    _supportCapture = FALSE;
    _supportPlayback = FALSE;
    _supportKeying = FALSE;
    
    if (supportsCapture) {
        _supportFlag = (_supportFlag | DLABVideoIOSupportCapture);
        _supportCapture = TRUE;
    }
    if (supportsPlayback) {
        _supportFlag = (_supportFlag | DLABVideoIOSupportPlayback);
        _supportPlayback = TRUE;
    }
    if (_deckLinkKeyer) {
        bool keyingInternal = false;
        error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsInternalKeying, &keyingInternal);
        if (!error && keyingInternal)
            _supportFlag = (_supportFlag | DLABVideoIOSupportInternalKeying);
        
        bool keyingExternal = false;
        error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsExternalKeying, &keyingExternal);
        if (!error && keyingExternal)
            _supportFlag = (_supportFlag | DLABVideoIOSupportExternalKeying);
        
        _supportKeying = (keyingInternal || keyingExternal);
    }
    
    // Validate attributes
    _modelName = @"Unknown modelName";
    CFStringRef newModelName = nil;
    error = _deckLink->GetModelName(&newModelName);
    if (!error) _modelName = CFBridgingRelease(newModelName);
    
    _displayName = @"Unknown displayName";
    CFStringRef newDisplayName = nil;
    error = _deckLink->GetDisplayName(&newDisplayName);
    if (!error) _displayName = CFBridgingRelease(newDisplayName);
    
    _persistentID = 0;
    int64_t newPersistentID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkPersistentID, &newPersistentID);
    if (!error) _persistentID = newPersistentID;
    
    _deviceGroupID = 0;
    int64_t newDeviceGroupID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkDeviceGroupID, &newDeviceGroupID);
    if (!error) _deviceGroupID = newDeviceGroupID;
    
    _topologicalID = 0;
    int64_t newTopologicalID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkTopologicalID, &newTopologicalID);
    if (!error) _topologicalID = newTopologicalID;
    
    _numberOfSubDevices = 0;
    int64_t newNumberOfSubDevices = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkNumberOfSubDevices, &newNumberOfSubDevices);
    if (!error) _numberOfSubDevices = newNumberOfSubDevices;
    
    _subDeviceIndex = 0;
    int64_t newSubDeviceIndex = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkSubDeviceIndex, &newSubDeviceIndex);
    if (!error) _subDeviceIndex = newSubDeviceIndex;
    
    _profileID = 0;
    int64_t newProfileID = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkProfileID, &newProfileID);
    if (!error) _profileID = newProfileID;
    
    _duplex = 0;
    int64_t newDuplex = 0;
    error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkDuplex, &newDuplex);
    if (!error) _duplex = newDuplex;
    
    _supportInputFormatDetection = false;
    bool newSupportsInputFormatDetection = false;
    error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsInputFormatDetection,
                                                &newSupportsInputFormatDetection);
    if (!error) _supportInputFormatDetection = newSupportsInputFormatDetection;
    
    _supportHDRMetadata = false;
    bool newSupportsHDRMetadata = false;
    error = _deckLinkProfileAttributes->GetFlag(BMDDeckLinkSupportsHDRMetadata,
                                                &newSupportsHDRMetadata);
    if (!error) _supportHDRMetadata = newSupportsHDRMetadata;
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
    
    // Release c++ Callback objects
    if (_outputPreviewCallback) {
        [self setOutputScreenPreviewToView:nil error:nil];
        _outputPreviewCallback->Release();
        _outputPreviewCallback = NULL;
    }
    if (_inputPreviewCallback) {
        [self setInputScreenPreviewToView:nil error:nil];
        _inputPreviewCallback->Release();
        _inputPreviewCallback = NULL;
    }
    if (_profileCallback) {
        [self subscribeProfileChange:NO];
        _profileCallback->Release();
        _profileCallback = NULL;
    }
    if (_prefsChangeCallback) {
        [self subscribePrefsChangeNotification:NO];
        _prefsChangeCallback->Release();
        _prefsChangeCallback = NULL;
    }
    if (_statusChangeCallback) {
        [self subscribeStatusChangeNotification:NO];
        _statusChangeCallback->Release();
        _statusChangeCallback = NULL;
    }
    if (_outputCallback) {
        [self subscribeOutput:NO];
        _outputCallback->Release();
        _outputCallback = NULL;
    }
    if (_inputCallback) {
        [self subscribeInput:NO];
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
    if (_deckLinkProfileManager) {
        _deckLinkProfileManager->Release();
        _deckLinkProfileManager = NULL;
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
    if (_deckLinkNotification) {
        _deckLinkNotification->Release();
        //_deckLinkNotification = NULL;
    }
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
// MARK: - (Public RO/Private RW) - property accessor
/* =================================================================================== */

- (DLABVideoSetting*) outputVideoSetting { return _outputVideoSettingW; }
- (DLABVideoSetting*) inputVideoSetting { return _inputVideoSettingW; }
- (DLABAudioSetting*) outputAudioSetting { return _outputAudioSettingW; }
- (DLABAudioSetting*) inputAudioSetting { return _inputAudioSettingW; }

@synthesize outputVideoSettingW = _outputVideoSettingW;
@synthesize inputVideoSettingW = _inputVideoSettingW;
@synthesize outputAudioSettingW = _outputAudioSettingW;
@synthesize inputAudioSettingW = _inputAudioSettingW;

/* =================================================================================== */
// MARK: - (Public) property accessor
/* =================================================================================== */

@synthesize modelName = _modelName;
@synthesize displayName = _displayName;
@synthesize persistentID = _persistentID;
@synthesize deviceGroupID = _deviceGroupID;
@synthesize topologicalID = _topologicalID;
@synthesize numberOfSubDevices = _numberOfSubDevices;
@synthesize subDeviceIndex = _subDeviceIndex;
@synthesize profileID = _profileID;
@synthesize duplex = _duplex;

@synthesize supportFlag = _supportFlag;
@synthesize supportCapture = _supportCapture;
@synthesize supportPlayback = _supportPlayback;
@synthesize supportKeying = _supportKeying;
@synthesize supportInputFormatDetection = _supportInputFormatDetection;
@synthesize supportHDRMetadata = _supportHDRMetadata;

// MARK: -

@synthesize swapHDMICh3AndCh4OnInput = _swapHDMICh3AndCh4OnInput;
@synthesize swapHDMICh3AndCh4OnOutput = _swapHDMICh3AndCh4OnOutput;

// MARK: -

@synthesize outputVideoSettingArray = _outputVideoSettingArray;
@synthesize inputVideoSettingArray = _inputVideoSettingArray;
@synthesize deckControl = _deckControl;

// MARK: -

@synthesize outputDelegate = _outputDelegate;
@synthesize inputDelegate = _inputDelegate;
@synthesize statusDelegate = _statusDelegate;
@synthesize prefsDelegate = _prefsDelegate;
@synthesize profileDelegate = _profileDelegate;

@synthesize inputVANCLines = _inputVANCLines;
@synthesize inputVANCHandler = _inputVANCHandler;
@synthesize outputVANCLines = _outputVANCLines;
@synthesize outputVANCHandler = _outputVANCHandler;
@synthesize inputVANCPacketHandler = _inputVANCPacketHandler;
@synthesize outputVANCPacketHandler = _outputVANCPacketHandler;

@synthesize inputFrameMetadataHandler = _inputFrameMetadataHandler;
@synthesize outputFrameMetadataHandler = _outputFrameMetadataHandler;

@synthesize debugUsevImageCopyBuffer = _debugUsevImageCopyBuffer;
@synthesize debugCalcPixelSizeFast = _debugCalcPixelSizeFast;

@synthesize inputPixelBufferAttributes = _inputPixelBufferAttributes;

/* =================================================================================== */
// MARK: - (Private) property accessor
/* =================================================================================== */

@synthesize deckLink = _deckLink;
@synthesize deckLinkProfileAttributes = _deckLinkProfileAttributes;
@synthesize deckLinkConfiguration = _deckLinkConfiguration;
@synthesize deckLinkStatus = _deckLinkStatus;
@synthesize deckLinkNotification = _deckLinkNotification;

@synthesize deckLinkHDMIInputEDID = _deckLinkHDMIInputEDID;
@synthesize deckLinkInput = _deckLinkInput;
@synthesize deckLinkOutput = _deckLinkOutput;
@synthesize deckLinkKeyer = _deckLinkKeyer;
@synthesize deckLinkProfileManager = _deckLinkProfileManager;

// MARK: -

@synthesize inputCallback = _inputCallback;
@synthesize outputCallback = _outputCallback;
@synthesize statusChangeCallback = _statusChangeCallback;
@synthesize prefsChangeCallback = _prefsChangeCallback;
@synthesize profileCallback = _profileCallback;
@synthesize captureQueue = _captureQueue;
@synthesize playbackQueue = _playbackQueue;
@synthesize delegateQueue = _delegateQueue;
@synthesize apiVersion = _apiVersion;

// MARK: -

@synthesize captureQueueKey = captureQueueKey;
@synthesize playbackQueueKey = playbackQueueKey;
@synthesize delegateQueueKey = delegateQueueKey;
@synthesize outputVideoFrameSet = outputVideoFrameSet;
@synthesize outputVideoFrameIdleSet = outputVideoFrameIdleSet;

@synthesize inputPixelBufferPool = _inputPixelBufferPool;
@synthesize outputPreviewCallback = _outputPreviewCallback;
@synthesize inputPreviewCallback = _inputPreviewCallback;

@synthesize needsInputVideoConfigurationRefresh = _needsInputVideoConfigurationRefresh;
@synthesize inputVideoConverter = _inputVideoConverter;
@synthesize outputVideoConverter = _outputVideoConverter;

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
// MARK: - (Private) - Subscription/Callback
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

// Support private callbacks (will be forwarded to delegates)

// Private helper method for input
- (BOOL) subscribeInput:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkInput * input = self.deckLinkInput;
    DLABInputCallback* callback = self.inputCallback;
    if (!input || !callback) return FALSE;
    if (flag) {
        result = input->SetCallback(callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkInput::SetCallback failed.");
        }
    } else {
        result = input->SetCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkInput::SetCallback failed.");
        }
    }
    return (result == S_OK);
}

// Private helper method for output
- (BOOL) subscribeOutput:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkOutput * output = self.deckLinkOutput;
    DLABOutputCallback* callback = self.outputCallback;
    if (!output || !callback) return FALSE;
    if (flag) {
        result = output->SetScheduledFrameCompletionCallback(callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkOutput::SetScheduledFrameCompletionCallback failed.");
        }
    } else {
        result = output->SetScheduledFrameCompletionCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkOutput::SetScheduledFrameCompletionCallback failed.");
        }
    }
    return (result == S_OK);
}

// Private helper method for statusChange
- (BOOL) subscribeStatusChangeNotification:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkNotification *notification = self.deckLinkNotification;
    DLABNotificationCallback *callback = self.statusChangeCallback;
    if (!notification || !callback) return FALSE;
    if (flag) {
        result = notification->Subscribe(bmdStatusChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Subscribe failed.");
        }
    } else {
        result = notification->Unsubscribe(bmdStatusChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
        }
    }
    return (result == S_OK);
}

// Private helper method for preferencesChange
- (BOOL) subscribePrefsChangeNotification:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkNotification *notification = self.deckLinkNotification;
    DLABNotificationCallback *callback = self.prefsChangeCallback;
    if (!notification || !callback) return FALSE;
    if (flag) {
        result = notification->Subscribe(bmdPreferencesChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Subscribe failed.");
        }
    } else {
        result = notification->Unsubscribe(bmdPreferencesChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
        }
    }
    return (result == S_OK);
}

// Private helper method for profileChange
- (BOOL) subscribeProfileChange:(BOOL) flag
{
    HRESULT result = E_FAIL;
    IDeckLinkProfileManager* manager = self.deckLinkProfileManager;
    DLABProfileCallback* callback = self.profileCallback;
    if (!manager || !callback) return FALSE;
    if (flag) {
        result = manager->SetCallback(callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkProfileManager::SetCallback failed.");
        }
    } else {
        result = manager->SetCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkProfileManager::SetCallback failed.");
        }
    }
    return (result == S_OK);
}

/* =================================================================================== */
// MARK: - (Public) - property getter - lazy instantiation
/* =================================================================================== */

- (NSArray*) outputVideoSettingArray
{
    if (!_outputVideoSettingArray) {
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
                
                _outputVideoSettingArray = [NSArray arrayWithArray:array];
            }
        }
    }
    return _outputVideoSettingArray;
}

- (NSArray*) inputVideoSettingArray
{
    if (!_inputVideoSettingArray) {
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
                
                _inputVideoSettingArray = [NSArray arrayWithArray:array];
            }
        }
    }
    return _inputVideoSettingArray;
}

- (DLABDeckControl*) deckControl
{
    if (!_deckControl) {
        _deckControl = [[DLABDeckControl alloc] initWithDeckLink:self.deckLink];
    }
    return _deckControl;
}

/* =================================================================================== */
// MARK: - (Public) - property setter
/* =================================================================================== */

- (void) setOutputDelegate:(id<DLABOutputPlaybackDelegate>)newDelegate
{
    if (_outputDelegate == newDelegate) return;
    if (_outputDelegate) {
        // Unsubscribe request from current delegate
        _outputDelegate = nil;
        
        [self subscribeOutput:NO];
    }
    if (newDelegate) {
        // Subscribe request from new delegate
        _outputDelegate = newDelegate;
        
        [self subscribeOutput:YES];
    }
}

- (void) setInputDelegate:(id<DLABInputCaptureDelegate>)newDelegate
{
    if (_inputDelegate == newDelegate) return;
    if (_inputDelegate) {
        // Unsubscribe request from current delegate
        _inputDelegate = nil;
        
        [self subscribeInput:NO];
    }
    if (newDelegate) {
        // Subscribe request from new delegate
        _inputDelegate = newDelegate;
        
        [self subscribeInput:YES];
    }
}

// public DLABStatusChangeDelegate
- (void) setStatusDelegate:(id<DLABStatusChangeDelegate>)newDelegate
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

// public DLABPrefsChangeDelegate
- (void) setPrefsDelegate:(id<DLABPrefsChangeDelegate>)newDelegate
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

// public DLABProfileChangeDelegate
- (void) setProfileDelegate:(id<DLABProfileChangeDelegate>)newDelegate
{
    if (_profileDelegate == newDelegate) return;
    if (_profileDelegate) {
        // Unsubscribe request from current delegate
        _profileDelegate = nil;
        
        [self subscribeProfileChange:NO];
    }
    if (newDelegate) {
        // Subscribe request from new delegate
        _profileDelegate = newDelegate;
        
        [self subscribeProfileChange:YES];
    }
}

/* =================================================================================== */
// MARK: - (Private) - property getter - lazy instantiation
/* =================================================================================== */

- (DLABInputCallback *)inputCallback
{
    if (!_inputCallback) {
        _inputCallback = new DLABInputCallback((id)self);
    }
    return _inputCallback;
}

- (DLABOutputCallback *)outputCallback
{
    if (!_outputCallback) {
        _outputCallback = new DLABOutputCallback((id)self);
    }
    return _outputCallback;
}

- (DLABNotificationCallback*)statusChangeCallback
{
    if (!_statusChangeCallback) {
        _statusChangeCallback = new DLABNotificationCallback((id)self);
    }
    return _statusChangeCallback;
}

- (DLABNotificationCallback*)prefsChangeCallback
{
    if (!_prefsChangeCallback) {
        _prefsChangeCallback = new DLABNotificationCallback((id)self);
    }
    return _prefsChangeCallback;
}

- (DLABProfileCallback*)profileCallback
{
    if (!_profileCallback) {
        _profileCallback = new DLABProfileCallback((id)self);
    }
    return _profileCallback;
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

/* =================================================================================== */
// MARK: - (Private) - property setter
/* =================================================================================== */

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
