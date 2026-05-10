//
//  DLABOutputCallback.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABOutputCallback.h>
#import <DLABQueryInterfaceAny.h>

// IDeckLinkVideoOutputCallback

HRESULT DLABOutputCallback::ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result)
{
    if(delegate && [delegate respondsToSelector:@selector(scheduledFrameCompleted:result:)]) {
        id<DLABOutputCallbackDelegate> strongDelegate = delegate;
        [strongDelegate scheduledFrameCompleted:completedFrame result:result];
    }
    return S_OK;
}

HRESULT DLABOutputCallback::ScheduledPlaybackHasStopped()
{
    if(delegate && [delegate respondsToSelector:@selector(scheduledPlaybackHasStopped)]) {
        id<DLABOutputCallbackDelegate> strongDelegate = delegate;
        [strongDelegate scheduledPlaybackHasStopped];
    }
    return S_OK;
}

// IDeckLinkAudioOutputCallback

HRESULT DLABOutputCallback::RenderAudioSamples(bool preroll)
{
    if(delegate && [delegate respondsToSelector:@selector(renderAudioSamplesPreroll:)]) {
        id<DLABOutputCallbackDelegate> strongDelegate = delegate;
        [strongDelegate renderAudioSamplesPreroll:preroll ? YES : NO];
    }
    return S_OK;
}

//

HRESULT DLABOutputCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (DLABIIDMatchesAny(iid,
                          IID_IDeckLinkVideoOutputCallback,
                          IID_IDeckLinkVideoOutputCallback_v14_2_1)) {
        *ppv = static_cast<IDeckLinkVideoOutputCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (DLABIIDMatchesAny(iid, IID_IDeckLinkAudioOutputCallback)) {
        *ppv = static_cast<IDeckLinkAudioOutputCallback *>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}
