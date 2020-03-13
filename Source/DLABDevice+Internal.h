//
//  DLABDevice+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDevice.h"

#import "DeckLinkAPI.h"

#import "DeckLinkAPI_v10_11.h"
#import "DeckLinkAPIConfiguration_v10_11.h"
#import "DeckLinkAPIVideoInput_v10_11.h"
#import "DeckLinkAPIVideoOutput_v10_11.h"

#import "DeckLinkAPIVideoInput_v11_4.h"
#import "DeckLinkAPIVideoOutput_v11_4.h"

#import "DLABInputCallback.h"
#import "DLABOutputCallback.h"
#import "DLABAncillaryPacket.h"
#import "DLABNotificationCallback.h"
#import "DLABVideoSetting+Internal.h"
#import "DLABAudioSetting+Internal.h"
#import "DLABTimecodeSetting+Internal.h"

const int maxOutputVideoFrameCount = 8;

/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice () <DLABNotificationCallbackDelegate>
{
    // private queue management
    void* captureQueueKey; // for Decklink-API Call
    void* playbackQueueKey; // for Decklink-API Call
    void* delegateQueueKey; // for delegate call
    
    // OutputVideoFramePool management
    NSMutableSet* outputVideoFrameSet;
    NSMutableSet* outputVideoFrameIdleSet;
}

/**
 Create DLABDevice instance from IDeckLink object.

 @param deckLink IDeckLink object.
 @return Instance of DLABDevice.
 */
- (nullable instancetype) initWithDeckLink:(IDeckLink *)deckLink NS_DESIGNATED_INITIALIZER;

/* =================================================================================== */
// MARK: - (Private) - block helper
/* =================================================================================== */

/**
 Call block in private dispatch queue / sync operation for delegate
 
 @param block block object
 */
- (void) delegate_sync:(dispatch_block_t) block;

/**
 Call block in private dispatch queue / async operation for delegate
 
 @param block block object
 */
- (void) delegate_async:(dispatch_block_t) block;

/**
 Call block in private dispatch queue / sync operation for output
 
 @param block block object
 */
- (void) playback_sync:(dispatch_block_t) block;

/**
 Call block in private dispatch queue / sync operation for input
 
 @param block block object
 */
- (void) capture_sync:(dispatch_block_t) block;

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

/**
 Utility method to fill (NSError * _Nullable * _Nullable)

 @param description string for NSLocalizedDescriptionKey
 @param failureReason string for NSLocalizedFailureReasonErrorKey
 @param result error code
 @param error pointer to (NSError*)
 @return YES if no error, NO if failed
 */
- (BOOL) post:(nullable NSString*)description
       reason:(nullable NSString*)failureReason
         code:(NSInteger)result
           to:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: - (Private/Public) - Subscription Status/Preferences Change
/* =================================================================================== */

// DLABNotificationCallbackDelegate

/**
 Handle IDeckLinkNotificationCallback::Notify

 @param topic BMDNotifications
 @param param1 first parameter in uint64_t
 @param param2 second parameter in uint64_t
 */
- (void) notify:(BMDNotifications)topic param1:(uint64_t)param1 param2:(uint64_t)param2;

// setter/helper methods

/**
 Public setter for statusChange delegate

 @param newDelegate id<DLABStatusChangeDelegate>
 */
- (void) setStatusChangeDelegate:(id<DLABStatusChangeDelegate>)newDelegate;

/**
 Private helper method for statusChange

 @param flag Flag to start/stop subscription
 @return YES if no error, NO if failed
 */
- (BOOL) subscribeStatusChangeNotification:(BOOL) flag;

/**
 Public setter for preferencesChange delegate

 @param newDelegate id<DLABPrefsChangeDelegate>
 */
- (void) setPrefsChangeDelegate:(id<DLABPrefsChangeDelegate>)newDelegate;

/**
 Private helper method for preferencesChange

 @param flag Flag to start/stop subscription
 @return YES if no error, NO if failed
 */
- (BOOL) subscribePrefsChangeNotification:(BOOL) flag;

/* =================================================================================== */
// MARK: - Properties
/* =================================================================================== */

// cpp objects - Ready on init

/**
 IDeckLink object.
 */
@property (nonatomic, assign) IDeckLink* deckLink;

/**
 IDeckLinkAttributes object.
 */
@property (nonatomic, assign) IDeckLinkProfileAttributes *deckLinkProfileAttributes;

/**
 IDeckLinkConfiguration object.
 */
@property (nonatomic, assign) IDeckLinkConfiguration *deckLinkConfiguration;

/**
 IDeckLinkStatus object.
 */
@property (nonatomic, assign) IDeckLinkStatus *deckLinkStatus;

/**
 IDeckLinkNotification object.
 */
@property (nonatomic, assign) IDeckLinkNotification *deckLinkNotification;

/**
 IDeckLinkHDMIInputEDID object.
 */
@property (nonatomic, assign, nullable) IDeckLinkHDMIInputEDID *deckLinkHDMIInputEDID;

/**
 IDeckLinkInput object for input.
 */
@property (nonatomic, assign, nullable) IDeckLinkInput *deckLinkInput;

/**
 IDeckLinkOutput object for output.
 */
@property (nonatomic, assign, nullable) IDeckLinkOutput* deckLinkOutput;

/**
 IDeckLinkKeyer object for keying.
 */
@property (nonatomic, assign, nullable) IDeckLinkKeyer *deckLinkKeyer;

/**
 IDeckLinkProfileManager object.
 */
@property (nonatomic, assign, nullable) IDeckLinkProfileManager *deckLinkProfileManager;

// lazy instantiation

/**
 DLABInputCallback object for input.
 */
@property (nonatomic, assign, nullable) DLABInputCallback *inputCallback;

/**
 DLABOutputCallback object for output.
 */
@property (nonatomic, assign, nullable) DLABOutputCallback *outputCallback;

/**
 DLABNotificationCallback object for statusChange.
 */
@property (nonatomic, assign, nullable) DLABNotificationCallback *statusChangeCallback;

/**
 DLABNotificationCallback object for preferenceChange.
 */
@property (nonatomic, assign, nullable) DLABNotificationCallback *prefsChangeCallback;

// Ready after setting preview

/**
 IDeckLinkScreenPreviewCallback object for output.
 */
@property (nonatomic, assign, nullable) IDeckLinkScreenPreviewCallback* outputPreviewCallback;

/**
 IDeckLinkScreenPreviewCallback object for input.
 */
@property (nonatomic, assign, nullable) IDeckLinkScreenPreviewCallback* inputPreviewCallback;

// dispatch_queue_t - lazy instantiation

/**
 private dispatch queue for input processing.
 */
@property (nonatomic, strong) dispatch_queue_t captureQueue;

/**
 private dispatch queue for output processing.
 */
@property (nonatomic, strong) dispatch_queue_t playbackQueue;

/**
 private dispatch queue for delegate call.
 */
@property (nonatomic, strong) dispatch_queue_t delegateQueue;

/* =================================================================================== */
// MARK: - (Private) - Paired with public readonly
/* =================================================================================== */

// private - Ready on init

/**
 Device's DLABAttributeModelName value.
 */
@property (nonatomic, copy) NSString *modelNameW;

/**
 Device's DLABAttributeDisplayName value.
 */
@property (nonatomic, copy) NSString *displayNameW;

/**
 Device's DLABAttributePersistentID value.
 */
@property (nonatomic, assign) int64_t persistentIDW;

/**
 Device's DLABAttributeDeviceGroupID value.
 */
@property (nonatomic, assign) int64_t deviceGroupIDW;

/**
 Device's DLABAttributeTopologicalID value.
 */
@property (nonatomic, assign) int64_t topologicalIDW;

/**
 Device's DLABAttributeNumberOfSubDevices value.
 */
@property (nonatomic, assign) int64_t numberOfSubDevicesW;

/**
 Device's DLABAttributeSubDeviceIndex value.
 */
@property (nonatomic, assign) int64_t subDeviceIndexW;

/**
 Device's DLABAttributeProfileID value.
 */
@property (nonatomic, assign) int64_t profileIDW;

/**
 Device's DLABAttributeDuplex value.
 */
@property (nonatomic, assign) int64_t duplexW;

/**
 Detail bitmask of DLABVideoIOSupport. You can examine what kind of keying feature is supported.
 */
@property (nonatomic, assign) DLABVideoIOSupport supportFlagW; // uint32_t

/**
 Convenience flag if the device supports capture (input stream).
 */
@property (nonatomic, assign) BOOL supportCaptureW;

/**
 Convenience flag if the device supports playback (output stream).
 */
@property (nonatomic, assign) BOOL supportPlaybackW;

/**
 Convenience flag if the device supports keying (output stream).
 */
@property (nonatomic, assign) BOOL supportKeyingW;

/**
 Convenience flag if the device supports format change detection (input stream).
 */
@property (nonatomic, assign) BOOL supportInputFormatDetectionW;

// lazy instantiation

/**
 Device supported output VideoSetting templates. For reference only.
 */
@property (nonatomic, copy, nullable) NSArray *outputVideoSettingArrayW;

/**
 Device supported input VideoSetting templates. For reference only.
 */
@property (nonatomic, copy, nullable) NSArray *inputVideoSettingArrayW;

// Ready while video enabled

/**
 Currently available output VideoSetting. Ready while enabled.
 */
@property (nonatomic, strong, nullable) DLABVideoSetting* outputVideoSettingW;

/**
 Currently available input VideoSetting. Ready while enabled.
 */
@property (nonatomic, strong, nullable) DLABVideoSetting* inputVideoSettingW;

// Ready while audio enabled

/**
 Currently available output AudioSetting. Ready while enabled.
 */
@property (nonatomic, strong, nullable) DLABAudioSetting* outputAudioSettingW;

/**
 Currently available input AudioSetting. Ready while enabled.
 */
@property (nonatomic, strong, nullable) DLABAudioSetting* inputAudioSettingW;

/* =================================================================================== */
// MARK: - Properties
/* =================================================================================== */

// Initial videoFrame forces update.

/**
 Request input Video Re-configuration
 */
@property (nonatomic, assign) BOOL needsInputVideoConfigurationRefresh;

// CFObjects // lazy instantiation

/**
 CVPixelBufferPoolRef for input PixelBuffer
 */
@property (nonatomic, assign, nullable) CVPixelBufferPoolRef inputPixelBufferPool;

/**
 BLACKMAGIC_DECKLINK_API_VERSION from current runtime
 */
@property (nonatomic, assign) int apiVersion;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: - output (internal)
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice (OutputInternal) <DLABOutputCallbackDelegate>

/* =================================================================================== */
// MARK: DLABOutputCallbackDelegate
/* =================================================================================== */

/**
 Handle IDeckLinkVideoOutputCallback::ScheduledFrameCompleted

 @param frame IDeckLinkVideoFrame
 @param result BMDOutputFrameCompletionResult
 */
- (void) scheduledFrameCompleted:(IDeckLinkVideoFrame *)frame
                          result:(BMDOutputFrameCompletionResult)result;

/**
 Handle IDeckLinkAudioOutputCallback::RenderAudioSamples

 @param preroll preroll or not
 */
- (void) renderAudioSamplesPreroll:(BOOL)preroll;

/**
 Handle IDeckLinkVideoOutputCallback::ScheduledPlaybackHasStopped
 */
- (void) scheduledPlaybackHasStopped;

/* =================================================================================== */
// MARK: private method
/* =================================================================================== */

/**
 Check output VideoFrame pool and expand if required.

 @return YES if no error, NO if failed
 */
- (BOOL) prepareOutputVideoFramePool;

/**
 Clean up all output VideoFrame in pool
 */
- (void) freeOutputVideoFramePool;

/**
 Reserve output VideoFrame and take it out from output VideoFrame pool

 @return IDeckLinkMutableVideoFrame or null if failed.
 */
- (nullable IDeckLinkMutableVideoFrame*) reserveOutputVideoFrame;

/**
 Release output VideoFrame and return it to output VideoFrame pool

 @param outFrame IDeckLinkMutableVideoFrame
 @return YES if no error, NO if failed
 */
- (BOOL) releaseOutputVideoFrame:(IDeckLinkMutableVideoFrame*)outFrame;

/**
 Prepare output VideoFrame from PixelBuffer

 @param pb CVPixelBufferRef
 @return IDeckLinkMutableVideoFrame or null if failed.
 */
- (nullable IDeckLinkMutableVideoFrame*) outputVideoFrameWithPixelBuffer:(CVPixelBufferRef)pb;

/**
 Validate timecode combination for current output VideoSetting

 @param format DLABTimecodeFormat
 @param outputVideoSetting DLABVideoSetting
 @return YES if valid combination, No if invalid combination
 */
- (BOOL) validateTimecodeFormat:(DLABTimecodeFormat)format
                   videoSetting:(DLABVideoSetting*)outputVideoSetting;

/* =================================================================================== */
// MARK: private experimental - VANC support
/* =================================================================================== */

/**
 Wrapper of IDeckLinkVideoFrameAncillary::GetBufferForVerticalBlankingLine.

 @param outFrame IDeckLinkMutableVideoFrame
 @param lineNumber VANC line number of interrest.
 @return row buffer pointer, or null if not available.
 */
- (nullable void*) getVancBufferOfOutputFrame:(IDeckLinkMutableVideoFrame*)outFrame
                                         line:(uint32_t)lineNumber;

/**
 Call VANCHandler for output VideoFrame

 @param outFrame IDeckLinkMutableVideoFrame
 @param displayTime time at which to display the frame in timeScale units
 @param frameDuration duration for which to display the frame in timeScale units
 @param timeScale time scale for displayTime and displayDuration
 */
- (void) callbackOutputVANCHandler:(IDeckLinkMutableVideoFrame*)outFrame
                            atTime:(NSInteger)displayTime
                          duration:(NSInteger)frameDuration
                       inTimeScale:(NSInteger)timeScale;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: - input (internal)
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice (InputInternal) <DLABInputCallbackDelegate>

/* =================================================================================== */
// MARK: DLABInputCallbackDelegate
/* =================================================================================== */

/**
 Handle BMDVideoInputFormatChangedEvents

 @param events BMDVideoInputFormatChangedEvents
 @param displayMode IDeckLinkDisplayMode object
 @param flags BMDDetectedVideoInputFormatFlags
 */
- (void) didChangeVideoInputFormat:(BMDVideoInputFormatChangedEvents)events
                       displayMode:(IDeckLinkDisplayMode*)displayMode
                             flags:(BMDDetectedVideoInputFormatFlags)flags;

/**
 Handle captured videoFrame/audioPacket

 @param videoFrame IDeckLinkVideoInputFrame
 @param audioPacket IDeckLinkAudioInputPacket
 */
- (void) didReceiveVideoInputFrame:(nullable IDeckLinkVideoInputFrame*)videoFrame
                  audioInputPacket:(nullable IDeckLinkAudioInputPacket*)audioPacket;

/* =================================================================================== */
// MARK: private method
/* =================================================================================== */

/**
 Prepare TimecodeSetting for VideoFrame in specified format if available.

 @param videoFrame IDeckLinkVideoInputFrame
 @param format BMDTimecodeFormat
 @return DLABTimecodeSetting for videoFrame or null if failed.
 */
- (nullable DLABTimecodeSetting*) createTimecodeSettingOf:(IDeckLinkVideoInputFrame*)videoFrame
                                                   format:(BMDTimecodeFormat)format;

/**
 Utility method to create DLABTimecodeSetting from videoFrame.
 
 If videoFrame contains timecode, either RP188 or VITC family will be returned.

 @param videoFrame IDeckLinkVideoInputFrame
 @return DLABTimecodeSetting for videoFrame or null if failed.
 */
- (nullable DLABTimecodeSetting*) createTimecodeSettingOf:(IDeckLinkVideoInputFrame*)videoFrame;

/**
 Prepare PixelBuffer for VideoFrame. Different stride is supported.

 @param videoFrame IDeckLinkVideoInputFrame
 @return CVPixelBufferRef for videoFrame or null if failed.
 */
- (nullable CVPixelBufferRef) createPixelBufferForVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame;

/**
 Utility method to convert videoFrame into CMSampleBufferRef.

 @param videoFrame IDeckLinkVideoInputFrame
 @return CMSampleBufferRef for videoFrame or null if failed.
 */
- (nullable CMSampleBufferRef) createVideoSampleForVideoFrame:(IDeckLinkVideoInputFrame*)videoFrame;

/**
 Utility method to convert audioPacket into CMSampleBufferRef.

 @param audioPacket IDeckLinkAudioInputPacket
 @return CMSampleBuffer for audioPacket or null if failed.
 */
- (nullable CMSampleBufferRef) createAudioSampleForAudioPacket:(IDeckLinkAudioInputPacket*)audioPacket;

/* =================================================================================== */
// MARK: private experimental - VANC support
/* =================================================================================== */

/**
 Wrapper of IDeckLinkVideoFrameAncillary::GetBufferForVerticalBlankingLine.

 @param inFrame IDeckLinkVideoInputFrame
 @param lineNumber VANC line number of interrest.
 @return row buffer pointer, or null if not available.
 */
- (nullable void*) getVancBufferOfInputFrame:(IDeckLinkVideoInputFrame*)inFrame
                                        line:(uint32_t)lineNumber;

/**
 Call VANCHandler block for input VideoFrame.

 @param inFrame IDeckLinkVideoInputFrame
 */
- (void) callbackInputVANCHandler:(IDeckLinkVideoInputFrame*)inFrame;

@end

NS_ASSUME_NONNULL_END
