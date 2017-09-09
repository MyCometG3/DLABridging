//
//  DLABBrowser+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABBrowser.h"
#import "DLABDevice+Internal.h"
#import "DLABDeviceNotificationCallback.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABBrowser () <DLABDeviceNotificationCallbackDelegate>
{
    IDeckLinkDiscovery *discovery;
    DLABDeviceNotificationCallback *callback;
    DLABVideoIOSupport direction;
    
    void* browserQueueKey;
}

- (nullable instancetype) init;

/**
 NSMutableArray of DLABDevice objects.
 */
@property (nonatomic, strong, nullable) NSMutableArray* devices;

/**
 private dispatch queue.
 */
@property (nonatomic, strong) dispatch_queue_t browserQueue;

/* =================================================================================== */
// MARK: - private method - initial registration
/* =================================================================================== */

/**
 Utility method to find all devices of specified direction.

 @param newDirection Preferred direction(Capture/Playback/Both).
 */
- (void) registerDevicesForDirection:(DLABVideoIOSupport) newDirection;

/* =================================================================================== */
// MARK: - private query
/* =================================================================================== */

/**
 Query device with secified parameter.

 @param deckLink IDeckLink object.
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithDeckLink:(IDeckLink*)deckLink;

/* =================================================================================== */
// MARK: - protocol DLABDeviceNotificationCallbackDelegate
/* =================================================================================== */

/**
 Private protocol DLABDeviceNotificationCallbackDelegate

 @param deckLink The added IDeckLink Object.
 */
- (void) didAddDevice:(IDeckLink*)deckLink;

/**
 Private protocol DLABDeviceNotificationCallbackDelegate

 @param deckLink The removed IDeckLink Object.
 */
- (void) didRemoveDevice:(IDeckLink*)deckLink;

/* =================================================================================== */
// MARK: - private - block helper
/* =================================================================================== */

/**
 Call block in private dispatch queue / sync operation

 @param block block object
 */
- (void) browser_sync:(dispatch_block_t) block;

@end

NS_ASSUME_NONNULL_END
