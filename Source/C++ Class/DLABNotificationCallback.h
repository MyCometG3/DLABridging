//
//  DLABNotificationCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DLABCallbackBase.h>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkNotificationCallback
 */

/* =================================================================================== */

@protocol DLABNotificationCallbackDelegate <NSObject>
@required
- (void) notify:(BMDNotifications)topic param1:(uint64_t)param1 param2:(uint64_t)param2;
@optional
@end

/* =================================================================================== */

class DLABNotificationCallback;
using DLABNotificationCallbackBase = DLABCallbackBase<DLABNotificationCallback, id<DLABNotificationCallbackDelegate>>;

class DLABNotificationCallback
    : public IDeckLinkNotificationCallback
    , public DLABNotificationCallbackBase
{
    using Base = DLABNotificationCallbackBase;
public:
    using Base::Base;
    
    // IDeckLinkNotificationCallback
    HRESULT Notify(BMDNotifications topic, uint64_t param1, uint64_t param2) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
