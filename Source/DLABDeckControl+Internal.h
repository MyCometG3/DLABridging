//
//  DLABDeckControl+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/07/24.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import "DLABDeckControl.h"
#import "DeckLinkAPI.h"
#import "DLABDeckControlStatusCallback.h"
#import "DLABTimecodeSetting+Internal.h"

/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABDeckControl () <DLABDeckControlStatusCallbackPrivateDelegate>

/**
 Create DLABDeckControl instance from IDeckLink object.

 @param deckLink IDeckLink object.
 @return Instance of DLABDeckControl.
 */
- (nullable instancetype) initWithDeckLink:(IDeckLink *)deckLink NS_DESIGNATED_INITIALIZER;


/* =================================================================================== */
// MARK: - Private Properties
/* =================================================================================== */

/// IDeckLinkDeckControl object
@property (nonatomic, assign, readonly, nullable) IDeckLinkDeckControl* deckControl;

/// Private queue management for deckcontrol call
@property (nonatomic, assign, readonly) void* deckQueueKey;

/// Private dispatch queue for deck control.
@property (nonatomic, strong, readonly, nullable) dispatch_queue_t deckQueue;

@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
