//
//  DLABDeviceNotificationCallback.h
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
 * IDeckLinkDeviceNotificationCallback
 */

/* =================================================================================== */

@protocol DLABDeviceNotificationCallbackDelegate <NSObject>
@required
- (void) didAddDevice:(IDeckLink*)deckLink;
- (void) didRemoveDevice:(IDeckLink*)deckLink;
@optional
@end

/* =================================================================================== */

class DLABDeviceNotificationCallback : public IDeckLinkDeviceNotificationCallback,
                                         public DLABCallbackBase<DLABDeviceNotificationCallback, id<DLABDeviceNotificationCallbackDelegate>>
{
    using Base = DLABCallbackBase<DLABDeviceNotificationCallback, id<DLABDeviceNotificationCallbackDelegate>>;
public:
    using Base::Base;
    
    // IDeckLinkDeviceNotificationCallback
    HRESULT DeckLinkDeviceArrived(IDeckLink *deckLink) override;
    HRESULT DeckLinkDeviceRemoved(IDeckLink *deckLink) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
