//
//  DLABProfileCallback.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/13.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABProfileCallback.h>

HRESULT DLABProfileCallback::ProfileChanging(IDeckLinkProfile* profileToBeActivated, bool streamsWillBeForcedToStop)
{
    if (delegate && [delegate respondsToSelector:@selector(willApplyProfile:stopping:)]) {
        id<DLABProfileCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate willApplyProfile:profileToBeActivated stopping:streamsWillBeForcedToStop];
    }
    return S_OK;
}

HRESULT DLABProfileCallback::ProfileActivated(IDeckLinkProfile* activatedProfile)
{
    if (delegate && [delegate respondsToSelector:@selector(didApplyProfile:)]) {
        id<DLABProfileCallbackPrivateDelegate> strongDelegate = delegate;
        [strongDelegate didApplyProfile:activatedProfile];
    }
    return S_OK;
}

HRESULT DLABProfileCallback::QueryInterface(REFIID iid, LPVOID *ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkProfileCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkProfileCallback, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkProfileCallback *>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}
