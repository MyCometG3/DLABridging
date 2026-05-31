//
//  DLABProfileCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/13.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DLABCallbackBase.h>

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

class DLABProfileCallback;
using DLABProfileCallbackBase = DLABCallbackBase<DLABProfileCallback, id<DLABProfileCallbackPrivateDelegate>>;

class DLABProfileCallback
    : public IDeckLinkProfileCallback
    , public DLABProfileCallbackBase
{
    using Base = DLABProfileCallbackBase;
public:
    using Base::Base;
    
    // IDeckLinkProfileCallback
    HRESULT ProfileChanging(IDeckLinkProfile* profileToBeActivated, bool streamsWillBeForcedToStop) override;
    HRESULT ProfileActivated(IDeckLinkProfile* activatedProfile) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
