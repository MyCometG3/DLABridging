//
//  DLABNotificationCallback.cpp
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABNotificationCallback.h"

DLABNotificationCallback::DLABNotificationCallback(id<DLABNotificationCallbackDelegate> delegate)
: delegate(delegate), refCount(1)
{
}

HRESULT DLABNotificationCallback::Notify(BMDNotifications topic, uint64_t param1, uint64_t param2)
{
    if ([delegate respondsToSelector:@selector(notify:param1:param2:)]) {
        [delegate notify:topic param1:param1 param2:param2];
    }
    return S_OK;
}

HRESULT DLABNotificationCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkNotificationCallback, sizeof(REFIID)) == 0) {
        *ppv = (IDeckLinkNotificationCallback *)this;
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG DLABNotificationCallback::AddRef()
{
    int32_t newRefValue = OSAtomicIncrement32(&refCount);
    return newRefValue;
}

ULONG DLABNotificationCallback::Release()
{
    int32_t newRefValue = OSAtomicDecrement32(&refCount);
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
