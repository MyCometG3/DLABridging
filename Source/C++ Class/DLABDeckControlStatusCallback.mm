//
//  DLABDeckControlStatusCallback.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020-2023 MyCometG3. All rights reserved.
//

#import <DLABDeckControlStatusCallback.h>

DLABDeckControlStatusCallback::DLABDeckControlStatusCallback(id<DLABDeckControlStatusCallbackPrivateDelegate> delegate)
: delegate(delegate), refCount(1)
{
}

// IDeckLinkDeckControlStatusCallback

HRESULT DLABDeckControlStatusCallback::TimecodeUpdate(BMDTimecodeBCD currentTimecode)
{
    if ([delegate respondsToSelector:@selector(deckControlTimecodeUpdate:)]) {
        [delegate deckControlTimecodeUpdate:currentTimecode];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::VTRControlStateChanged(BMDDeckControlVTRControlState newState, BMDDeckControlError error)
{
    if ([delegate respondsToSelector:@selector(deckControlVTRControlStateChanged:controlError:)]) {
        [delegate deckControlVTRControlStateChanged:newState controlError:error];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::DeckControlEventReceived(BMDDeckControlEvent event, BMDDeckControlError error)
{
    if ([delegate respondsToSelector:@selector(deckControlEventReceived:controlError:)]) {
        [delegate deckControlEventReceived:event controlError:error];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::DeckControlStatusChanged(BMDDeckControlStatusFlags flags, uint32_t mask)
{
    if ([delegate respondsToSelector:@selector(deckControlStatusChanged:mask:)]) {
        [delegate deckControlStatusChanged:flags mask:mask];
    }
    return S_OK;
}

// IUnknown
HRESULT DLABDeckControlStatusCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkDeckControlStatusCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkInputCallback *)this;
        AddRef();
        return S_OK;
    }
    
    return E_NOINTERFACE;
}

ULONG DLABDeckControlStatusCallback::AddRef()
{
    ULONG newRefValue = ++refCount;
    return newRefValue;
}

ULONG DLABDeckControlStatusCallback::Release()
{
    ULONG newRefValue = --refCount;
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
