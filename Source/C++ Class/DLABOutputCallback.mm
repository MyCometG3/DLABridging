//
//  DLABOutputCallback.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABOutputCallback.h"

DLABOutputCallback::DLABOutputCallback(id<DLABOutputCallbackDelegate> delegate)
: delegate(delegate), refCount(1)
{
}

// IDeckLinkVideoOutputCallback

HRESULT DLABOutputCallback::ScheduledFrameCompleted(IDeckLinkVideoFrame *completedFrame, BMDOutputFrameCompletionResult result)
{
    if([delegate respondsToSelector:@selector(scheduledFrameCompleted:result:)]) {
        [delegate scheduledFrameCompleted:completedFrame result:result];
    }
    return S_OK;
}

HRESULT DLABOutputCallback::ScheduledPlaybackHasStopped()
{
    if([delegate respondsToSelector:@selector(scheduledPlaybackHasStopped)]) {
        [delegate scheduledPlaybackHasStopped];
    }
    return S_OK;
}

// IDeckLinkAudioOutputCallback

HRESULT DLABOutputCallback::RenderAudioSamples(bool preroll)
{
    if([delegate respondsToSelector:@selector(renderAudioSamplesPreroll:)]) {
        [delegate renderAudioSamplesPreroll:preroll ? YES : NO];
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
    if (memcmp(&iid, &IID_IDeckLinkVideoOutputCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkVideoOutputCallback *)this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkAudioOutputCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkAudioOutputCallback *)this;
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG DLABOutputCallback::AddRef()
{
    int32_t newRefValue = OSAtomicIncrement32(&refCount);
    return newRefValue;
}

ULONG DLABOutputCallback::Release()
{
    int32_t newRefValue = OSAtomicDecrement32(&refCount);
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
