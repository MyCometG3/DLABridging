//
//  DLABDevice+Profile.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABDevice+Internal.h"

/* =================================================================================== */
// MARK: - profile (internal)
/* =================================================================================== */

@implementation DLABDevice (ProfileInternal)

/* =================================================================================== */
// MARK: DLABProfileCallbackPrivateDelegate
/* =================================================================================== */

- (void) willApplyProfile:(IDeckLinkProfile*)profile stopping:(BOOL)streamsWillBeForcedToStop
{
    NSParameterAssert(profile);
    
    id<DLABProfileChangeDelegate> delegate = self.profileDelegate;
    if (delegate) {
        DLABProfileAttributes* attrObj = [[DLABProfileAttributes alloc] initWithProfile:profile];
        if (attrObj) {
            __weak typeof(self) wself = self;
            [self delegate_sync:^{
                [delegate willApplyProfileAttributes:attrObj
                                            toDevice:wself
                                            stopping:streamsWillBeForcedToStop]; // sync
            }];
        }
    }
}

- (void) didApplyProfile:(IDeckLinkProfile*)profile
{
    NSParameterAssert(profile);
    
    id<DLABProfileChangeDelegate> delegate = self.profileDelegate;
    if (delegate) {
        DLABProfileAttributes* attrObj = [[DLABProfileAttributes alloc] initWithProfile:profile];
        if (attrObj) {
            __weak typeof(self) wself = self;
            [self delegate_sync:^{
                [delegate didApplyProfileAttributes:attrObj
                                           toDevice:wself]; // sync
            }];
        }
    }
}

@end

/* =================================================================================== */
// MARK: - profile (public)
/* =================================================================================== */

@implementation DLABDevice (Profile)

- (NSArray<DLABProfileAttributes*>*) availableProfileAttributesWithError:(NSError**)error
{
    IDeckLinkProfileManager *mgr = self.deckLinkProfileManager;
    if (mgr) {
        HRESULT result = E_FAIL;
        IDeckLinkProfileIterator *itr = NULL;
        result = mgr->GetProfiles(&itr);
        
        if (result == S_OK && itr) {
            NSMutableArray* array = [NSMutableArray new];
            
            IDeckLinkProfile* profile = NULL;
            while (itr->Next(&profile) == S_OK) {
                if (profile) {
                    DLABProfileAttributes* attrObj = nil;
                    attrObj = [[DLABProfileAttributes alloc] initWithProfile:profile];
                    if (attrObj) {
                        [array addObject:attrObj];
                    }
                    profile->Release();
                    profile = NULL;
                }
            }
            itr->Release();
            
            return array;
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkProfileManager::GetProfiles failed."
                  code:result
                    to:error];
            return nil;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfileManager is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
}

- (BOOL) activateProfile:(NSNumber *)targetProfileID error:(NSError**)error
{
    NSParameterAssert(targetProfileID != nil);
    
    HRESULT result = E_FAIL;
    
    IDeckLinkProfileManager *mgr = self.deckLinkProfileManager;
    if (mgr) {
        BMDProfileID profileID = targetProfileID.unsignedIntValue;
        IDeckLinkProfile* profile = NULL;
        mgr->GetProfile(profileID, &profile);
        if (profile) {
            result = profile->SetActive();
            profile->Release();
        } else {
            [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
                reason:@"IDeckLinkProfileManager::GetProfiles failed."
                  code:result
                    to:error];
            return NO;
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfileManager is not supported."
              code:E_NOINTERFACE
                to:error];
        return NO;
    }
    
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfile::SetActive failed."
              code:result
                to:error];
        return NO;
    }
}

- (NSNumber*) checkRunningProfile:(NSNumber *)targetProfileID error:(NSError**)error
{
    NSParameterAssert(targetProfileID != nil);
    
    HRESULT result = E_FAIL;
    bool isActive = false;
    
    IDeckLinkProfileManager *mgr = self.deckLinkProfileManager;
    if (mgr) {
        BMDProfileID profileID = targetProfileID.unsignedIntValue;
        IDeckLinkProfile* profile = NULL;
        mgr->GetProfile(profileID, &profile);
        if (profile) {
            result = profile->IsActive(&isActive);
            profile->Release();
        }
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfileManager is not supported."
              code:E_NOINTERFACE
                to:error];
        return nil;
    }
    
    if (result == S_OK) {
        return @(isActive);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfile::IsActive failed."
              code:result
                to:error];
        return nil;
    }
}

- (BOOL) activateProfileUsingAttributes:(DLABProfileAttributes*)attributes error:(NSError**)error
{
    NSParameterAssert(attributes != nil);
    
    HRESULT result = E_FAIL;
    
    IDeckLinkProfile* profile = attributes.profile;
    if (profile) {
        result = profile->SetActive();
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABProfileAttributes - profile is not available."
              code:paramErr
                to:error];
        return NO;
    }
    
    if (result == S_OK) {
        return YES;
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfile::SetActive failed."
              code:result
                to:error];
        return NO;
    }
}

- (NSNumber*)checkRunningProfileUsingAttributes:(DLABProfileAttributes*)attributes error:(NSError**)error
{
    NSParameterAssert(attributes != nil);
    
    HRESULT result = E_FAIL;
    bool isActive = false;
    
    IDeckLinkProfile* profile = attributes.profile;
    if (profile) {
        result = profile->IsActive(&isActive);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"DLABProfileAttributes - profile is not available."
              code:paramErr
                to:error];
        return nil;
    }
    
    if (result == S_OK) {
        return @(isActive);
    } else {
        [self post:[NSString stringWithFormat:@"%s (%d)", __PRETTY_FUNCTION__, __LINE__]
            reason:@"IDeckLinkProfile::IsActive failed."
              code:result
                to:error];
        return nil;
    }
}

@end
