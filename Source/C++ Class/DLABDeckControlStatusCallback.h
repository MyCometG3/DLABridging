//
//  DLABDeckControlStatusCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>

/* This software is released under the MIT License, see LICENSE.txt. */

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

class DLABDeckControlStatusCallback : public IDeckLinkDeckControlStatusCallback
{
public:
    DLABDeckControlStatusCallback(id<DLABDeckControlStatusCallbackPrivateDelegate> delegate);
    
    // IDeckLinkDeckControlStatusCallback
    HRESULT TimecodeUpdate(BMDTimecodeBCD currentTimecode);
    HRESULT VTRControlStateChanged(BMDDeckControlVTRControlState newState, BMDDeckControlError error);
    HRESULT DeckControlEventReceived(BMDDeckControlEvent event, BMDDeckControlError error);
    HRESULT DeckControlStatusChanged(BMDDeckControlStatusFlags flags, uint32_t mask);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    __weak id<DLABDeckControlStatusCallbackPrivateDelegate> delegate;
    int32_t refCount;
};
