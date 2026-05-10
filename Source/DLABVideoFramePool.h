//
//  DLABVideoFramePool.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2024/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#import <DeckLinkAPI.h>

@class DLABVideoSetting;

/// Manages a bounded pool of IDeckLinkMutableVideoFrame objects for
/// scheduled playback.  The pool expands on demand (initial unit 4,
/// subsequent units 2) up to a hard cap of 8 frames.  All internal
/// state is protected by @synchronized(self).
@interface DLABVideoFramePool : NSObject

/// Prepare the pool for the given output device and video setting.
/// Expands the pool if no idle frames are available.  Returns YES
/// when at least one frame is ready.
- (BOOL)prepareWithOutput:(IDeckLinkOutput * _Nonnull)output
                  setting:(DLABVideoSetting * _Nonnull)setting;

/// Reserve a frame from the idle set. Call `prepareWithOutput:setting:`
/// first; returns nil when no prepared idle frame is available.
- (nullable IDeckLinkMutableVideoFrame *)reserveFrame;

/// Return a previously reserved frame to the idle set.
/// Returns YES if the frame was recognized and returned.
- (BOOL)releaseFrame:(IDeckLinkMutableVideoFrame * _Nonnull)frame;

/// Release all frames in the pool and clear both sets.
- (void)freeFrames;

@end

#endif /* __cplusplus */
