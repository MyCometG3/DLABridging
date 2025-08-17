//
//  DLABDevice+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDevice.h>
#import <DeckLinkAPI.h>

#import <DeckLinkAPI_v14_2_1.h>
#import <DeckLinkAPIScreenPreviewCallback_v14_2_1.h>
#import <DeckLinkAPIVideoFrame_v14_2_1.h>
#import <DeckLinkAPIVideoInput_v14_2_1.h>
#import <DeckLinkAPIVideoOutput_v14_2_1.h>

#import <DeckLinkAPIVideoInput_v11_5_1.h>

#import <DeckLinkAPIVideoInput_v11_4.h>
#import <DeckLinkAPIVideoOutput_v11_4.h>

#import <DLABInputCallback.h>
#import <DLABOutputCallback.h>
#import <DLABAncillaryPacket.h>
#import <DLABNotificationCallback.h>
#import <DLABVideoSetting+Internal.h>
#import <DLABAudioSetting+Internal.h>
#import <DLABTimecodeSetting+Internal.h>
#import <DLABProfileCallback.h>
#import <DLABProfileAttributes+Internal.h>
#import <DLABFrameMetadata+Internal.h>
#import <DLABVideoConverter.h>
#import <DLABDeckControl+Internal.h>

const int maxOutputVideoFrameCount = 8;

/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice () <DLABNotificationCallbackDelegate>

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
// MARK: - (Private) - Subscription/Callback
/* =================================================================================== */

// DLABNotificationCallbackDelegate

/**
 Handle IDeckLinkNotificationCallback::Notify
 
 @param topic BMDNotifications
 @param param1 first parameter in uint64_t
 @param param2 second parameter in uint64_t
 */
- (void) notify:(BMDNotifications)topic param1:(uint64_t)param1 param2:(uint64_t)param2;

// Support private callbacks (will be forwarded to delegates)

- (BOOL) subscribeInput:(BOOL) flag;
- (BOOL) subscribeOutput:(BOOL) flag;
- (BOOL) subscribeStatusChangeNotification:(BOOL) flag;
- (BOOL) subscribePrefsChangeNotification:(BOOL) flag;
- (BOOL) subscribeProfileChange:(BOOL) flag;

/* =================================================================================== */
// MARK: - (Private) - Paired with public readonly
/* =================================================================================== */

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
// MARK: - (Private) - property
/* =================================================================================== */

// cpp objects - Ready on init

/**
 IDeckLink object.
 */
@property (nonatomic, assign, readonly) IDeckLink* deckLink;

/**
 IDeckLinkAttributes object.
 */
@property (nonatomic, assign, readonly) IDeckLinkProfileAttributes *deckLinkProfileAttributes;

/**
 IDeckLinkConfiguration object.
 */
@property (nonatomic, assign, readonly) IDeckLinkConfiguration *deckLinkConfiguration;

/**
 IDeckLinkStatus object.
 */
@property (nonatomic, assign, readonly) IDeckLinkStatus *deckLinkStatus;

/**
 IDeckLinkNotification object.
 */
@property (nonatomic, assign, readonly) IDeckLinkNotification *deckLinkNotification;

/* =================================================================================== */

/**
 IDeckLinkHDMIInputEDID object.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkHDMIInputEDID *deckLinkHDMIInputEDID;

/**
 IDeckLinkInput object for input.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkInput *deckLinkInput;

/**
 IDeckLinkOutput object for output.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkOutput* deckLinkOutput;

/**
 IDeckLinkKeyer object for keying.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkKeyer *deckLinkKeyer;

/**
 IDeckLinkProfileManager object.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkProfileManager *deckLinkProfileManager;

/* =================================================================================== */

// cpp objects - lazy instantiation

/**
 DLABInputCallback object for input.
 */
@property (nonatomic, assign, readonly, nullable) DLABInputCallback *inputCallback;

/**
 DLABOutputCallback object for output.
 */
@property (nonatomic, assign, readonly, nullable) DLABOutputCallback *outputCallback;

/**
 DLABNotificationCallback object for statusChange.
 */
@property (nonatomic, assign, readonly, nullable) DLABNotificationCallback *statusChangeCallback;

/**
 DLABNotificationCallback object for preferenceChange.
 */
@property (nonatomic, assign, readonly, nullable) DLABNotificationCallback *prefsChangeCallback;

/**
 IDeckLinkProfileCallback object for profile change.
 */
@property (nonatomic, assign, readonly, nullable) DLABProfileCallback* profileCallback;

// dispatch_queue_t - lazy instantiation

/**
 private dispatch queue for input processing.
 */
@property (nonatomic, strong, readonly, nullable) dispatch_queue_t captureQueue;

/**
 private dispatch queue for output processing.
 */
@property (nonatomic, strong, readonly, nullable) dispatch_queue_t playbackQueue;

/**
 private dispatch queue for delegate call.
 */
@property (nonatomic, strong, readonly, nullable) dispatch_queue_t delegateQueue;

//

/**
 BLACKMAGIC_DECKLINK_API_VERSION from current runtime
 */
@property (nonatomic, assign, readonly) int apiVersion;

/* =================================================================================== */

// private queue management

/**
 Queue Key for Decklink-API Call (Capture)
 */
@property (nonatomic, assign, readonly) void* captureQueueKey;

/**
 Queue Key for Decklink-API Call (Playback)
 */
@property (nonatomic, assign, readonly) void* playbackQueueKey;

/**
 Queue Key for delegate-API Call
 */
@property (nonatomic, assign, readonly) void* delegateQueueKey;

// NSMutableSet* - OutputVideoFramePool management

/**
 OutputVideoFramePool management.
 */
@property (nonatomic, strong, readonly) NSMutableSet* outputVideoFrameSet;

/**
 OutputVideoFramePool management.
 */
@property (nonatomic, strong, readonly) NSMutableSet* outputVideoFrameIdleSet;

/* =================================================================================== */

// CFObjects

/**
 CVPixelBufferPoolRef for input PixelBuffer
 */
@property (nonatomic, assign, nullable) CVPixelBufferPoolRef inputPixelBufferPool;

// cpp objects - Ready after setting preview

/**
 IDeckLinkScreenPreviewCallback object for output.
 */
@property (nonatomic, assign, nullable) IDeckLinkScreenPreviewCallback* outputPreviewCallback;

/**
 IDeckLinkScreenPreviewCallback object for input.
 */
@property (nonatomic, assign, nullable) IDeckLinkScreenPreviewCallback* inputPreviewCallback;

/* =================================================================================== */

// Initial videoFrame forces update.

/**
 Request input Video Re-configuration
 */
@property (nonatomic, assign) BOOL needsInputVideoConfigurationRefresh;

//

/**
 DLABVideoConverter for video format conversion
 */
@property (nonatomic, strong, nullable) DLABVideoConverter* inputVideoConverter;

/**
 DLABVideoConverter for video format conversion
 */
@property (nonatomic, strong, nullable) DLABVideoConverter* outputVideoConverter;

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
 Wrapper of IDeckLinkMutableVideoFrame::GetAncillaryData. Caller must release when finished.
 
 @param outFrame IDeckLinkMutableVideoFrame
 @return VideoFrameAncillary for Output Frame.
 */
- (nullable IDeckLinkVideoFrameAncillary *) prepareOutputFrameAncillary:(IDeckLinkMutableVideoFrame*)outFrame;

/**
 Wrapper of IDeckLinkVideoFrameAncillary::GetBufferForVerticalBlankingLine.
 
 @param ancillaryData VideoFrameAncillary for Output Frame.
 @param lineNumber VANC line number of interrest.
 @return row buffer pointer, or null if not available.
 */
- (nullable void*) bufferOfOutputFrameAncillary:(IDeckLinkVideoFrameAncillary*)ancillaryData
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

/**
 Call VANCPacketHandler for output VideoFrame
 
 @param outFrame IDeckLinkMutableVideoFrame
 @param displayTime time at which to display the frame in timeScale units
 @param frameDuration duration for which to display the frame in timeScale units
 @param timeScale time scale for displayTime and displayDuration
 */
- (void) callbackOutputVANCPacketHandler:(IDeckLinkMutableVideoFrame*)outFrame
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
 Wrapper of IDeckLinkVideoInputFrame::GetAncillaryData. Caller must release when finished.
 
 @param inFrame IDeckLinkVideoInputFrame
 @return VideoFrameAncillary for Input Frame.
 */
- (nullable IDeckLinkVideoFrameAncillary *) prepareInputFrameAncillary:(IDeckLinkVideoInputFrame*)inFrame;

/**
 Wrapper of IDeckLinkVideoFrameAncillary::GetBufferForVerticalBlankingLine.
 
 @param ancillaryData VideoFrameAncillary for Input Frame.
 @param lineNumber VANC line number of interrest.
 @return row buffer pointer, or null if not available.
 */
- (nullable void*) bufferOfInputFrameAncillary:(IDeckLinkVideoFrameAncillary*)ancillaryData
                                          line:(uint32_t)lineNumber;

/**
 Call VANCHandler block for input VideoFrame.
 
 @param inFrame IDeckLinkVideoInputFrame
 */
- (void) callbackInputVANCHandler:(IDeckLinkVideoInputFrame*)inFrame;

/**
 Call VANCPacketHandler block for input VideoFrame.
 
 @param inFrame IDeckLinkVideoInputFrame
 */
- (void) callbackInputVANCPacketHandler:(IDeckLinkVideoInputFrame*)inFrame;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: - profile (internal)
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice (ProfileInternal) <DLABProfileCallbackPrivateDelegate>

/* =================================================================================== */
// MARK: DLABProfileCallbackPrivateDelegate
/* =================================================================================== */

/**
 Handle IDeckLinkProfileCallback::ProfileChanging
 
 @param profile IDeckLinkProfile*
 @param streamsWillBeForcedToStop streamsWillBeForcedToStop
 */
- (void) willApplyProfile:(IDeckLinkProfile*)profile stopping:(BOOL)streamsWillBeForcedToStop;

/**
 Handle IDeckLinkProfileCallback::ProfileActivated
 
 @param profile IDeckLinkProfile*
 */
- (void) didApplyProfile:(IDeckLinkProfile*)profile;

@end

NS_ASSUME_NONNULL_END
