//
//  DLABProfileAttributes.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import "DLABConstants.h"

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

NS_ASSUME_NONNULL_BEGIN

@interface DLABProfileAttributes : NSObject <NSCopying>

- (instancetype) init NS_UNAVAILABLE;

//

/**
 Query DLABProfile value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<int64_t> form.
 */
- (nullable NSNumber*) profileIDWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeSupportsInternalKeying value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<BOOL> form.
 */
- (nullable NSNumber*) supportsInternalKeyingWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeSupportsExternalKeying value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<BOOL> form.
 */
- (nullable NSNumber*) supportsExternalKeyingWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeNumberOfSubDevices value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<int64_t> form.
 */
- (nullable NSNumber*) numberOfSubDevicesWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeSubDeviceIndex value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<int64_t> form.
 */
- (nullable NSNumber*) subDeviceIndexWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeSupportsDualLinkSDI value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<BOOL> form.
 */
- (nullable NSNumber*) supportsDualLinkSDIWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeSupportsQuadLinkSDI value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<BOOL> form.
 */
- (nullable NSNumber*) supportsQuadLinkSDIWithError:(NSError * _Nullable * _Nullable)error;

/**
 Query DLABAttributeDuplex value of this attributes.
 @param error Error description if failed.
 @return value in NSNumber(<int64_t> form.
 */
- (nullable NSNumber*) duplexModeWithError:(NSError**)error;

/* =================================================================================== */
// MARK: (Public) - Key/Value
/* =================================================================================== */

// getter attributeID

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<BOOL>* form.
 */
- (nullable NSNumber*) boolValueForAttribute:(DLABAttribute) attributeID
                                       error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<int64_t>* form.
 */
- (nullable NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                                      error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSNumber<double>* form.
 */
- (nullable NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                         error:(NSError * _Nullable * _Nullable)error;

/**
 Getter for DLABAttribute
 
 @param attributeID DLABAttribute
 @param error Error description if failed.
 @return Query result in NSString* form.
 */
- (nullable NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
