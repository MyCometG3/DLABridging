//
//  DLABInputCallback.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABInputCallback.h"

DLABInputCallback::DLABInputCallback(id<DLABInputCallbackDelegate> delegate)
: delegate(delegate), refCount(1)
{
}

// DLABInputCallbackDelegate

HRESULT DLABInputCallback::VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode *newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags)
{
    if([delegate respondsToSelector:@selector(didChangeVideoInputFormat:displayMode:flags:)]) {
        [delegate didChangeVideoInputFormat:notificationEvents displayMode:newDisplayMode flags:detectedSignalFlags];
    }
    return S_OK;
}

HRESULT DLABInputCallback::VideoInputFrameArrived(IDeckLinkVideoInputFrame* videoFrame, IDeckLinkAudioInputPacket* audioPacket)
{
    if([delegate respondsToSelector:@selector(didReceiveVideoInputFrame:audioInputPacket:)]) {
        [delegate didReceiveVideoInputFrame:videoFrame audioInputPacket:audioPacket];
    }
    return S_OK;
}

//

HRESULT DLABInputCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkInputCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkInputCallback *)this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkInputCallback_v11_5_1, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkInputCallback *)this;
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG DLABInputCallback::AddRef()
{
    ULONG newRefValue = ++refCount;
    return newRefValue;
}

ULONG DLABInputCallback::Release()
{
    ULONG newRefValue = --refCount;
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
