//
//  DLABBrowser.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2020 MyCometG3. All rights reserved.
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
    
    [self unregisterDevices];
    
    if (_apiInformation != NULL) {
        _apiInformation->Release();
    }
}

/* =================================================================================== */
// MARK: - public accessors
/* =================================================================================== */

@synthesize delegate = _delegate;
@dynamic isRunning;
@dynamic allDevices;

/* =================================================================================== */
// MARK: - private accessors
/* =================================================================================== */

@synthesize isInstalled = _isInstalled;
@synthesize devices = _devices;
@synthesize browserQueue = _browserQueue;
@synthesize apiInformation = _apiInformation;

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
        if (self->direction == DLABVideoIOSupportNone) {
            return;
        }
        self->direction = DLABVideoIOSupportNone;
        
        result = [self subscribeDeviceNotification:NO];
    }];
    
    if (!result) {
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger) registerDevicesForInput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture;
    return [self registerDevicesForDirection:newDirection];
}

- (NSUInteger) registerDevicesForOutput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportPlayback;
    return [self registerDevicesForDirection:newDirection];
}

- (NSUInteger) registerDevices
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture | DLABVideoIOSupportPlayback;
    return [self registerDevicesForDirection:newDirection];
}

- (void) unregisterDevices
{
    [self browser_sync:^{
        [self.devices removeAllObjects];
    }];
}

/* =================================================================================== */
// MARK: - public query
/* =================================================================================== */

- (BOOL) isRunning {
    return _isInstalled;
}

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
        BOOL matchModelName = ([device.modelName compare: modelName] == NSOrderedSame);
        BOOL matchDisplayName = ([device.displayName compare: displayName] == NSOrderedSame);
        if (matchModelName && matchDisplayName) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithPersistentID:(int64_t)persistentID
{
    for (DLABDevice* device in self.devices) {
        if (device.persistentID == persistentID) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithTopologicalID:(int64_t)topologicalID
{
    for (DLABDevice* device in self.devices) {
        if (device.topologicalID == topologicalID) {
            return device;
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: public Key/Value
/* =================================================================================== */

- (NSNumber*) boolValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID
{
    IDeckLinkAPIInformation* api = self.apiInformation;
    if (api) {
        HRESULT result = E_FAIL;
        BMDDeckLinkAPIInformationID cfgID = informationID;
        bool newBoolValue = false;
        result = api->GetFlag(cfgID, &newBoolValue);
        if (!result) {
            return @(newBoolValue);
        }
    }
    return nil;
}

- (NSNumber*) intValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID
{
    IDeckLinkAPIInformation* api = self.apiInformation;
    if (api) {
        HRESULT result = E_FAIL;
        BMDDeckLinkAPIInformationID cfgID = informationID;
        int64_t newIntValue = false;
        result = api->GetInt(cfgID, &newIntValue);
        if (!result) {
            return @(newIntValue);
        }
    }
    return nil;
}

- (NSNumber*) doubleValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID
{
    IDeckLinkAPIInformation* api = self.apiInformation;
    if (api) {
        HRESULT result = E_FAIL;
        BMDDeckLinkAPIInformationID cfgID = informationID;
        double newDoubleValue = false;
        result = api->GetFloat(cfgID, &newDoubleValue);
        if (!result) {
            return @(newDoubleValue);
        }
    }
    return nil;
}

- (NSString*) stringValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID
{
    IDeckLinkAPIInformation* api = self.apiInformation;
    if (api) {
        HRESULT result = E_FAIL;
        BMDDeckLinkAPIInformationID cfgID = informationID;
        CFStringRef newStringValue = NULL;
        result = api->GetString(cfgID, &newStringValue);
        if (!result) {
            return (NSString*)CFBridgingRelease(newStringValue);
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: - private method - utility method
/* =================================================================================== */

- (HRESULT) subscribeDeviceNotification:(BOOL)flag
{
    HRESULT result = E_FAIL;
    if (flag) {
        if (!self.isInstalled) {
            discovery = CreateDeckLinkDiscoveryInstance();
            callback = new DLABDeviceNotificationCallback(self);
            if (discovery && callback) {
                result = discovery->InstallDeviceNotifications(callback);
            }
        }
        if (!result) {
            self.isInstalled = YES;
        } else {
            if (callback) {
                callback->Release();
                callback = NULL;
            }
            if (discovery) {
                discovery->Release();
                discovery = NULL;
            }
        }
        return result;
    } else {
        if (self.isInstalled) {
            if (discovery && callback) {
                result = discovery->UninstallDeviceNotifications();
            }
        }
        if (!result) {
            self.isInstalled = NO;
            if (callback) {
                callback->Release();
                callback = NULL;
            }
            if (discovery) {
                discovery->Release();
                discovery = NULL;
            }
        }
        return result;
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
        BOOL currentFlag = (self->direction != DLABVideoIOSupportNone);
        if (currentFlag) {
            return;
        }
        
        result = [self subscribeDeviceNotification:YES];
        if (!result) {
            self->direction = newDirection;
        }
    }];
    
    if (!result) {
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger) registerDevicesForDirection:(DLABVideoIOSupport) newDirection
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
                                    newDevice.supportCapture);
                BOOL playbackFlag = ((newDirection & DLABVideoIOSupportPlayback) &&
                                     newDevice.supportPlayback);
                
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
    return [newDevices count];
}

/* =================================================================================== */
// MARK: - private query
/* =================================================================================== */

NS_INLINE BOOL getTwoIDs(IDeckLink* deckLink, int64_t *topologicalIDRef, int64_t *persistentIDRef)
{
    HRESULT error = E_FAIL;
    
    IDeckLinkProfileAttributes* attr = NULL;
    error = deckLink->QueryInterface(IID_IDeckLinkProfileAttributes,
                                     (void **)&attr);
    if (!error && attr) {
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
        
        return YES;
    }
    
    return NO;
}

- (DLABDevice*) deviceWithDeckLink:(IDeckLink *)deckLink inclusive:(BOOL)flag
{
    NSParameterAssert(deckLink);
    
    if (!flag) {
        return [self deviceWithDeckLink:deckLink];
    }
    
    int64_t newTopologicalID = 0;
    int64_t newPersistentID = 0;
    if (!getTwoIDs(deckLink, &newTopologicalID, &newPersistentID)) {
        return nil;
    }
    
    for (DLABDevice* device in self.devices) {
        int64_t srcTopologicalID = 0;
        int64_t srcPersistentID = 0;
        if (!getTwoIDs(device.deckLink, &srcTopologicalID, &srcPersistentID)) {
            continue;
        }
        
        if (device.deckLink == deckLink) {
            return device;
        }
        if (srcTopologicalID == newTopologicalID &&
            srcPersistentID == newPersistentID) {
            return device;
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
            BOOL captureFlag = ((self->direction & DLABVideoIOSupportCapture) &&
                                device.supportCapture);
            BOOL playbackFlag = ((self->direction & DLABVideoIOSupportPlayback) &&
                                 device.supportPlayback);
            
            if (captureFlag || playbackFlag) {
                [self.devices addObject:device];
                [self.delegate didAddDevice:device ofBrowser:self];
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
            [self.delegate didRemoveDevice:device ofBrowser:self];
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

- (IDeckLinkAPIInformation*) apiInformation
{
    if (!_apiInformation) {
        IDeckLinkAPIInformation* interface = CreateDeckLinkAPIInformationInstance();
        _apiInformation = interface;
    }
    return _apiInformation;
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
