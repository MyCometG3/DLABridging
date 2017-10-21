//
//  DLABBrowser.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABBrowser+Internal.h"

const char* kBrowserQueue = "DLABDevice.browserQueue";

@implementation DLABBrowser

- (instancetype) init
{
    self = [super init];
    if (self) {
        direction = DLABVideoIOSupportNone;
        _devices = [NSMutableArray array];
    }
    
    return self;
}

- (void) dealloc
{
    [self stop];
    
    if (callback) {
        callback->Release();
        callback = NULL;
    }
    if (discovery) {
        discovery->Release();
        discovery = NULL;
    }
}

/* =================================================================================== */
// MARK: - public method
/* =================================================================================== */

- (BOOL) startForInput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture;
    return [self startForDirection:newDirection];
}

- (BOOL) startForOutput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportPlayback;
    return [self startForDirection:newDirection];
}

- (BOOL) start
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture | DLABVideoIOSupportPlayback;
    return [self startForDirection:newDirection];
}

- (BOOL) stop
{
    __block HRESULT result = E_FAIL;
    [self browser_sync:^{
        if (direction == DLABVideoIOSupportNone) {
            return;
        }
        direction = DLABVideoIOSupportNone;

        // remove all registerd devices
        [_devices removeAllObjects];
        
        if (discovery) {
            if (callback) {
                result = discovery->UninstallDeviceNotifications();
                
                callback->Release();
                callback = NULL;
            }
            discovery->Release();
            discovery = NULL;
        }
    }];
    
    if (!result) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) startForDirection:(DLABVideoIOSupport) newDirection
{
    NSParameterAssert(newDirection);
    
    // Check parameters
    BOOL newFlag = ((newDirection & (DLABVideoIOSupportCapture|DLABVideoIOSupportPlayback)) == 0);
    if (newFlag) {
        return NO;
    }
    
    __block HRESULT result = E_FAIL;
    [self browser_sync:^{
        BOOL currentFlag = (direction != DLABVideoIOSupportNone);
        if (currentFlag) {
            return;
        }
        
        // initial registration should be done here
        [self registerDevicesForDirection:newDirection];
        
        if (!discovery && !callback) {
            discovery = CreateDeckLinkDiscoveryInstance();
            if (discovery) {
                callback = new DLABDeviceNotificationCallback(self);
                if (callback) {
                    result = discovery->InstallDeviceNotifications(callback);
                }
            }
        }
        
        if (!result) {
            direction = newDirection;
        }
    }];
    
    if (!result) {
        return YES;
    } else {
        return NO;
    }
}

/* =================================================================================== */
// MARK: - public query
/* =================================================================================== */

- (NSArray*) allDevices
{
    __block NSArray* array = nil;
    [self browser_sync:^{
        array = [NSArray arrayWithArray:self.devices];
    }];
    if (array) {
        return array;
    } else {
        return nil;
    }
}

- (DLABDevice*) deviceWithModelName:(NSString*)modelName
                        displayName:(NSString*)displayName
{
    NSParameterAssert(modelName && displayName);
    
    for (DLABDevice* device in self.devices) {
        BOOL matchModelName = ([device.modelNameW compare: modelName] == NSOrderedSame);
        BOOL matchDisplayName = ([device.displayNameW compare: displayName] == NSOrderedSame);
        if (matchModelName && matchDisplayName) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithPersistentID:(int64_t)persistentID
{
    for (DLABDevice* device in self.devices) {
        if (device.persistentIDW == persistentID) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithTopologicalID:(int64_t)topologicalID
{
    for (DLABDevice* device in self.devices) {
        if (device.topologicalIDW == topologicalID) {
            return device;
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: - private method - initial registration
/* =================================================================================== */

- (void) registerDevicesForDirection:(DLABVideoIOSupport) newDirection
{
    NSParameterAssert(newDirection);
    
    NSMutableArray* newDevices = [NSMutableArray array];
    
    // Iterate every DeckLinkDevice and register as initial state
    IDeckLinkIterator* iterator = CreateDeckLinkIteratorInstance();
    if (iterator) {
        IDeckLink* newDeckLink = NULL;
        while (iterator->Next(&newDeckLink) == S_OK) {
            DLABDevice* newDevice = nil;
            
            // Create new DLABDevice from IDeckLink obj
            if ([self deviceWithDeckLink:newDeckLink inclusive:YES] == nil) {
                newDevice = [[DLABDevice alloc] initWithDeckLink:newDeckLink];
            }
            
            // Release source IDeckLink obj
            newDeckLink->Release();
            
            if (newDevice) {
                // Check capability
                BOOL captureFlag = ((newDirection & DLABVideoIOSupportCapture) &&
                                    newDevice.supportCaptureW);
                BOOL playbackFlag = ((newDirection & DLABVideoIOSupportPlayback) &&
                                     newDevice.supportPlaybackW);
                
                // Register as new device
                if (captureFlag || playbackFlag) {
                    [newDevices addObject:newDevice];
                }
            }
        }
        iterator->Release();
    }
    
    if ([newDevices count]) {
        [self browser_sync:^{
            [self.devices addObjectsFromArray:newDevices];
        }];
    }
}

/* =================================================================================== */
// MARK: - private query
/* =================================================================================== */

NS_INLINE BOOL getTwoIDs(IDeckLink* deckLink, int64_t *topologicalIDRef, int64_t *persistentIDRef)
{
    HRESULT error = E_FAIL;
    
    IDeckLinkAttributes* attr = NULL;
    error = deckLink->QueryInterface(IID_IDeckLinkAttributes,
                                     (void **)&attr);
    if (!error && attr) {
        attr->AddRef();
    
        int64_t persistentID = 0;
        HRESULT errPID = attr->GetInt(BMDDeckLinkPersistentID, &persistentID);
        if (!errPID) {
            *persistentIDRef = persistentID;
        }
        int64_t topologicalID = 0;
        HRESULT errTID = attr->GetInt(BMDDeckLinkTopologicalID, &topologicalID);
        if (!errTID) {
            *topologicalIDRef = topologicalID;
        }
        
        attr->Release();
        attr = NULL;
        
        if (errPID && errTID) {
            error = E_FAIL;
        }
    }
    
    if (!error) {
        return YES;
    }
    return NO;
}
- (DLABDevice*) deviceWithDeckLink:(IDeckLink *)deckLink inclusive:(BOOL)flag
{
    NSParameterAssert(deckLink);
    
    int64_t newTopologicalID = 0;
    int64_t newPersistentID = 0;
    if (flag && !getTwoIDs(deckLink, &newTopologicalID, &newPersistentID)) {
        return nil;
    }
    
    for (DLABDevice* device in self.devices) {
        if (device.deckLink == deckLink) {
            return device;
        }
        
        if (flag) {
            int64_t srcTopologicalID = 0;
            int64_t srcPersistentID = 0;
            if (!getTwoIDs(device.deckLink, &srcTopologicalID, &srcPersistentID)) {
                continue;
            }
            if (srcTopologicalID == newTopologicalID &&
                srcPersistentID == newPersistentID) {
                return device;
            }
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithDeckLink:(IDeckLink *)deckLink
{
    NSParameterAssert(deckLink);
    
    for (DLABDevice* device in self.devices) {
        if (device.deckLink == deckLink) {
            return device;
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: - protocol DLABDeviceNotificationCallbackDelegate
/* =================================================================================== */

- (void) didAddDevice:(IDeckLink*)deckLink
{
    NSParameterAssert(deckLink);
    
    [self browser_sync:^{
        // Avoid duplication
        if ([self deviceWithDeckLink:deckLink inclusive:YES])
            return;
        
        DLABDevice* device = [[DLABDevice alloc] initWithDeckLink:deckLink];
        if (device) {
            BOOL captureFlag = ((direction & DLABVideoIOSupportCapture) &&
                                device.supportCaptureW);
            BOOL playbackFlag = ((direction & DLABVideoIOSupportPlayback) &&
                                 device.supportPlaybackW);
            
            if (captureFlag || playbackFlag) {
                [self.devices addObject:device];
                [_delegate didAddDevice:device ofBrowser:self];
            }
        }
    }];
}

- (void) didRemoveDevice:(IDeckLink*)deckLink
{
    NSParameterAssert(deckLink);
    
    [self browser_sync:^{
        DLABDevice* device = [self deviceWithDeckLink:deckLink inclusive:YES];
        if (device) {
            [self.devices removeObject:device];
            [_delegate didRemoveDevice:device ofBrowser:self];
        }
    }];
}

/* =================================================================================== */
// MARK: - private - lazy instantiation
/* =================================================================================== */

- (dispatch_queue_t) browserQueue
{
    if (!_browserQueue) {
        browserQueueKey = &browserQueueKey;
        void *unused = (__bridge void*)self;
        _browserQueue = dispatch_queue_create(kBrowserQueue, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_browserQueue, browserQueueKey, unused, NULL);
    }
    return _browserQueue;
}

/* =================================================================================== */
// MARK: - private - block helper
/* =================================================================================== */

- (void) browser_sync:(dispatch_block_t) block
{
    NSParameterAssert(block);
    
    dispatch_queue_t queue = self.browserQueue; // Allow lazy instantiation
    if (queue) {
        if (browserQueueKey && dispatch_get_specific(browserQueueKey)) {
            block();
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

@end
