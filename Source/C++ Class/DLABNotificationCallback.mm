//
//  DLABNotificationCallback.cpp
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABNotificationCallback.h>

HRESULT DLABNotificationCallback::Notify(BMDNotifications topic, uint64_t param1, uint64_t param2)
{
    if (delegate && [delegate respondsToSelector:@selector(notify:param1:param2:)]) {
        id<DLABNotificationCallbackDelegate> strongDelegate = delegate;
        [strongDelegate notify:topic param1:param1 param2:param2];
    }
    return S_OK;
}

HRESULT DLABNotificationCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkNotificationCallback, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkNotificationCallback *>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}
