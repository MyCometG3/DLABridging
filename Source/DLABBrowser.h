//
//  DLABBrowser.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DLABridging/DLABConstants.h>

NS_ASSUME_NONNULL_BEGIN

@class DLABDevice;
@class DLABBrowser;

/**
 DLABBrowserDelegate protocol provides caller to know hot device add/remove event.
 */
@protocol DLABBrowserDelegate <NSObject>
@required
/**
 Called when new device is detected as specified direction.
 
 @param device Newly detected device.
 @param sender Monitoring DLABBrowser object.
 */
- (void) didAddDevice:(DLABDevice*) device ofBrowser:(DLABBrowser*)sender;
/**
 Called when a device is removed as specified direction.
 
 @param device The removed device.
 @param sender Monitoring DLABBrowser object.
 */
- (void) didRemoveDevice:(DLABDevice*) device ofBrowser:(DLABBrowser*)sender;
@optional
@end

NS_ASSUME_NONNULL_END

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

/**
 DLABBrowser is the device finder of connected DeckLink devices.
 
 To monitor hot add/remove, keep browser active.
 */
@interface DLABBrowser : NSObject

/**
 Caller must register to receive hot add/remove event.
 */
@property (nonatomic, weak) id<DLABBrowserDelegate> delegate;

/* =================================================================================== */
// MARK: Public query
/* =================================================================================== */

@property (nonatomic, assign, readonly) BOOL isRunning;

/**
 Query all detected devices.
 */
@property (nonatomic, strong, readonly, nullable) NSArray<DLABDevice*>* allDevices;

/**
 Query deivce with specified parameter.
 
 @param persistentID device persistentID.
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithPersistentID:(int64_t)persistentID;

/**
 Query deivce with specified parameter.
 
 @param topologicalID device topologicalID.
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithTopologicalID:(int64_t)topologicalID;

/**
 Query deivce with specified parameter.
 
 @param model device modelName string
 @param display device displayName string
 @return device instance.
 */
- (nullable DLABDevice*) deviceWithModelName:(NSString*)model
                                 displayName:(NSString*)display;

/**
 Getter for DLABDeckLinkAPIInformation
 
 @param informationID DLABDeckLinkAPIInformation
 @return Query result in NSNumber<BOOL>* form.
 */
- (nullable NSNumber*) boolValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID;

/**
 Getter for DLABDeckLinkAPIInformation
 
 @param informationID DLABDeckLinkAPIInformation
 @return Query result in NSNumber<int64_t>* form.
 */
- (nullable NSNumber*) intValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID;

/**
 Getter for DLABDeckLinkAPIInformation
 
 @param informationID DLABDeckLinkAPIInformation
 @return Query result in NSNumber<double>* form.
 */
- (nullable NSNumber*) doubleValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID;

/**
 Getter for DLABDeckLinkAPIInformation
 
 @param informationID DLABDeckLinkAPIInformation
 @return Query result in NSString* form.
 */
- (nullable NSString*) stringValueForAPIInformation:(DLABDeckLinkAPIInformation)informationID;

/* =================================================================================== */
// MARK: Public method
/* =================================================================================== */

/**
 Start detection for input.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) startForInput;

/**
 Start detection for output.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) startForOutput;

/**
 Start detection for both input/output.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) start;

/**
 Stop detection.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) stop;

/**
 Register all DLABDevice(s) which support input.
 
 @return Count of registered DLABDevice(s)
 */
- (NSUInteger) registerDevicesForInput;

/**
 Register all DLABDevice(s) which support output.
 
 @return Count of registered DLABDevice(s)
 */
- (NSUInteger) registerDevicesForOutput;

/**
 Register all DLABDevice(s) which support either input/output.
 
 @return Count of registered DLABDevice(s)
 */
- (NSUInteger) registerDevices;

/**
 Unregister all DLABDevice(s).
 */
- (void) unregisterDevices;

@end

NS_ASSUME_NONNULL_END
