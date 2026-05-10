//
//  DLABDevice.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDevice+Internal.h>
#import <DLABBridgingSupport.h>
#import <DLABQueryInterfaceAny.h>
#import <DLABVersionChecker.h>

#if DEBUG
#define DLABShutdownCallbackAssert(condition, message) NSCAssert((condition), (message))
#else
#define DLABShutdownCallbackAssert(condition, message) do { (void)(condition); } while (0)
#endif

NS_INLINE void DLABAssertOrphanedCallback(BOOL released,
                                          NSString * _Nonnull callbackName,
                                          NSString * _Nonnull operationName)
{
    DLABShutdownCallbackAssert(released,
                               ([NSString stringWithFormat:@"%@ failed during shutdown; retaining %@ to avoid releasing a callback still owned by DeckLink.",
                                 operationName,
                                 callbackName]));
}

const char* kCaptureQueue = "DLABDevice.captureQueue";
const char* kPlaybackQueue = "DLABDevice.playbackQueue";
const char* kDelegateQueue = "DLABDevice.delegateQueue";

@implementation DLABDevice

- (instancetype) init
{
    DLABRaiseUnavailableInit(self, @selector(initWithDeckLink:));
    return nil;
}

- (instancetype) initWithDeckLink:(IDeckLink *)newDeckLink
{
    NSParameterAssert(newDeckLink);
    
    if (self = [super init]) {
        // validate property support (attributes/configuration/status/notification)
        IDeckLinkProfileAttributes* profileAttributes = NULL;
        IDeckLinkConfiguration* configuration = NULL;
        IDeckLinkStatus* status = NULL;
        IDeckLinkNotification* notification = NULL;
        
        HRESULT err1 = DLABQueryInterfaceAny(newDeckLink, &profileAttributes,
                                             IID_IDeckLinkProfileAttributes,
                                             IID_IDeckLinkProfileAttributes_v15_3_1);
        HRESULT err2 = DLABQueryInterfaceAny(newDeckLink, &configuration,
                                             IID_IDeckLinkConfiguration,
                                             IID_IDeckLinkConfiguration_v15_3_1);
        HRESULT err3 = DLABQueryInterfaceAny(newDeckLink, &status,
                                             IID_IDeckLinkStatus,
                                             IID_IDeckLinkStatus_v15_3_1);
        HRESULT err4 = DLABQueryInterfaceAny(newDeckLink, &notification,
                                             IID_IDeckLinkNotification,
                                             IID_IDeckLinkNotification_v15_3_1);
        
        if (FAILED(err1) || FAILED(err2) || FAILED(err3) || FAILED(err4)) {
            if (profileAttributes) profileAttributes->Release();
            if (configuration) configuration->Release();
            if (status) status->Release();
            if (notification) notification->Release();
            return nil;
        }
        
        _deckLinkProfileAttributes = profileAttributes;
        _deckLinkConfiguration = configuration;
        _deckLinkStatus = status;
        _deckLinkNotification = notification;
        
        // Retain IDeckLink and each Interfaces
        _deckLink = newDeckLink;
        _deckLink->AddRef();
        
        //
        _outputVideoFramePool = [[DLABVideoFramePool alloc] init];
        
        // Eagerly initialize dispatch queues and callback objects to avoid
        // lazy-initialization races on concurrent first access.
        _captureQueue = dispatch_queue_create(kCaptureQueue, DISPATCH_QUEUE_SERIAL);
        captureQueueKey = &captureQueueKey;
        dispatch_queue_set_specific(_captureQueue, captureQueueKey, (__bridge void*)self, NULL);
        
        _playbackQueue = dispatch_queue_create(kPlaybackQueue, DISPATCH_QUEUE_SERIAL);
        playbackQueueKey = &playbackQueueKey;
        dispatch_queue_set_specific(_playbackQueue, playbackQueueKey, (__bridge void*)self, NULL);
        
        _delegateQueue = dispatch_queue_create(kDelegateQueue, DISPATCH_QUEUE_SERIAL);
        delegateQueueKey = &delegateQueueKey;
        dispatch_queue_set_specific(_delegateQueue, delegateQueueKey, (__bridge void*)self, NULL);
        
        _inputCallback = new DLABInputCallback((id)self);
        _outputCallback = new DLABOutputCallback((id)self);
        _statusChangeCallback = new DLABNotificationCallback((id)self);
        _prefsChangeCallback = new DLABNotificationCallback((id)self);
        _profileCallback = new DLABProfileCallback((id)self);
        
        //
        [self validate];
    }
    return self;
}

- (void) validate
{
    BOOL supportsCapture = FALSE;
    BOOL supportsPlayback = FALSE;
    
    [self validateVideoIOSupport:&supportsCapture playback:&supportsPlayback];
    [self validateOptionalInterfacesForCaptureSupport:&supportsCapture playbackSupport:&supportsPlayback];
    [self updateSupportFlagsFromCaptureSupport:supportsCapture playbackSupport:supportsPlayback];
    [self loadStaticDeviceAttributes];
}

- (void) validateVideoIOSupport:(BOOL *)supportsCapture
                       playback:(BOOL *)supportsPlayback
{
    int64_t support = 0;
    HRESULT error = _deckLinkProfileAttributes->GetInt(BMDDeckLinkVideoIOSupport, &support);
    *supportsCapture = FALSE;
    *supportsPlayback = FALSE;
    if (!error) {
        *supportsCapture = (support & bmdDeviceSupportsCapture);
        *supportsPlayback = (support & bmdDeviceSupportsPlayback);
    }
}

- (void) validateOptionalInterfacesForCaptureSupport:(BOOL *)supportsCapture
                                     playbackSupport:(BOOL *)supportsPlayback
{
    HRESULT error = E_FAIL;
    
    if (!_deckLinkInput && *supportsCapture) {
        error = DLABQueryInterfaceAny(_deckLink, &_deckLinkInput,
                                      IID_IDeckLinkInput,
                                      IID_IDeckLinkInput_v15_3_1,
                                      IID_IDeckLinkInput_v14_2_1,
                                      IID_IDeckLinkInput_v11_5_1,
                                      IID_IDeckLinkInput_v11_4);
        if (error) {
            if (_deckLinkInput) _deckLinkInput->Release();
            _deckLinkInput = NULL;
            *supportsCapture = FALSE;
        }
    }
    
    if (!_deckLinkOutput && *supportsPlayback) {
        error = DLABQueryInterfaceAny(_deckLink, &_deckLinkOutput,
                                      IID_IDeckLinkOutput,
                                      IID_IDeckLinkOutput_v15_3_1,
                                      IID_IDeckLinkOutput_v14_2_1,
                                      IID_IDeckLinkOutput_v11_4);
        if (error) {
            if (_deckLinkOutput) _deckLinkOutput->Release();
            _deckLinkOutput = NULL;
            *supportsPlayback = FALSE;
        }
    }
    
    if (!_deckLinkHDMIInputEDID && *supportsCapture) {
        error = _deckLink->QueryInterface(IID_IDeckLinkHDMIInputEDID, (void **)&_deckLinkHDMIInputEDID);
        if (error) {
            if (_deckLinkHDMIInputEDID) _deckLinkHDMIInputEDID->Release();
            _deckLinkHDMIInputEDID = NULL;
        }
    }
    
    if (!_deckLinkKeyer && *supportsPlayback) {
        error = _deckLink->QueryInterface(IID_IDeckLinkKeyer, (void **)&_deckLinkKeyer);
        if (error) {
            if (_deckLinkKeyer) _deckLinkKeyer->Release();
            _deckLinkKeyer = NULL;
        }
    }
    
    if (!_deckLinkProfileManager) {
        error = _deckLink->QueryInterface(IID_IDeckLinkProfileManager, (void **)&_deckLinkProfileManager);
        if (error) {
            if (_deckLinkProfileManager) _deckLinkProfileManager->Release();
            _deckLinkProfileManager = NULL;
        }
    }
    
    if (!_deckLinkStatistics) {
        error = _deckLink->QueryInterface(IID_IDeckLinkStatistics, (void **)&_deckLinkStatistics);
        if (error) {
            if (_deckLinkStatistics) _deckLinkStatistics->Release();
            _deckLinkStatistics = NULL;
        }
    }
}

- (void) updateSupportFlagsFromCaptureSupport:(BOOL)supportsCapture
                              playbackSupport:(BOOL)supportsPlayback
{
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
        HRESULT error = E_FAIL;
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
}

- (void) loadStaticDeviceAttributes
{
    HRESULT error = E_FAIL;
    
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
    // Stop streams during shutdown to prevent resource leaks
    // Stop output streams if running
    if (_deckLinkOutput) {
        NSNumber* isRunning = [self isScheduledPlaybackRunningWithError:nil];
        if (isRunning && [isRunning boolValue]) {
            [self stopScheduledPlaybackWithError:nil];
        }
    }
    
    // Stop input streams if running
    if (_deckLinkInput) {
        // Always attempt to stop input streams (no easy way to check if running)
        [self stopStreamsWithError:nil];
    }
    
    // Release OutputVideoFramePool
    [_outputVideoFramePool freeFrames];
    
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
        BOOL canReleaseProfileCallback = YES;
        if (_profileCallbackRegistered) {
            canReleaseProfileCallback = [self subscribeProfileChange:NO];
        }
        DLABAssertOrphanedCallback(canReleaseProfileCallback,
                                   @"_profileCallback",
                                   @"IDeckLinkProfileManager::SetCallback(NULL)");
        if (canReleaseProfileCallback) {
            _profileCallback->Release();
            _profileCallback = NULL;
        }
    }
    if (_prefsChangeCallback) {
        BOOL canReleasePrefsCallback = YES;
        if (_prefsChangeNotificationSubscribed) {
            canReleasePrefsCallback = [self subscribePrefsChangeNotification:NO];
        }
        DLABAssertOrphanedCallback(canReleasePrefsCallback,
                                   @"_prefsChangeCallback",
                                   @"IDeckLinkNotification::Unsubscribe(bmdPreferencesChanged)");
        if (canReleasePrefsCallback) {
            _prefsChangeCallback->Release();
            _prefsChangeCallback = NULL;
        }
    }
    if (_statusChangeCallback) {
        BOOL canReleaseStatusCallback = YES;
        if (_statusChangeNotificationSubscribed) {
            canReleaseStatusCallback = [self subscribeStatusChangeNotification:NO];
        }
        DLABAssertOrphanedCallback(canReleaseStatusCallback,
                                   @"_statusChangeCallback",
                                   @"IDeckLinkNotification::Unsubscribe(bmdStatusChanged)");
        if (canReleaseStatusCallback) {
            _statusChangeCallback->Release();
            _statusChangeCallback = NULL;
        }
    }
    if (_outputCallback) {
        BOOL canReleaseOutputCallback = YES;
        if (_outputCallbackRegistered) {
            canReleaseOutputCallback = [self subscribeOutput:NO];
        }
        DLABAssertOrphanedCallback(canReleaseOutputCallback,
                                   @"_outputCallback",
                                   @"IDeckLinkOutput::SetScheduledFrameCompletionCallback(NULL)");
        if (canReleaseOutputCallback) {
            _outputCallback->Release();
            _outputCallback = NULL;
        }
    }
    if (_inputCallback) {
        BOOL canReleaseInputCallback = YES;
        if (_inputCallbackRegistered) {
            canReleaseInputCallback = [self subscribeInput:NO];
        }
        DLABAssertOrphanedCallback(canReleaseInputCallback,
                                   @"_inputCallback",
                                   @"IDeckLinkInput::SetCallback(NULL)");
        if (canReleaseInputCallback) {
            _inputCallback->Release();
            _inputCallback = NULL;
        }
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
    if (_deckLinkStatistics) {
        _deckLinkStatistics->Release();
        _deckLinkStatistics = NULL;
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
@synthesize inputAncillaryPacketHandler = _inputAncillaryPacketHandler; // (SDK 15.3 or later)
@synthesize outputAncillaryPacketHandler = _outputAncillaryPacketHandler; // (SDK 15.3 or later)

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
@synthesize deckLinkStatistics = _deckLinkStatistics;

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
@synthesize outputVideoFramePool = _outputVideoFramePool;

@synthesize inputPixelBufferPool = _inputPixelBufferPool;
@synthesize outputPreviewCallback = _outputPreviewCallback;
@synthesize inputPreviewCallback = _inputPreviewCallback;

@synthesize needsInputVideoConfigurationRefresh = _needsInputVideoConfigurationRefresh;
@synthesize statusChangeNotificationSubscribed = _statusChangeNotificationSubscribed;
@synthesize prefsChangeNotificationSubscribed = _prefsChangeNotificationSubscribed;
@synthesize inputCallbackRegistered = _inputCallbackRegistered;
@synthesize outputCallbackRegistered = _outputCallbackRegistered;
@synthesize profileCallbackRegistered = _profileCallbackRegistered;
@synthesize inputVideoConverter = _inputVideoConverter;
@synthesize outputVideoConverter = _outputVideoConverter;

/* =================================================================================== */
// MARK: - (Private) - block helper
/* =================================================================================== */

- (void) delegate_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.delegateQueue;
    DLABDispatchSyncIfNeeded(queue, delegateQueueKey, block);
}

- (void) delegate_async:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.delegateQueue;
    DLABDispatchAsyncIfNeeded(queue, delegateQueueKey, block);
}

- (void) playback_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.playbackQueue;
    DLABDispatchSyncIfNeeded(queue, playbackQueueKey, block);
}

- (void) capture_sync:(dispatch_block_t) block
{
    dispatch_queue_t queue = self.captureQueue;
    DLABDispatchSyncIfNeeded(queue, captureQueueKey, block);
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
// MARK: - (Private) - validation helpers
/* =================================================================================== */

- (BOOL) validateProfileAttributesInterfaceWithError:(NSError**)error
                                        functionName:(const char*)functionName
                                          lineNumber:(int)lineNumber
{
    if (!_deckLinkProfileAttributes) {
        [self post:[NSString stringWithFormat:@"%s (%d)", functionName, lineNumber]
            reason:@"IDeckLinkProfileAttributes interface not available."
              code:E_FAIL
                to:error];
        return NO;
    }
    return YES;
}

- (BOOL) validateConfigurationInterfaceWithError:(NSError**)error
                                    functionName:(const char*)functionName
                                      lineNumber:(int)lineNumber
{
    if (!_deckLinkConfiguration) {
        [self post:[NSString stringWithFormat:@"%s (%d)", functionName, lineNumber]
            reason:@"IDeckLinkConfiguration interface not available."
              code:E_FAIL
                to:error];
        return NO;
    }
    return YES;
}

- (BOOL) validateStatisticsInterfaceWithError:(NSError**)error
                                 functionName:(const char*)functionName
                                   lineNumber:(int)lineNumber
{
    if (!_deckLinkStatistics) {
        [self post:[NSString stringWithFormat:@"%s (%d)", functionName, lineNumber]
            reason:@"IDeckLinkStatistics interface not available."
              code:E_FAIL
                to:error];
        return NO;
    }
    return YES;
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
        // TODO: Add param2 handling for DLABNotificationIPFlowStatusChanged/DLABNotificationIPFlowSettingChanged
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
        } else {
            self.inputCallbackRegistered = YES;
        }
    } else {
        result = input->SetCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkInput::SetCallback failed.");
        } else {
            self.inputCallbackRegistered = NO;
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
        } else {
            self.outputCallbackRegistered = YES;
        }
    } else {
        result = output->SetScheduledFrameCompletionCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkOutput::SetScheduledFrameCompletionCallback failed.");
        } else {
            self.outputCallbackRegistered = NO;
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
        } else {
            self.statusChangeNotificationSubscribed = YES;
        }
    } else {
        result = notification->Unsubscribe(bmdStatusChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
        } else {
            self.statusChangeNotificationSubscribed = NO;
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
        } else {
            self.prefsChangeNotificationSubscribed = YES;
        }
    } else {
        result = notification->Unsubscribe(bmdPreferencesChanged, callback);
        if (result) {
            NSLog(@"ERROR: IDeckLinkNotification::Unsubscribe failed.");
        } else {
            self.prefsChangeNotificationSubscribed = NO;
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
        } else {
            self.profileCallbackRegistered = YES;
        }
    } else {
        result = manager->SetCallback(NULL);
        if (result) {
            NSLog(@"ERROR: IDeckLinkProfileManager::SetCallback failed.");
        } else {
            self.profileCallbackRegistered = NO;
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

- (void) updateSubscriptionFrom:(id)oldValue
                             to:(id)newValue
                          block:(BOOL(^)(BOOL))subscribeBlock
{
    if (oldValue) {
        subscribeBlock(NO);
    }
    if (newValue) {
        subscribeBlock(YES);
    }
}

- (void) setOutputDelegate:(id<DLABOutputPlaybackDelegate>)newDelegate
{
    if (_outputDelegate == newDelegate) return;
    id old = _outputDelegate;
    _outputDelegate = nil;
    if (newDelegate) {
        _outputDelegate = newDelegate;
    }
    [self updateSubscriptionFrom:old
                              to:newDelegate
                           block:^BOOL(BOOL flag) { return [self subscribeOutput:flag]; }];
}

- (void) setInputDelegate:(id<DLABInputCaptureDelegate>)newDelegate
{
    if (_inputDelegate == newDelegate) return;
    id old = _inputDelegate;
    _inputDelegate = nil;
    if (newDelegate) {
        _inputDelegate = newDelegate;
    }
    [self updateSubscriptionFrom:old
                              to:newDelegate
                           block:^BOOL(BOOL flag) { return [self subscribeInput:flag]; }];
}

// public DLABStatusChangeDelegate
- (void) setStatusDelegate:(id<DLABStatusChangeDelegate>)newDelegate
{
    if (_statusDelegate == newDelegate) return;
    id old = _statusDelegate;
    _statusDelegate = nil;
    if (newDelegate) {
        _statusDelegate = newDelegate;
    }
    [self updateSubscriptionFrom:old
                              to:newDelegate
                           block:^BOOL(BOOL flag) { return [self subscribeStatusChangeNotification:flag]; }];
}

// public DLABPrefsChangeDelegate
- (void) setPrefsDelegate:(id<DLABPrefsChangeDelegate>)newDelegate
{
    if (_prefsDelegate == newDelegate) return;
    id old = _prefsDelegate;
    _prefsDelegate = nil;
    if (newDelegate) {
        _prefsDelegate = newDelegate;
    }
    [self updateSubscriptionFrom:old
                              to:newDelegate
                           block:^BOOL(BOOL flag) { return [self subscribePrefsChangeNotification:flag]; }];
}

// public DLABProfileChangeDelegate
- (void) setProfileDelegate:(id<DLABProfileChangeDelegate>)newDelegate
{
    if (_profileDelegate == newDelegate) return;
    id old = _profileDelegate;
    _profileDelegate = nil;
    if (newDelegate) {
        _profileDelegate = newDelegate;
    }
    [self updateSubscriptionFrom:old
                              to:newDelegate
                           block:^BOOL(BOOL flag) { return [self subscribeProfileChange:flag]; }];
}

/* =================================================================================== */
// MARK: - (Private) - property getter - lazy instantiation
/* =================================================================================== */

- (DLABInputCallback *)inputCallback
{
    return _inputCallback;
}

- (DLABOutputCallback *)outputCallback
{
    return _outputCallback;
}

- (DLABNotificationCallback*)statusChangeCallback
{
    return _statusChangeCallback;
}

- (DLABNotificationCallback*)prefsChangeCallback
{
    return _prefsChangeCallback;
}

- (DLABProfileCallback*)profileCallback
{
    return _profileCallback;
}

- (dispatch_queue_t) captureQueue
{
    return _captureQueue;
}

- (dispatch_queue_t) playbackQueue
{
    return _playbackQueue;
}

- (dispatch_queue_t) delegateQueue
{
    return _delegateQueue;
}

- (int) apiVersion
{
    return [DLABVersionChecker apiVersion];
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
    if (![self validateProfileAttributesInterfaceWithError:error
                                              functionName:__PRETTY_FUNCTION__
                                                lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetFlagValue(_deckLinkProfileAttributes,
                            (BMDDeckLinkAttributeID)attributeID,
                            error,
                            __PRETTY_FUNCTION__,
                            __LINE__,
                            @"IDeckLinkAttributes::GetFlag failed.");
}

- (NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                             error:(NSError**)error
{
    if (![self validateProfileAttributesInterfaceWithError:error
                                              functionName:__PRETTY_FUNCTION__
                                                lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetIntValue(_deckLinkProfileAttributes,
                           (BMDDeckLinkAttributeID)attributeID,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkAttributes::GetInt failed.");
}

- (NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    if (![self validateProfileAttributesInterfaceWithError:error
                                              functionName:__PRETTY_FUNCTION__
                                                lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetFloatValue(_deckLinkProfileAttributes,
                             (BMDDeckLinkAttributeID)attributeID,
                             error,
                             __PRETTY_FUNCTION__,
                             __LINE__,
                             @"IDeckLinkAttributes::GetFloat failed.");
}

- (NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    if (![self validateProfileAttributesInterfaceWithError:error
                                              functionName:__PRETTY_FUNCTION__
                                                lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetStringValue(_deckLinkProfileAttributes,
                              (BMDDeckLinkAttributeID)attributeID,
                              error,
                              __PRETTY_FUNCTION__,
                              __LINE__,
                              @"IDeckLinkAttributes::GetString failed.");
}

/* =================================================================================== */
// MARK: - getter configurationID
/* =================================================================================== */

- (NSNumber*) boolValueForConfiguration:(DLABConfiguration)configurationID
                                  error:(NSError**)error
{
    return DLABGetFlagValue(_deckLinkConfiguration,
                            (BMDDeckLinkConfigurationID)configurationID,
                            error,
                            __PRETTY_FUNCTION__,
                            __LINE__,
                            @"IDeckLinkConfiguration::GetFlag failed.");
}

- (NSNumber*) intValueForConfiguration:(DLABConfiguration)configurationID
                                 error:(NSError**)error
{
    return DLABGetIntValue(_deckLinkConfiguration,
                           (BMDDeckLinkConfigurationID)configurationID,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkConfiguration::GetInt failed.");
}

- (NSNumber*) doubleValueForConfiguration:(DLABConfiguration)configurationID
                                    error:(NSError**)error
{
    return DLABGetFloatValue(_deckLinkConfiguration,
                             (BMDDeckLinkConfigurationID)configurationID,
                             error,
                             __PRETTY_FUNCTION__,
                             __LINE__,
                             @"IDeckLinkConfiguration::GetFloat failed.");
}

- (NSString*) stringValueForConfiguration:(DLABConfiguration)configurationID
                                    error:(NSError**)error
{
    return DLABGetStringValue(_deckLinkConfiguration,
                              (BMDDeckLinkConfigurationID)configurationID,
                              error,
                              __PRETTY_FUNCTION__,
                              __LINE__,
                              @"IDeckLinkConfiguration::GetString failed.");
}

- (NSNumber*) boolValueForConfiguration:(DLABConfiguration)configurationID
                              withParam:(NSUInteger)param
                                  error:(NSError**)error
{
    return DLABGetFlagWithParam(_deckLinkConfiguration,
                                (BMDDeckLinkConfigurationID)configurationID,
                                (uint64_t)param,
                                error,
                                __PRETTY_FUNCTION__,
                                __LINE__,
                                @"IDeckLinkConfiguration::GetFlagWithParam failed.");
}

- (NSNumber*) intValueForConfiguration:(DLABConfiguration)configurationID
                             withParam:(NSUInteger)param
                                 error:(NSError**)error
{
    return DLABGetIntWithParam(_deckLinkConfiguration,
                               (BMDDeckLinkConfigurationID)configurationID,
                               (uint64_t)param,
                               error,
                               __PRETTY_FUNCTION__,
                               __LINE__,
                               @"IDeckLinkConfiguration::GetIntWithParam failed.");
}

- (NSNumber*) doubleValueForConfiguration:(DLABConfiguration)configurationID
                                withParam:(NSUInteger)param
                                    error:(NSError**)error
{
    return DLABGetFloatWithParam(_deckLinkConfiguration,
                                 (BMDDeckLinkConfigurationID)configurationID,
                                 (uint64_t)param,
                                 error,
                                 __PRETTY_FUNCTION__,
                                 __LINE__,
                                 @"IDeckLinkConfiguration::GetFloatWithParam failed.");
}

- (NSString*) stringValueForConfiguration:(DLABConfiguration)configurationID
                                withParam:(NSUInteger)param
                                    error:(NSError**)error
{
    return DLABGetStringWithParam(_deckLinkConfiguration,
                                  (BMDDeckLinkConfigurationID)configurationID,
                                  (uint64_t)param,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkConfiguration::GetStringWithParam failed.");
}

/* =================================================================================== */
// MARK: - setter configrationID
/* =================================================================================== */

- (BOOL) setBoolValue:(BOOL)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetFlagValue(_deckLinkConfiguration,
                            (BMDDeckLinkConfigurationID)configurationID,
                            (bool)value,
                            error,
                            __PRETTY_FUNCTION__,
                            __LINE__,
                            @"IDeckLinkConfiguration::SetFlag failed.");
}

- (BOOL) setIntValue:(NSInteger)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetIntValue(_deckLinkConfiguration,
                           (BMDDeckLinkConfigurationID)configurationID,
                           (int64_t)value,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkConfiguration::SetInt failed.");
}

- (BOOL) setDoubleValue:(double_t)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetFloatValue(_deckLinkConfiguration,
                             (BMDDeckLinkConfigurationID)configurationID,
                             (double)value,
                             error,
                             __PRETTY_FUNCTION__,
                             __LINE__,
                             @"IDeckLinkConfiguration::SetFloat failed.");
}

- (BOOL) setStringValue:(NSString*)value forConfiguration:(DLABConfiguration)
configurationID error:(NSError**)error
{
    NSParameterAssert(value != nil);
    
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetStringValue(_deckLinkConfiguration,
                              (BMDDeckLinkConfigurationID)configurationID,
                              value,
                              error,
                              __PRETTY_FUNCTION__,
                              __LINE__,
                              @"IDeckLinkConfiguration::SetString failed.");
}

- (BOOL) setBoolValue:(BOOL)value
     forConfiguration:(DLABConfiguration)configurationID
            withParam:(NSUInteger)param
                error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetFlagWithParam(_deckLinkConfiguration,
                                (BMDDeckLinkConfigurationID)configurationID,
                                (uint64_t)param,
                                (bool)value,
                                error,
                                __PRETTY_FUNCTION__,
                                __LINE__,
                                @"IDeckLinkConfiguration::SetFlagWithParam failed.");
}

- (BOOL) setIntValue:(NSInteger)value
    forConfiguration:(DLABConfiguration)configurationID
           withParam:(NSUInteger)param
               error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetIntWithParam(_deckLinkConfiguration,
                               (BMDDeckLinkConfigurationID)configurationID,
                               (uint64_t)param,
                               (int64_t)value,
                               error,
                               __PRETTY_FUNCTION__,
                               __LINE__,
                               @"IDeckLinkConfiguration::SetIntWithParam failed.");
}

- (BOOL) setDoubleValue:(double_t)value
       forConfiguration:(DLABConfiguration)configurationID
              withParam:(NSUInteger)param
                  error:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetFloatWithParam(_deckLinkConfiguration,
                                 (BMDDeckLinkConfigurationID)configurationID,
                                 (uint64_t)param,
                                 (double)value,
                                 error,
                                 __PRETTY_FUNCTION__,
                                 __LINE__,
                                 @"IDeckLinkConfiguration::SetFloatWithParam failed.");
}

- (BOOL) setStringValue:(NSString*)value
       forConfiguration:(DLABConfiguration)configurationID
              withParam:(NSUInteger)param
                  error:(NSError**)error
{
    NSParameterAssert(value != nil);
    
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
    return DLABSetStringWithParam(_deckLinkConfiguration,
                                  (BMDDeckLinkConfigurationID)configurationID,
                                  (uint64_t)param,
                                  value,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkConfiguration::SetStringWithParam failed.");
}

- (BOOL) writeConfigurationToPreferencesWithError:(NSError**)error
{
    if (![self validateConfigurationInterfaceWithError:error
                                          functionName:__PRETTY_FUNCTION__
                                            lineNumber:__LINE__]) {
        return NO;
    }
    
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
    return DLABGetFlagValue(_deckLinkStatus,
                            (BMDDeckLinkStatusID)statusID,
                            error,
                            __PRETTY_FUNCTION__,
                            __LINE__,
                            @"IDeckLinkStatus::GetFlag failed.");
}

- (NSNumber*) intValueForStatus:(DLABDeckLinkStatus)statusID
                          error:(NSError**)error
{
    return DLABGetIntValue(_deckLinkStatus,
                           (BMDDeckLinkStatusID)statusID,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkStatus::GetInt failed.");
}

- (NSNumber*) doubleValueForStatus:(DLABDeckLinkStatus)statusID
                             error:(NSError**)error
{
    return DLABGetFloatValue(_deckLinkStatus,
                             (BMDDeckLinkStatusID)statusID,
                             error,
                             __PRETTY_FUNCTION__,
                             __LINE__,
                             @"IDeckLinkStatus::GetFloat failed.");
}

- (NSString*) stringValueForStatus:(DLABDeckLinkStatus)statusID
                             error:(NSError**)error
{
    return DLABGetStringValue(_deckLinkStatus,
                              (BMDDeckLinkStatusID)statusID,
                              error,
                              __PRETTY_FUNCTION__,
                              __LINE__,
                              @"IDeckLinkStatus::GetString failed.");
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

- (NSNumber*) boolValueForStatus:(DLABDeckLinkStatus)statusID
                       withParam:(NSUInteger)param
                           error:(NSError**)error
{
    return DLABGetFlagWithParam(_deckLinkStatus,
                                (BMDDeckLinkStatusID)statusID,
                                (uint64_t)param,
                                error,
                                __PRETTY_FUNCTION__,
                                __LINE__,
                                @"IDeckLinkStatus::GetFlagWithParam failed.");
}

- (NSNumber*) intValueForStatus:(DLABDeckLinkStatus)statusID
                      withParam:(NSUInteger)param
                          error:(NSError**)error
{
    return DLABGetIntWithParam(_deckLinkStatus,
                               (BMDDeckLinkStatusID)statusID,
                               (uint64_t)param,
                               error,
                               __PRETTY_FUNCTION__,
                               __LINE__,
                               @"IDeckLinkStatus::GetIntWithParam failed.");
}

- (NSNumber*) doubleValueForStatus:(DLABDeckLinkStatus)statusID
                         withParam:(NSUInteger)param
                             error:(NSError**)error
{
    return DLABGetFloatWithParam(_deckLinkStatus,
                                 (BMDDeckLinkStatusID)statusID,
                                 (uint64_t)param,
                                 error,
                                 __PRETTY_FUNCTION__,
                                 __LINE__,
                                 @"IDeckLinkStatus::GetFloatWithParam failed.");
}

- (NSString*) stringValueForStatus:(DLABDeckLinkStatus)statusID
                         withParam:(NSUInteger)param
                             error:(NSError**)error
{
    return DLABGetStringWithParam(_deckLinkStatus,
                                  (BMDDeckLinkStatusID)statusID,
                                  (uint64_t)param,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkStatus::GetStringWithParam failed.");
}

- (NSMutableData*) dataValueForStatus:(DLABDeckLinkStatus)statusID
                            withParam:(NSUInteger)param
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
    result = _deckLinkStatus->GetBytesWithParam(stat, (uint64_t)param, buffer, &bufferSize);
    if (!result) {
        if (requestSize == 0 && bufferSize > 0) {
            data = [self dataValueForStatus:statusID withParam:param ofSize:(NSUInteger)bufferSize error:error];
        }
        if (data) {
            return data; // immutable deep copy
        } else {
            return nil;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkStatus::GetBytesWithParam failed."
              code:result
                to:error];
        return nil;
    }
}

/* =================================================================================== */
// MARK: - getter statisticID
/* =================================================================================== */

- (NSNumber*) intValueForStatistic:(DLABDeckLinkStatistic)statisticID
                             error:(NSError**)error
{
    if (![self validateStatisticsInterfaceWithError:error
                                       functionName:__PRETTY_FUNCTION__
                                         lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetIntValue(_deckLinkStatistics,
                           (BMDDeckLinkStatisticID)statisticID,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkStatistics::GetInt failed.");
}

- (NSNumber*) intValueForStatistic:(DLABDeckLinkStatistic)statisticID
                         withParam:(NSUInteger)param
                             error:(NSError**)error
{
    if (![self validateStatisticsInterfaceWithError:error
                                       functionName:__PRETTY_FUNCTION__
                                         lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetIntWithParam(_deckLinkStatistics,
                               (BMDDeckLinkStatisticID)statisticID,
                               (uint64_t)param,
                               error,
                               __PRETTY_FUNCTION__,
                               __LINE__,
                               @"IDeckLinkStatistics::GetIntWithParam failed.");
}

- (NSString*) stringValueForStatistic:(DLABDeckLinkStatistic)statisticID
                            withParam:(NSUInteger)param
                                error:(NSError**)error
{
    if (![self validateStatisticsInterfaceWithError:error
                                       functionName:__PRETTY_FUNCTION__
                                         lineNumber:__LINE__]) {
        return nil;
    }
    
    return DLABGetStringWithParam(_deckLinkStatistics,
                                  (BMDDeckLinkStatisticID)statisticID,
                                  (uint64_t)param,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkStatistics::GetStringWithParam failed.");
}

@end
