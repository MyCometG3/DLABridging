//
//  DLABDevice.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#import "DLABConstants.h"
@class DLABDevice;
@class DLABVideoSetting;
@class DLABAudioSetting;
@class DLABTimecodeSetting;

/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 DLABOutputPlaybackDelegate provides caller to handle output queueing.
 */
@protocol DLABOutputPlaybackDelegate <NSObject>
@required

/**
 Called when new output VideoFrame is ready to be queued.
 
 @param sender Source DLABDevice object.
 */
- (void)renderVideoFrameOfDevice:(DLABDevice*)sender;

/**
 Called when new output AudioSamples are ready to be queued.
 
 @param sender Source DLABDevice object.
 */
- (void)renderAudioSamplesOfDevice:(DLABDevice*)sender;
@optional

/**
 Called when sceduled playback is stopped.
 
 @param sender Source DLABDevice object.
 */
- (void)scheduledPlaybackHasStoppedOfDevice:(DLABDevice*)sender;
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 DLABInputCaptureDelegate provides caller to handle input frames and format change event.
 */
@protocol DLABInputCaptureDelegate <NSObject>
@required

/**
 Called when new input VideoSample is available.

 @param sampleBuffer CMSampleBufferRef for Video
 @param sender Source DLABDevice object.
 */
- (void)processCapturedVideoSample:(CMSampleBufferRef)sampleBuffer
                          ofDevice:(DLABDevice*)sender;

/**
 Called when new input AudioSample is available.

 @param sampleBuffer CMSampleBufferRef for Audio
 @param sender Source DLABDevice object.
 */
- (void)processCapturedAudioSample:(CMSampleBufferRef)sampleBuffer
                          ofDevice:(DLABDevice*)sender;
@optional

/**
 Called when new input VideoSample with Timecode is available.

 @param sampleBuffer CMSampleBufferRef for Video
 @param setting DLABTimecodeSetting for this VideoSample
 @param sender Source DLABDevice object.
 */
- (void)processCapturedVideoSample:(CMSampleBufferRef)sampleBuffer
                   timecodeSetting:(DLABTimecodeSetting*)setting
                          ofDevice:(DLABDevice*)sender;

/**
 Called when input video format change is detected.

 Caller can do either 1) stop stream, or 2) apply new setting.
 
 1) To stop stream do following:
 
 : stopStreamsWithError:

 2) To apply new setting do following in sequence:
 
 : pauseStreamsWithError:
 : enableVideoInputWithVideoSetting:error:
 : flushStreamsWithError:
 : startStreamsWithError:
 
 (Please refer to BlackMagic Decklink SDK.pdf 2.4.6 Automatic Mode Detection)
 
 @param newVideoSetting New VideoSetting
 @param events DLABVideoInputFormatChangedEvent
 @param flags DLABDetectedVideoInputFormatFlag
 @param sender Source DLABDevice object.
 */
- (void)processInputFormatChangeWithVideoSetting:(nullable DLABVideoSetting*)newVideoSetting
                                          events:(DLABVideoInputFormatChangedEvent)events
                                           flags:(DLABDetectedVideoInputFormatFlag)flags
                                        ofDevice:(DLABDevice*)sender;

/*
 */
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 DLABStatusChangeDelegate protocol provides caller to know when status update is detected.
 */
@protocol DLABStatusChangeDelegate <NSObject>
@required
/**
 Called when status udpate is detected.

 @param statusID DLABDeckLinkStatus
 */
- (void)statusChanged:(DLABDeckLinkStatus)statusID
             ofDevice:(DLABDevice*)sender;
@optional
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 DLABPrefsChangeDelegate protocol provides caller to know when preference update is detected.
 */
@protocol DLABPrefsChangeDelegate <NSObject>
@required
/**
 Called when preference update is detected.
 */
- (void)prefsChangedOfDevice:(DLABDevice*)sender;
@optional
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 Experimental VANC support: VANC callback block
 
 This block is called in sync on delegate queue. You should process immediately.
 
 - output: This block is called prior to outputVideoFrame is scheduled
 
 - input : This block is called prior to inputVideoSample delegate call is performed
 
 If you defined multiple lineNumfer as interrest, sequence of callback will be performed.
 
 Buffer length is available from videoSetting.rowBytes.
 @param timingInfo TimingInfo of Video Input Frame
 @param lineNumber lineNumber of VANC buffer.
 @param buffer VANC buffer of specified lineNumber.
 @return Return FALSE if further call is not acceptable.
 */
typedef BOOL (^VANCHandler) (CMSampleTimingInfo timingInfo, uint32_t lineNumber, void* _Nullable buffer);

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 General DeckLink Device object, wrapper of multiple original DeckLink API C++ objects.

 NOTE: Currently following features are not supported.
  : IdeckLinkVideoFrame3DExtensions
  : IDeckLinkAPIInformation
  : IDeckLinkMemoryAllocator
  : IDeckLinkScreenPreviewCallback, IDeckLinkGLScreenPreviewHelper
  : IDeckLinkDeckControl, IDeckLinkDeckControlStatusCallback.
  : Any Encoder related features (compressed packet support).
  : IDeckLinkVideoFrameMetadataExtensions
  : IDeckLinkVideoConversion
 */
@interface DLABDevice : NSObject

- (instancetype) init NS_UNAVAILABLE;

/* =================================================================================== */
// MARK: (Public) - Readonly
/* =================================================================================== */

// Ready on init

/**
 Device's DLABAttributeModelName value.
 */
@property (nonatomic, copy, readonly) NSString *modelName;

/**
 Device's DLABAttributeDisplayName value.
 */
@property (nonatomic, copy, readonly) NSString *displayName;

/**
 Device's DLABAttributePersistentID value.
 */
@property (nonatomic, assign, readonly) int64_t persistentID;

/**
 Device's DLABAttributeTopologicalID value.
 */
@property (nonatomic, assign, readonly) int64_t topologicalID;

/**
 Detail bitmask of DLABVideoIOSupport. You can examine what kind of keying feature is supported.
 */
@property (nonatomic, assign, readonly) DLABVideoIOSupport supportFlag; // uint32_t

/**
 Convenience flag if the device supports capture (input stream).
 */
@property (nonatomic, assign, readonly) BOOL supportCapture;

/**
 Convenience flag if the device supports playback (output stream).
 */
@property (nonatomic, assign, readonly) BOOL supportPlayback;

/**
 Convenience flag if the device supports keying (output stream).
 */
@property (nonatomic, assign, readonly) BOOL supportKeying;

/**
 Convenience flag if the device supports format change detection (input stream).
 */
@property (nonatomic, assign, readonly) BOOL supportInputFormatDetection;

// lazy instantiation

/**
 Device supported output VideoSetting templates. For reference only.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<DLABVideoSetting*> *outputVideoSettingArray;

/**
 Device supported input VideoSetting templates. For reference only.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<DLABVideoSetting*> *inputVideoSettingArray;

// Ready while video enabled

/**
 Currently available output VideoSetting. Ready while enabled.
 */
@property (nonatomic, strong, readonly, nullable) DLABVideoSetting* outputVideoSetting;

/**
 Currently available input VideoSetting. Ready while enabled.
 */
@property (nonatomic, strong, readonly, nullable) DLABVideoSetting* inputVideoSetting;

// Ready while audio enabled

/**
 Currently available output AudioSetting. Ready while enabled.
 */
@property (nonatomic, strong, readonly, nullable) DLABAudioSetting* outputAudioSetting;

/**
 Currently available input AudioSetting. Ready while enabled.
 */
@property (nonatomic, strong, readonly, nullable) DLABAudioSetting* inputAudioSetting;

/* =================================================================================== */
// MARK: (Public) - Read/Write
/* =================================================================================== */

/**
 Caller should populate to receive DLABOutputPlaybackDelegate call.
 */
@property (nonatomic, weak, nullable) id<DLABOutputPlaybackDelegate> outputDelegate;

/**
 Caller should populate to receive DLABInputCaptureDelegate call.
 */
@property (nonatomic, weak, nullable) id<DLABInputCaptureDelegate> inputDelegate;

/**
 Caller should populate to receive DLABStatusChangeDelegate call.
 */
@property (nonatomic, weak, nullable) id<DLABStatusChangeDelegate> statusDelegate;

/**
 Caller should populate to receive DLABPrefsChangeDelegate call.
 */
@property (nonatomic, weak, nullable) id<DLABPrefsChangeDelegate> prefsDelegate;

/* =================================================================================== */
// MARK: (Public) - VANC support (experimental)
/* =================================================================================== */

/**
 Experimental VANC support: Caller should populate interested line numbers of VANC data.
 */
@property (nonatomic, strong, nullable) NSArray<NSNumber*> *inputVANCLines;

/**
 Experimental VANC support: Caller should populate VANC callback block.
 */
@property (nonatomic, copy, nullable) VANCHandler inputVANCHandler;

/**
 Experimental VANC support: Caller should populate interested line numbers of VANC data.
 */
@property (nonatomic, strong, nullable) NSArray<NSNumber*> *outputVANCLines;

/**
 Experimental VANC support: Caller should populate VANC callback block.
 */
@property (nonatomic, copy, nullable) VANCHandler outputVANCHandler;

/* =================================================================================== */
// MARK: (Public) - Key/Value
/* =================================================================================== */

// getter attributeID

/**
 Getter for DLABAttribute

 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<BOOL>* form.
 */
- (nullable NSNumber*) boolValueForAttribute:(DLABAttribute) attributeID
                                       error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<int64_t>* form.
 */
- (nullable NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                                      error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute

 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<double>* form.
 */
- (nullable NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                         error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSString* form.
 */
- (nullable NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                         error:(NSError * _Nullable * _Nullable)error;

// getter configurationID

/**
 Getter for DLABConfiguration

 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return Query result in NSNumber<BOOL>* form.
 */
- (nullable NSNumber*) boolValueForConfiguration:(DLABConfiguration)configurationID
                                           error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABConfiguration
 
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return Query result in NSNumber<int64_t>* form.
 */
- (nullable NSNumber*) intValueForConfiguration:(DLABConfiguration)configurationID
                                          error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABConfiguration
 
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return Query result in NSNumber<double>* form.
 */
- (nullable NSNumber*) doubleValueForConfiguration:(DLABConfiguration)configurationID
                                             error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABConfiguration
 
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return Query result in NSString* form.
 */
- (nullable NSString*) stringValueForConfiguration:(DLABConfiguration)configurationID
                                             error:(NSError * _Nullable * _Nullable)error;

// setter configrationID

/**
 Setter for DLABConfiguration

 @param value BOOL value
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return YES if no error, NO if failed
 */
- (BOOL) setBoolValue:(BOOL)value
     forConfiguration:(DLABConfiguration) configurationID
                error:(NSError * _Nullable * _Nullable)error;

/**
 Setter for DLABConfiguration
 
 @param value NSInteger value
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return YES if no error, NO if failed
 */
- (BOOL) setIntValue:(NSInteger)value
    forConfiguration:(DLABConfiguration) configurationID
               error:(NSError * _Nullable * _Nullable)error;

/**
 Setter for DLABConfiguration
 
 @param value double_t value
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return YES if no error, NO if failed
 */
- (BOOL) setDoubleValue:(double_t)value
       forConfiguration:(DLABConfiguration) configurationID
                  error:(NSError * _Nullable * _Nullable)error;

/**
 Setter for DLABConfiguration
 
 @param value NSString* value
 @param configurationID DLABConfiguration
 @param error Error description if failed.
 @return YES if no error, NO if failed
 */
- (BOOL) setStringValue:(NSString*)value
       forConfiguration:(DLABConfiguration) configurationID
                  error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkConfiguration::WriteConfigurationToPreferences

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) writeConfigurationToPreferencesWithError:(NSError * _Nullable * _Nullable)error;

// getter statusID

/**
 Getter for DLABDeckLinkStatus

 @param statusID DLABDeckLinkStatus.
 @param error Error description if failed.
 @return Query result in NSNumber<BOOL>* form.
 */
- (nullable NSNumber*) boolValueForStatus:(DLABDeckLinkStatus)statusID
                                    error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABDeckLinkStatus

 @param statusID DLABDeckLinkStatus.
 @param error Error description if failed.
 @return Query result in NSNumber<int64_t>* form.
 */
- (nullable NSNumber*) intValueForStatus:(DLABDeckLinkStatus)statusID
                                   error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABDeckLinkStatus

 @param statusID DLABDeckLinkStatus.
 @param error Error description if failed.
 @return Query result in NSNumber<double>* form.
 */
- (nullable NSNumber*) doubleValueForStatus:(DLABDeckLinkStatus)statusID
                                      error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABDeckLinkStatus

 @param statusID DLABDeckLinkStatus.
 @param error Error description if failed.
 @return Query result in NSString* form.
 */
- (nullable NSString*) stringValueForStatus:(DLABDeckLinkStatus)statusID
                                      error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABDeckLinkStatus.

 @param statusID DLABDeckLinkStatus.
 @param requestSize Byte length of result. Specify 0 if unknown.
 @param error Error description if failed.
 @return Query result in NSMutableData* form.
 */
- (nullable NSMutableData*) dataValueForStatus:(DLABDeckLinkStatus)statusID
                                        ofSize:(NSUInteger) requestSize
                                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: - output (public)
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice (Output)

/* =================================================================================== */
// MARK: Setting
/* =================================================================================== */

/**
 Convenience constructer for Output Video Setting

 @param mode Video stream categoly (i.e. DLABDisplayModeNTSC, DLABDisplayModeHD1080i5994)
 @param format Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 @param videoOutputFlag Additional flag of video (i.e. DLABVideoOutputFlagVANC)
 @param displayModeSupportFlag
 Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 @param error Error description if failed.
 @return Output Video Setting Object.
 */
- (nullable DLABVideoSetting*)createOutputVideoSettingOfDisplayMode:(DLABDisplayMode)mode
                                                        pixelFormat:(DLABPixelFormat)format
                                                         outputFlag:(DLABVideoOutputFlag)videoOutputFlag
                                                        supportedAs:(DLABDisplayModeSupportFlag*)displayModeSupportFlag
                                                              error:(NSError * _Nullable * _Nullable)error;

/**
 Convenience constructer for Output Audio Setting

 @param type BitsPerSample. Either 16 or 32 are supported.
 @param count Number of audio channel. 1 for Mono, 2 for Stereo. 16 max for discrete.
 @param rate Sample frame rate. Only 48000 Hz is supported.
 @param error Error description if failed.
 @return Output Audio Setting object.
 */
- (nullable DLABAudioSetting*)createOutputAudioSettingOfSampleType:(DLABAudioSampleType)type
                                                      channelCount:(uint32_t)count
                                                        sampleRate:(DLABAudioSampleRate)rate
                                                             error:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Video
/* =================================================================================== */

/**
 Wrapper of IDeckLinkOutput::IsScheduledPlaybackRunning

 @param error Error description if failed
 @return Query result in NSNumber<BOOL>* form, or NULL if failed.
 */
- (nullable NSNumber*) isScheduledPlaybackRunningWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::SetScreenPreviewCallback and CreateCocoaScreenPreview()

 @param parentView Parent NSView for preview output.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) setOutputScreenPreviewToView:(nullable NSView*)parentView
                                error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::EnableVideoOutput

 @param setting 
 Output Video Setting created by createOutputVideoSettingOfDisplayMode:pixelFormat:outputFlag:supportedAs:error:
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableVideoOutputWithVideoSetting:(DLABVideoSetting*)setting
                                     error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::DisableVideoOutput

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) disableVideoOutputWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::DisplayVideoFrameSync

 @param pixelBuffer CVPixelBufferRef for output
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) instantPlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::ScheduleVideoFrame
 
 @param pixelBuffer CVPixelBufferRef for output
 @param displayTime time at which to display the frame in timeScale units
 @param frameDuration duration for which to display the frame in timeScale units
 @param timeScale time scale for displayTime and displayDuration
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                atTime:(NSInteger)displayTime
                              duration:(NSInteger)frameDuration
                           inTimeScale:(NSInteger)timeScale
                                 error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::ScheduleVideoFrame with Timecode support

 @param pixelBuffer CVPixelBufferRef for output
 @param displayTime time at which to display the frame in timeScale units
 @param frameDuration duration for which to display the frame in timeScale units
 @param timeScale time scale for displayTime and displayDuration
 @param setting Output Timecode Setting to attach
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) schedulePlaybackOfPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                atTime:(NSInteger)displayTime
                              duration:(NSInteger)frameDuration
                           inTimeScale:(NSInteger)timeScale
                       timecodeSetting:(DLABTimecodeSetting*)setting
                                 error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::GetBufferedVideoFrameCount

 @param error Error description if failed
 @return The number of frames queued, or NULL if failed.
 */
- (nullable NSNumber*) getBufferedVideoFrameCountWithError:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Audio
/* =================================================================================== */

/**
 Wrapper of IDeckLinkOutput::EnableAudioOutput

 @param setting Output Audio Setting created by createOutputAudioSettingOfSampleType:channelCount:sampleRate:error:
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableAudioOutputWithAudioSetting:(DLABAudioSetting*)setting
                                     error:(NSError * _Nullable * _Nullable)error;

/**
 Wrappper of IDeckLinkOutput::DisableAudioOutput

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) disableAudioOutputWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::WriteAudioSamplesSync using AudioBufferList
 
 Audio channel samples must be interleaved into a sample frame and sample frames must be contiguous.
 @param audioBufferList audioBufferList containing audio sample frames.
 @param sampleFrameWritten Actual number of sample frames scheduled.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) instantPlaybackOfAudioBufferList:(AudioBufferList*)audioBufferList
                             writtenCount:(NSUInteger*)sampleFrameWritten
                                    error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::WriteAudioSamplesSync using CMBlockBuffer
 
 Audio channel samples must be interleaved into a sample frame and sample frames must be contiguous.
 @param blockBuffer CMBlockBuffer containing audio sample frames.
 @param byteOffset byteOffset of buffer.
 @param sampleFrameWritten Actual number of sample frames scheduled.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) instantPlaybackOfAudioBlockBuffer:(CMBlockBufferRef)blockBuffer
                                    offset:(size_t)byteOffset
                              writtenCount:(NSUInteger*)sampleFrameWritten
                                     error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::BeginAudioPreroll

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) beginAudioPrerollWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::EndAudioPreroll

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) endAudioPrerollWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::ScheduleAudioSamples using AudioBufferList

 @param audioBufferList audioBufferList containing audio sample frames.
 
 Audio channel samples must be interleaved into a sample frame and sample frames must be contiguous.
 @param streamTime Time for audio playback in units of timeScale.
 To queue samples to play back immediately after currently buffered samples both streamTime
 and timeScale may be set to zero when using DLABAudioOutputStreamTypeContinuous
 @param timeScale Time scale for the audio stream.
 @param sampleFramesWritten Actual number of sample frames scheduled.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) schedulePlaybackOfAudioBufferList:(AudioBufferList*)audioBufferList
                                    atTime:(NSInteger)streamTime
                               inTimeScale:(NSInteger)timeScale
                              writtenCount:(NSUInteger*)sampleFramesWritten
                                     error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::ScheduleAudioSamples using CMBlockBuffer

 Audio channel samples must be interleaved into a sample frame and sample frames must be contiguous.
 @param blockBuffer CMBlockBuffer containing audio sample frames.
 @param byteOffset byteOffset of buffer.
 @param streamTime Time for audio playback in units of timeScale.
 To queue samples to play back immediately after currently buffered samples both streamTime
 and timeScale may be set to zero when using DLABAudioOutputStreamTypeContinuous
 @param timeScale Time scale for the audio stream.
 @param sampleFramesWritten Actual number of sample frames scheduled.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) schedulePlaybackOfAudioBlockBuffer:(CMBlockBufferRef)blockBuffer
                                     offset:(size_t)byteOffset
                                     atTime:(NSInteger)streamTime
                                inTimeScale:(NSInteger)timeScale
                               writtenCount:(NSUInteger*)sampleFramesWritten
                                      error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::GetBufferedAudioSampleFrameCount

 @param error Error description if failed
 @return Number of audio frames currently buffered, or NULL if failed.
 */
- (nullable NSNumber*) getBufferedAudioSampleFrameCountWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::FlushBufferedAudioSamples

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) flushBufferedAudioSamplesWithError:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Stream
/* =================================================================================== */

/**
 Wrapper of IDeckLinkOutput::StartScheduledPlayback

 @param startTime Time at which the playback starts in units of timeScale
 @param timeScale Time scale for playbackStartTime and playbackSpeed
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) startScheduledPlaybackAtTime:(NSUInteger)startTime
                          inTimeScale:(NSUInteger)timeScale
                                error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::StopScheduledPlayback

 NOTE: This method stops stream immediately.
 
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) stopScheduledPlaybackWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::StopScheduledPlayback

 @param timeScale Time scale for stopPlaybackAtTime and actualStopTime.
 Specify 0 to stop immediately
 @param stopPlayBackAtTime Playback time at which to stop in units of timeScale. 
 Specify 0 to stop immediately.
 @param actualStopTime Playback time at which playback actually stopped in units of timeScale.
 Specify NULL to stop immediately
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) stopScheduledPlaybackInTimeScale:(NSInteger)timeScale
                                   atTime:(NSInteger)stopPlayBackAtTime
                         actualStopTimeAt:(nullable NSInteger*)actualStopTime
                                    error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::GetScheduledStreamTime

 @param timeScale Time scale for elapsedTimeSinceSchedulerBegan
 @param streamTime Frame time
 @param playbackSpeed Scheduled playback speed
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) getScheduledStreamTimeInTimeScale:(NSInteger)timeScale
                                streamTime:(NSInteger*)streamTime
                             playbackSpeed:(double*)playbackSpeed
                                     error:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Clock
/* =================================================================================== */

/**
 Wrapper of IDeckLinkOutput::GetReferenceStatus

 @param referenceStatus A bit-mask of the reference status. See DLABReferenceStatus for more details.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) getReferenceStatus:(DLABReferenceStatus*)referenceStatus
                      error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkOutput::GetHardwareReferenceClock

 @param timeScale Desired time scale
 @param hardwareTime Hardware reference time (in units of desiredTimeScale)
 @param timeInFrame Time in frame (in units of desiredTimeScale)
 @param ticksPerFrame Number of ticks for a frame (in units of desiredTimeScale)
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) getOutputHardwareReferenceClockInTimeScale:(NSInteger)timeScale
                                       hardwareTime:(NSInteger*)hardwareTime
                                        timeInFrame:(NSInteger*)timeInFrame
                                      ticksPerFrame:(NSInteger*)ticksPerFrame
                                              error:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Keying
/* =================================================================================== */

/**
 Wrapper of IDeckLinkKeyer::Enable for Internal Keying

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableKeyerAsInternalWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkKeyer::Enable for External Keying

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableKeyerAsExternalWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkKeyer::SetLevel

 @param level The level that the image is to be blended onto the frame.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) updateKeyerLevelWith:(uint8_t)level error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkKeyer::RampUp

 @param numFrames  number of frames that the image is progressively blended in.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) updateKeyerRampUpWith:(uint32_t)numFrames error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkKeyer::RampDown

 @param numFrames The number of frames that the image is progressively blended out.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) updateKeyerRampDownWith:(uint32_t)numFrames error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkKeyer::Disable

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) disableKeyerWithError:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: - Input (public)
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDevice (Input)

/* =================================================================================== */
// MARK: Setting
/* =================================================================================== */

/**
 Convenience constructer for Input Video Setting

 @param mode Video stream categoly (i.e. DLABDisplayModeNTSC, DLABDisplayModeHD1080i5994)
 @param format Raw pixel format type (i.e. DLABPixelFormat8BitYUV, DLABPixelFormat8BitBGRA)
 @param videoInputFlag Additional flag of video input (i.e. DLABVideoInputFlagEnableFormatDetection)
 @param displayModeSupportFlag
 Support status of specified setting (i.e. DLABDisplayModeSupportFlagSupportedWithConversion)
 @param error Error description if failed.
 @return Input Video Setting Object.
 */
- (nullable DLABVideoSetting*)createInputVideoSettingOfDisplayMode:(DLABDisplayMode)mode
                                                       pixelFormat:(DLABPixelFormat)format
                                                         inputFlag:(DLABVideoInputFlag)videoInputFlag
                                                       supportedAs:(DLABDisplayModeSupportFlag*)displayModeSupportFlag
                                                             error:(NSError * _Nullable * _Nullable)error;

/**
 Convenience constructer for Input Audio Setting

 @param type BitsPerSample. Either 16 or 32 are supported.
 @param count Number of audio channel. 1 for Mono, 2 for Stereo. 16 max for discrete.
 @param rate Sample frame rate. Only 48000 Hz is supported.
 @param error Error description if failed.
 @return Input Audio Setting object.
 */
- (nullable DLABAudioSetting*)createInputAudioSettingOfSampleType:(DLABAudioSampleType)type
                                                     channelCount:(uint32_t)count
                                                       sampleRate:(DLABAudioSampleRate)rate
                                                            error:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Video
/* =================================================================================== */

/**
 Wrapper of IDeckLinkInput::SetScreenPreviewCallback and CreateCocoaScreenPreview()

 @param parentView Parent NSView for preview input.
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) setInputScreenPreviewToView:(nullable NSView*)parentView
                               error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::EnableVideoInput

 @param setting Input Video Setting created by
 createInputVideoSettingOfDisplayMode:pixelFormat:inputFlag:supportedAs:error:
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableVideoInputWithVideoSetting:(DLABVideoSetting*)setting
                                    error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::GetAvailableVideoFrameCount

 @param error Error description if failed
 @return The number of available input frames, or NULL if failed.
 */
- (nullable NSNumber*) getAvailableVideoFrameCountWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::DisableVideoInput

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) disableVideoInputWithError:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Audio
/* =================================================================================== */

/**
 Wrapper of IDeckLinkInput::EnableAudioInput

 @param setting Input Audio Setting created by 
 createInputAudioSettingOfSampleType:channelCount:sampleRate:error:
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) enableAudioInputWithSetting:(DLABAudioSetting*)setting
                               error:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::DisableAudioInput

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) disableAudioInputWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::GetAvailableAudioSampleFrameCount

 @param error Error description if failed
 @return The number of buffered audio frames currently available, or NULL if failed.
 */
- (nullable NSNumber*) getAvailableAudioSampleFrameCountWithError:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Stream
/* =================================================================================== */

/**
 Wrapper of IDeckLinkInput::StartStreams

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) startStreamsWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::StopStreams

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) stopStreamsWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::FlushStreams

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) flushStreamsWithError:(NSError * _Nullable * _Nullable)error;

/**
 Wrapper of IDeckLinkInput::PauseStreams

 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) pauseStreamsWithError:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: Clock
/* =================================================================================== */

/**
 Wrapper of IDeckLinkInput::GetHardwareReferenceClock

 @param timeScale Desired time scale
 @param hardwareTime Hardware reference time
 @param timeInFrame Time in frame (in units of desired TimeScale)
 @param ticksPerFrame Number of ticks for a frame (in units of desired TimeScale)
 @param error Error description if failed
 @return YES if no error, NO if failed
 */
- (BOOL) getInputHardwareReferenceClockInTimeScale:(NSInteger)timeScale
                                      hardwareTime:(NSInteger*)hardwareTime
                                       timeInFrame:(NSInteger*)timeInFrame
                                     ticksPerFrame:(NSInteger*)ticksPerFrame
                                             error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END