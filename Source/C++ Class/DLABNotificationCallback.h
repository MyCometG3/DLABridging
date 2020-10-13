//
//  DLABNotificationCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <atomic>

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

class DLABNotificationCallback : public IDeckLinkNotificationCallback
{
public:
    DLABNotificationCallback(id<DLABNotificationCallbackDelegate> delegate);
    
    // IDeckLinkNotificationCallback
    HRESULT Notify(BMDNotifications topic, uint64_t param1, uint64_t param2);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    __weak id<DLABNotificationCallbackDelegate> delegate;
    std::atomic<ULONG> refCount;
};
