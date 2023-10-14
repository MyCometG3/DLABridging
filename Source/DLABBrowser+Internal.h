//
//  DLABBrowser+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABBrowser.h>
#import <DLABDevice+Internal.h>
#import <DLABDeviceNotificationCallback.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLABBrowser () <DLABDeviceNotificationCallbackDelegate>
{
    IDeckLinkDiscovery *discovery;
    DLABDeviceNotificationCallback *callback;
    DLABVideoIOSupport direction;
    
    void* browserQueueKey;
}

/**
 True if subscribing DeviceNotification.
 */
@property (nonatomic, assign) BOOL isInstalled;

/**
 NSMutableArray of DLABDevice objects.
 */
@property (nonatomic, strong, readonly, nullable) NSMutableArray* devices;

/**
 private dispatch queue.
 */
@property (nonatomic, strong, readonly, nullable) dispatch_queue_t browserQueue;

/**
 IDeckLinkAPIInformation object interface.
 */
@property (nonatomic, assign, readonly, nullable) IDeckLinkAPIInformation* apiInformation;

/* =================================================================================== */
// MARK: - private method - utility method
/* =================================================================================== */

/**
 Start detection with specified flag.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) startForDirection:(DLABVideoIOSupport) newDirection;

/**
 Utility method to find all devices of specified direction.
 
 @param newDirection Preferred direction(Capture/Playback/Both).
 @return Count of registered DLABDevice(s)
 */
- (NSUInteger) registerDevicesForDirection:(DLABVideoIOSupport) newDirection;

/* =================================================================================== */
// MARK: - private query
/* =================================================================================== */

/**
 Query device with secified parameter.
 
 @param deckLink IDeckLink object.
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithDeckLink:(IDeckLink*)deckLink;

/**
 Query device with secified parameter with inclusive option.
 Specify flag = true to consider as same if a pair of persistentID/topologicalID matches.
 
 @param deckLink IDeckLink object.
 @param flag Do inclusive comarison.
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithDeckLink:(IDeckLink *)deckLink inclusive:(BOOL)flag;

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
