//
//  DLABDeckControl.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLABDevice.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DLABDeckControlStatusCallbackDelegate
@required
- (void) deckControlTimecodeUpdate:(DLABTimecodeBCD)currentTimecode;
- (void) deckControlVTRControlStateChanged:(DLABDeckControlVTRControl)newState
                              controlError:(DLABDeckControlError)error;
- (void) deckControlEventReceived:(DLABDeckControlEvent)event
                     controlError:(DLABDeckControlError)error;
- (void) deckControlStatusChanged:(DLABDeckControlStatus)flags mask:(uint32_t)mask;
@optional
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDeckControl : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// Caller must register to receive DLABDeckControlStatusCallback.
@property (nonatomic, weak, readwrite) id<DLABDeckControlStatusCallbackDelegate> delegate;

/// Open the deck with specified timebase.
/// @param timebase Timebase for the deck control.
/// @param dropFrame Use dropframe timecode.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) openWithTimebase:(CMTime)timebase
                dropFrame:(BOOL)dropFrame
                    error:(NSError * _Nullable * _Nullable) error;

/// Close the deck and update standby state.
/// @param standbyOn TRUE for standby on, FALSE for standby off.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) closeWithStandbyOn:(BOOL)standbyOn
                      error:(NSError * _Nullable * _Nullable) error;

/// Convenience property for current DLABDeckControlMode.
@property (nonatomic, assign, readonly) DLABDeckControlMode controlMode;
/// Convenience property for current DLABDeckControlVTRControl.
@property (nonatomic, assign, readonly) DLABDeckControlVTRControl vtrControlState;
/// Convenience property for current DLABDeckControlStatus.
@property (nonatomic, assign, readonly) DLABDeckControlStatus statusFlags;

/// Get current state of the deck.
/// @param mode DLABDeckControlMode
/// @param state DLABDeckControlVTRControl
/// @param flags DLABDeckControlStatus
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) currentStateWithMode:(DLABDeckControlMode*)mode
              vtrControlState:(DLABDeckControlVTRControl*)state
                        flags:(DLABDeckControlStatus*)flags
                        error:(NSError * _Nullable * _Nullable)error;

/// Update the deck standby state.
/// @param standbyOn TRUE for standby on, FALSE for standby off.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) standby:(BOOL)standbyOn error:(NSError * _Nullable * _Nullable)error;

/// Send a custom command to the deck.
/// @param commandBuffer Custom command data.
/// @param responseBuffer Buffer to receive response data.
/// @param size Actual response data size.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) sendCommand:(NSData*)commandBuffer
            response:(NSMutableData*)responseBuffer
        responseSize:(uint32_t*)size
               error:(NSError * _Nullable * _Nullable)error;

/// Send a "play" command to the deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) playWithError:(NSError * _Nullable * _Nullable)error;

/// Send a "stop" command to the deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) stopWithError:(NSError * _Nullable * _Nullable)error;

/// Send a "play" command to "paused"/"stopped" deck. Send a "pause" command to "playing" deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) togglePlayStopWithError:(NSError * _Nullable * _Nullable)error;

/// Send a "eject tape" command to the deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) ejectWithError:(NSError * _Nullable * _Nullable)error;

/// Send a "go to timecode" command to the deck.
/// @param timecode DLABTimecodeBCD
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) goToTimecode:(DLABTimecodeBCD)timecode error:(NSError * _Nullable * _Nullable)error;

/// Send a "fast forward" command to the deck.
/// @param viewTape TRUE for view the tape or automatic selection. FALSE for end to end view.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) fastForwardWithViewTape:(BOOL)viewTape error:(NSError * _Nullable * _Nullable)error;

/// Send a "rewind" command to the deck.
/// @param viewTape TRUE for view the tape or automatic selection. FALSE for end to end view.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) rewindWithViewTape:(BOOL)viewTape error:(NSError * _Nullable * _Nullable)error;

/// Send a "step forward" command to the deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) stepForwardWithError:(NSError * _Nullable * _Nullable)error;

/// Send a "step back" command to the deck.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) stepBackWithError:(NSError * _Nullable * _Nullable)error;

/// Send a “jog playback” command to the deck.
/// @param rate The rate at which to jog playback.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) jogWithRate:(double) rate error:(NSError * _Nullable * _Nullable)error;

/// Send a “shuttle” playback command to the deck.
/// @param rate The rate at which to shuttle playback.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) shuttleWithRate:(double) rate error:(NSError * _Nullable * _Nullable)error;

/// Get the current timecode in string format.
/// @param error Error description if failed.
/// @result Current timecode string.
- (NSString* _Nullable) timecodeStringWithError:(NSError * _Nullable * _Nullable)error;

/// Get timecodeSetting from the deck.
/// @param error Error description if failed.
/// @result Timecodesetting with dummy DLABTimecodeFormat.
- (DLABTimecodeSetting* _Nullable) timecodeSettingWithError:(NSError * _Nullable * _Nullable)error;

/// Get the current timecode in BCD format.
/// @param error Error description if failed.
/// @result DLABTimecodeBCD
- (DLABTimecodeBCD) timecodeBCDWithError:(NSError * _Nullable * _Nullable)error;

/// The preroll period in seconds.
@property (nonatomic, assign, readwrite) uint32_t prerollSeconds;

/// Set the preroll time period.
/// @param prerollInSec The preroll period in seconds to set.
- (void) setPrerollSeconds:(uint32_t)prerollInSec;

/// Get the preroll time period.
/// @result The current preroll period in seconds.
- (uint32_t) prerollSeconds;

/// The field accurate capture timecode offset.
@property (nonatomic, assign, readwrite) int32_t captureOffset;

/// Set the number of fields for a deck specific offset between the inpoint and the time at which the capture starts.
/// @param offsetFields The timecode offset to set in fields.
- (void) setCaptureOffset:(int32_t)offsetFields;

/// Get the number of fields for a deck specific offset between the inpoint and the time at which the capture starts.
/// @result The current timecode offset in fields.
- (int32_t) captureOffset;

/// The field accurate export timecode offset.
@property (nonatomic, assign, readwrite) int32_t exportOffset;

/// Set the number of fields for a deck specific offset prior to the in or out point where an export will begin or end.
/// @param offsetFields The timecode offset to set in fields.
- (void) setExportOffset:(int32_t)offsetFields;

/// Get the number of fields for a deck specific offset prior to the in or out point where an export will begin or end.
/// @result The current timecode offset in fields.
- (int32_t) exportOffset;

/// The recommended delay field of the current deck.
@property (nonatomic, assign, readonly) int32_t manualExportOffset;

/// Get the recommended delay fields of the current deck.
/// @discussion This is only applicable for manual exports and may be adjusted with the main export offset if required.
/// @result The current timecode offset in fields.
- (int32_t) manualExportOffset;

//

/// Starts an export to tape operation using the given parameters.
/// @param inTimecode The timecode to start the export sequence
/// @param outTimecode The timecode to stop the export sequence
/// @param flags DLABDeckControlExportModeOps
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if failed.
- (BOOL) startExportFrom:(DLABTimecodeBCD)inTimecode
                      to:(DLABTimecodeBCD)outTimecode
            modeOpsFlags:(DLABDeckControlExportModeOps)flags
                   error:(NSError * _Nullable * _Nullable)error;

/// Starts a capture operation using the given parameters.
/// @param useVITC If true use VITC as the source of timecodes
/// @param inTimecode The timecode to start the capture sequence.
/// @param outTimecode The timecode to stop the capture sequence.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if fail.
- (BOOL) startCaptureFrom:(DLABTimecodeBCD)inTimecode
                       to:(DLABTimecodeBCD)outTimecode
                  useVITC:(BOOL)useVITC
                    error:(NSError * _Nullable * _Nullable)error;

/// The device ID returned by the deck.
@property (nonatomic, assign, readonly) uint16_t deviceID;

/// Get the device ID returned by the deck.
- (uint16_t)deviceID;

/// The Abort operation is synchronous. Completion is signaled with a DLABDeckControlAbortedEvent event.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if fail.
- (BOOL) abortWithError:(NSError * _Nullable * _Nullable)error;

/// Start the deck record operation.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if fail.
- (BOOL) crashRecordStartWithError:(NSError * _Nullable * _Nullable)error;

/// Stop the deck record operation.
/// @param error Error description if failed.
/// @result TRUE if success, FALSE if error.
- (BOOL) crashRecordStopWithError:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
