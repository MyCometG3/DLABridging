//
//  DLABDeviceNotificationCallback.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABDeviceNotificationCallback.h>

HRESULT DLABDeviceNotificationCallback::DeckLinkDeviceArrived(IDeckLink *deckLink)
{
    if ([delegate respondsToSelector:@selector(didAddDevice:)]) {
        [delegate didAddDevice:deckLink];
    }
    return S_OK;
}

HRESULT DLABDeviceNotificationCallback::DeckLinkDeviceRemoved(IDeckLink *deckLink)
{
    if ([delegate respondsToSelector:@selector(didRemoveDevice:)]) {
        [delegate didRemoveDevice:deckLink];
    }
    return S_OK;
}

HRESULT DLABDeviceNotificationCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkDeviceNotificationCallback, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkDeviceNotificationCallback *>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}
