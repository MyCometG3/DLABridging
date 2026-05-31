//
//  DLABDeckControlStatusCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DLABCallbackBase.h>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkDeckControlStatusCallback
 */

/* =================================================================================== */

@protocol DLABDeckControlStatusCallbackPrivateDelegate <NSObject>
@required
- (void) deckControlTimecodeUpdate:(BMDTimecodeBCD)currentTimecode;
- (void) deckControlVTRControlStateChanged:(BMDDeckControlVTRControlState)newState controlError:(BMDDeckControlError)error;
- (void) deckControlEventReceived:(BMDDeckControlEvent)event controlError:(BMDDeckControlError)error;
- (void) deckControlStatusChanged:(BMDDeckControlStatusFlags)flags mask:(uint32_t)mask;
@optional
@end

/* =================================================================================== */

class DLABDeckControlStatusCallback;
using DLABDeckControlStatusCallbackBase = DLABCallbackBase<DLABDeckControlStatusCallback, id<DLABDeckControlStatusCallbackPrivateDelegate>>;

class DLABDeckControlStatusCallback
    : public IDeckLinkDeckControlStatusCallback
    , public DLABDeckControlStatusCallbackBase
{
    using Base = DLABDeckControlStatusCallbackBase;
public:
    using Base::Base;
    
    // IDeckLinkDeckControlStatusCallback
    HRESULT TimecodeUpdate(BMDTimecodeBCD currentTimecode) override;
    HRESULT VTRControlStateChanged(BMDDeckControlVTRControlState newState, BMDDeckControlError error) override;
    HRESULT DeckControlEventReceived(BMDDeckControlEvent event, BMDDeckControlError error) override;
    HRESULT DeckControlStatusChanged(BMDDeckControlStatusFlags flags, uint32_t mask) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
