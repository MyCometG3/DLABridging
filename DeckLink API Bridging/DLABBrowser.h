//
//  DLABBrowser.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import "DLABConstants.h"

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
 @param browser Monitoring DLABBrowser object.
 */
- (void) didAddDevice:(DLABDevice*) device browser:(DLABBrowser*) browser;
/**
 Called when a device is removed as specified direction.
 
 @param device The removed device.
 @param browser Monitoring DLABBrowser object.
 */
- (void) didRemoveDevice:(DLABDevice*) device browser:(DLABBrowser*) browser;
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

/**
 Query all detected devices.
 */
@property (nonatomic, readonly, nullable) NSArray<DLABDevice*>* allDevices;

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
 Start detection with specified flag.
 
 @return YES if successfully started. NO if any error.
 */
- (BOOL) startForDirection:(DLABVideoIOSupport) newDirection;

@end

NS_ASSUME_NONNULL_END
