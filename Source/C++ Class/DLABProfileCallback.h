//
//  DLABProfileCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/13.
//  Copyright © 2020-2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <atomic>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkProfileCallback
 */

/* =================================================================================== */

@protocol DLABProfileCallbackPrivateDelegate <NSObject>
@required
- (void) willApplyProfile:(IDeckLinkProfile*) profile stopping:(BOOL)streamsWillBeForcedToStop;
- (void) didApplyProfile:(IDeckLinkProfile*) profile;
@optional
@end

/* =================================================================================== */

class DLABProfileCallback : public IDeckLinkProfileCallback
{
public:
    DLABProfileCallback(id<DLABProfileCallbackPrivateDelegate> delegate);
    
    // IDeckLinkProfileCallback
    HRESULT ProfileChanging(IDeckLinkProfile* profileToBeActivated, bool streamsWillBeForcedToStop);
    HRESULT ProfileActivated(IDeckLinkProfile* activatedProfile);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    __weak id<DLABProfileCallbackPrivateDelegate> delegate;
    std::atomic<ULONG> refCount;
};
