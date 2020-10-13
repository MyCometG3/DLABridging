//
//  DLABDeviceNotificationCallback.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDeviceNotificationCallback.h"

DLABDeviceNotificationCallback::DLABDeviceNotificationCallback(id<DLABDeviceNotificationCallbackDelegate> delegate)
: delegate(delegate), refCount(1)
{
}

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
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkDeviceNotificationCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkDeviceNotificationCallback *)this;
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG DLABDeviceNotificationCallback::AddRef()
{
    ULONG newRefValue = ++refCount;
    return newRefValue;
}

ULONG DLABDeviceNotificationCallback::Release()
{
    ULONG newRefValue = --refCount;
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
