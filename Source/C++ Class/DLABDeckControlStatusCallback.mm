//
//  DLABDeckControlStatusCallback.m
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDeckControlStatusCallback.h>

// IDeckLinkDeckControlStatusCallback

HRESULT DLABDeckControlStatusCallback::TimecodeUpdate(BMDTimecodeBCD currentTimecode)
{
    if (delegate && [delegate respondsToSelector:@selector(deckControlTimecodeUpdate:)]) {
        id<DLABDeckControlStatusCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate deckControlTimecodeUpdate:currentTimecode];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::VTRControlStateChanged(BMDDeckControlVTRControlState newState, BMDDeckControlError error)
{
    if (delegate && [delegate respondsToSelector:@selector(deckControlVTRControlStateChanged:controlError:)]) {
        id<DLABDeckControlStatusCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate deckControlVTRControlStateChanged:newState controlError:error];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::DeckControlEventReceived(BMDDeckControlEvent event, BMDDeckControlError error)
{
    if (delegate && [delegate respondsToSelector:@selector(deckControlEventReceived:controlError:)]) {
        id<DLABDeckControlStatusCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate deckControlEventReceived:event controlError:error];
    }
    return S_OK;
}

HRESULT DLABDeckControlStatusCallback::DeckControlStatusChanged(BMDDeckControlStatusFlags flags, uint32_t mask)
{
    if (delegate && [delegate respondsToSelector:@selector(deckControlStatusChanged:mask:)]) {
        id<DLABDeckControlStatusCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate deckControlStatusChanged:flags mask:mask];
    }
    return S_OK;
}

// IUnknown
HRESULT DLABDeckControlStatusCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkDeckControlStatusCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkDeckControlStatusCallback, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkDeckControlStatusCallback *>(this);
        AddRef();
        return S_OK;
    }
    
    return E_NOINTERFACE;
}
