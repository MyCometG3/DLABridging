//
//  DLABInputCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DeckLinkAPIVideoInput_v14_2_1.h>
#import <DeckLinkAPIVideoInput_v11_5_1.h>
#import <DLABCallbackBase.h>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkInputCallback
 */

/* =================================================================================== */

@protocol DLABInputCallbackDelegate <NSObject>
@required
- (void) didChangeVideoInputFormat:(BMDVideoInputFormatChangedEvents)events displayMode:(IDeckLinkDisplayMode*)displayMode flags:(BMDDetectedVideoInputFormatFlags)flags;
- (void) didReceiveVideoInputFrame:(IDeckLinkVideoInputFrame*)videoFrame audioInputPacket: (IDeckLinkAudioInputPacket*)audioPacket;
@optional
@end

/* =================================================================================== */

class DLABInputCallback : public IDeckLinkInputCallback,
                           public DLABCallbackBase<DLABInputCallback, id<DLABInputCallbackDelegate>>
{
    using Base = DLABCallbackBase<DLABInputCallback, id<DLABInputCallbackDelegate>>;
public:
    using Base::Base;
    
    // IDeckLinkInputCallback
    HRESULT VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode *newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags) override;
    HRESULT VideoInputFrameArrived(IDeckLinkVideoInputFrame* videoFrame, IDeckLinkAudioInputPacket* audioPacket) override;
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return Base::AddRef(); }
    ULONG Release() override { return Base::Release(); }
};
