//
//  DLABProfileAttributes.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABProfileAttributes+Internal.h"

@implementation DLABProfileAttributes

- (instancetype) init
{
    NSString *classString = NSStringFromClass([self class]);
    NSString *selectorString = NSStringFromSelector(@selector(initWithProfile:));
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
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
        result = profile->QueryInterface(IID_IDeckLinkProfileAttributes, (void **)&attr);
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
    if (error) {
        if (!description) description = @"unknown description";
        if (!failureReason) failureReason = @"unknown failureReason";
        
        NSString *domain = @"com.MyCometG3.DLABridging.ErrorDomain";
        NSInteger code = (NSInteger)result;
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description,
                                   NSLocalizedFailureReasonErrorKey : failureReason,};
        *error = [NSError errorWithDomain:domain code:code userInfo:userInfo];
        return YES;
    }
    return NO;
}

/* =================================================================================== */
// MARK: - getter attributeID
/* =================================================================================== */

- (NSNumber*) boolValueForAttribute:(DLABAttribute) attributeID
                              error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    bool newBoolValue = false;
    result = _attributes->GetFlag(attr, &newBoolValue);
    if (!result) {
        return @(newBoolValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetFlag failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) intValueForAttribute:(DLABAttribute) attributeID
                             error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    int64_t newIntValue = 0;
    result = _attributes->GetInt(attr, &newIntValue);
    if (!result) {
        return @(newIntValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetInt failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSNumber*) doubleValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    double newDoubleValue = 0;
    result = _attributes->GetFloat(attr, &newDoubleValue);
    if (!result) {
        return @(newDoubleValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetFloat failed."
              code:result
                to:error];
        return nil;
    }
}

- (NSString*) stringValueForAttribute:(DLABAttribute) attributeID
                                error:(NSError**)error
{
    HRESULT result = E_FAIL;
    BMDDeckLinkAttributeID attr = attributeID;
    CFStringRef newStringValue = NULL;
    result = _attributes->GetString(attr, &newStringValue);
    if (!result) {
        return (NSString*)CFBridgingRelease(newStringValue);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkAttributes::GetString failed."
              code:result
                to:error];
        return nil;
    }
}

@end
