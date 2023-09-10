//
//  DLABOutputCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <atomic>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkVideoOutputCallback + IDeckLinkAudioOutputCallback
 */

/* =================================================================================== */

@protocol DLABOutputCallbackDelegate <NSObject>
@required
- (void)scheduledFrameCompleted:(IDeckLinkVideoFrame *)frame
                         result:(BMDOutputFrameCompletionResult)result;
- (void)renderAudioSamplesPreroll:(BOOL)preroll;
- (void)scheduledPlaybackHasStopped;
@optional
@end

/* =================================================================================== */

class DLABOutputCallback : public IDeckLinkVideoOutputCallback, public IDeckLinkAudioOutputCallback
{
public:
    DLABOutputCallback(id<DLABOutputCallbackDelegate> delegate);
    
    // IDeckLinkVideoOutputCallback
    HRESULT ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result);
    HRESULT ScheduledPlaybackHasStopped(void);
    
    // IDeckLinkAudioOutputCallback
    HRESULT RenderAudioSamples(bool preroll);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    __weak id<DLABOutputCallbackDelegate> delegate;
    std::atomic<ULONG> refCount;
};
