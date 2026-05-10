//
//  DLABProfileAttributes.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABProfileAttributes+Internal.h>
#import <DLABBridgingSupport.h>
#include <DLABQueryInterfaceAny.h>

@implementation DLABProfileAttributes

- (instancetype) init
{
    DLABRaiseUnavailableInit(self, @selector(initWithProfile:));
    return nil;
}

- (instancetype) initWithProfile:(IDeckLinkProfile*) profile
{
    NSParameterAssert(profile);
    
    self = [super init];
    if (self) {
        // Retain
        profile->AddRef();
        
        // validate property support (attributes)
        HRESULT result = E_FAIL;
        IDeckLinkProfileAttributes *attr = NULL;
        result = DLABQueryInterfaceAny(profile, &attr,
                                       IID_IDeckLinkProfileAttributes,
                                       IID_IDeckLinkProfileAttributes_v15_3_1);
        if (result == S_OK && attr) {
            _attributes = attr;
            _profile = profile;
        } else {
            if (attr) attr->Release();
            if (profile) profile->Release();
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_attributes) {
        _attributes->Release();
        _attributes = NULL;
    }
    if (_profile) {
        _profile->Release();
        _profile = NULL;
    }
}

// public hash - NSObject
- (NSUInteger) hash
{
    NSUInteger value = (NSUInteger)_attributes ^ (NSUInteger) _profile;
    return value;
}

// public comparison - NSObject
- (BOOL) isEqual:(id)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    return [self isEqualToProfileAttributes:(DLABProfileAttributes*)object];
}

// private comparison - DLABProfileAttributes
- (BOOL) isEqualToProfileAttributes:(DLABProfileAttributes*)object
{
    if (self == object) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    
    if (!( self.attributes == object.attributes )) return NO;
    if (!( self.profile == object.profile )) return NO;
    
    return YES;
}

// NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone
{
    DLABProfileAttributes* obj = [[DLABProfileAttributes alloc] initWithProfile:self.profile];
    return obj;
}

/* =================================================================================== */
// MARK: - Private accessor
/* =================================================================================== */

@synthesize profile = _profile;
@synthesize attributes = _attributes;

/* =================================================================================== */
// MARK: - query attributes
/* =================================================================================== */

- (NSNumber*) profileIDWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* intValue = nil;
    intValue = [self intValueForAttribute:DLABAttributeProfileID error:&err];
    if (intValue && !err) {
        return intValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) supportsInternalKeyingWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* boolValue = nil;
    boolValue = [self boolValueForAttribute:DLABAttributeSupportsInternalKeying error:&err];
    if (boolValue && !err) {
        return boolValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) supportsExternalKeyingWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* boolValue = nil;
    boolValue = [self boolValueForAttribute:DLABAttributeSupportsExternalKeying error:&err];
    if (boolValue && !err) {
        return boolValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) numberOfSubDevicesWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* intValue = nil;
    intValue = [self intValueForAttribute:DLABAttributeNumberOfSubDevices error:&err];
    if (intValue && !err) {
        return intValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) subDeviceIndexWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* intValue = nil;
    intValue = [self intValueForAttribute:DLABAttributeSubDeviceIndex error:&err];
    if (intValue && !err) {
        return intValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) supportsDualLinkSDIWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* boolValue = nil;
    boolValue = [self boolValueForAttribute:DLABAttributeSupportsDualLinkSDI error:&err];
    if (boolValue && !err) {
        return boolValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) supportsQuadLinkSDIWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* boolValue = nil;
    boolValue = [self boolValueForAttribute:DLABAttributeSupportsQuadLinkSDI error:&err];
    if (boolValue && !err) {
        return boolValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

- (NSNumber*) duplexModeWithError:(NSError**)error
{
    NSError* err = nil;
    NSNumber* intValue = nil;
    intValue = [self intValueForAttribute:DLABAttributeDuplex error:&err];
    if (intValue && !err) {
        return intValue;
    } else {
        if (error) *error = err;
        return nil;
    }
}

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

- (BOOL) post:(NSString*)description
       reason:(NSString*)failureReason
         code:(NSInteger)result
           to:(NSError**)error;
{
    return DLABPostError(error, description, failureReason, result);
}

/* =================================================================================== */
// MARK: - getter attributeID
/* =================================================================================== */

- (NSNumber*) boolValueForAttribute:(DLABAttribute) attributeID
                              error:(NSError**)error
{
    return DLABGetFlagValue(_attributes,
                            (BMDDeckLinkAttributeID)attributeID,
                            error,
                            __PRETTY_FUNCTION__,
                            __LINE__,
                            @"IDeckLinkAttributes::GetFlag failed.");
}

- (NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                             error:(NSError**)error
{
    return DLABGetIntValue(_attributes,
                           (BMDDeckLinkAttributeID)attributeID,
                           error,
                           __PRETTY_FUNCTION__,
                           __LINE__,
                           @"IDeckLinkAttributes::GetInt failed.");
}

- (NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    return DLABGetFloatValue(_attributes,
                             (BMDDeckLinkAttributeID)attributeID,
                             error,
                             __PRETTY_FUNCTION__,
                             __LINE__,
                             @"IDeckLinkAttributes::GetFloat failed.");
}

- (NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    return DLABGetStringValue(_attributes,
                              (BMDDeckLinkAttributeID)attributeID,
                              error,
                              __PRETTY_FUNCTION__,
                              __LINE__,
                              @"IDeckLinkAttributes::GetString failed.");
}

- (NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                            withParam:(NSUInteger)param
                                error:(NSError**)error
{
    return DLABGetStringWithParam(_attributes,
                                  (BMDDeckLinkAttributeID)attributeID,
                                  (uint64_t)param,
                                  error,
                                  __PRETTY_FUNCTION__,
                                  __LINE__,
                                  @"IDeckLinkAttributes::GetStringWithParam failed.");
}

@end
