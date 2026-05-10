//
//  DLABOutputCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DeckLinkAPI_v14_2_1.h>
#import <DLABCallbackBase.h>

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

class DLABOutputCallback : public IDeckLinkVideoOutputCallback,
                            public IDeckLinkAudioOutputCallback,
                            public DLABCallbackBase<DLABOutputCallback, id<DLABOutputCallbackDelegate>>
{
    using Base = DLABCallbackBase<DLABOutputCallback, id<DLABOutputCallbackDelegate>>;
public:
    using Base::Base;
    
    // IDeckLinkVideoOutputCallback
    HRESULT ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result) override;
    HRESULT ScheduledPlaybackHasStopped(void) override;
    
    // IDeckLinkAudioOutputCallback
    HRESULT RenderAudioSamples(bool preroll) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
