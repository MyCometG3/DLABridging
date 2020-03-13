//
//  DLABDevice+Profile.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020 MyCometG3. All rights reserved.
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
        profile->AddRef();
        DLABProfileAttributes* attrObj = [[DLABProfileAttributes alloc] initWithProfile:profile];
        if (attrObj) {
            __weak typeof(self) wself = self;
            [self delegate_sync:^{
                [delegate willApplyProfileAttributes:attrObj
                                            toDevice:wself
                                            stopping:streamsWillBeForcedToStop]; // sync
            }];
        }
        profile->Release();
    }
}

- (void) didApplyProfile:(IDeckLinkProfile*)profile
{
    NSParameterAssert(profile);
    id<DLABProfileChangeDelegate> delegate = self.profileDelegate;
    if (delegate) {
        profile->AddRef();
        DLABProfileAttributes* attrObj = [[DLABProfileAttributes alloc] initWithProfile:profile];
        if (attrObj) {
            __weak typeof(self) wself = self;
            [self delegate_sync:^{
                [delegate didApplyProfileAttributes:attrObj
                                           toDevice:wself]; // sync
            }];
        }
        profile->Release();
    }
}

@end

/* =================================================================================== */
// MARK: - profile (public)
/* =================================================================================== */

@implementation DLABDevice (Profile)

- (nullable NSArray<DLABProfileAttributes*>*) availableProfileAttributes
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
            
            if (array.count) {
                return [array copy];
            }
        }
    }
    return nil;
}

- (BOOL) activateProfile:(NSNumber *)targetProfileID
{
    NSParameterAssert(targetProfileID != nil);
    IDeckLinkProfileManager *mgr = self.deckLinkProfileManager;
    if (mgr) {
        HRESULT result = E_FAIL;
        BMDProfileID profileID = targetProfileID.unsignedIntValue;
        IDeckLinkProfile* profile = NULL;
        result = mgr->GetProfile(profileID, &profile);
        
        if (result == S_OK && profile) {
            result = profile->SetActive();
            profile->Release();
            
            if (result == S_OK) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

- (BOOL) checkRunningProfile:(NSNumber *)targetProfileID
{
    NSParameterAssert(targetProfileID != nil);
    IDeckLinkProfileManager *mgr = self.deckLinkProfileManager;
    if (mgr) {
        HRESULT result = E_FAIL;
        BMDProfileID profileID = targetProfileID.unsignedIntValue;
        IDeckLinkProfile* profile = NULL;
        result = mgr->GetProfile(profileID, &profile);
        
        if (result == S_OK && profile) {
            bool isActive = false;
            result = profile->IsActive(&isActive);
            profile->Release();
            
            if (result == S_OK && isActive) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

- (BOOL)activateProfileUsingAttributes:(DLABProfileAttributes*)attributes
{
    NSParameterAssert(attributes != nil);
    IDeckLinkProfile* profile = attributes.profile;
    if (profile) {
        HRESULT result = E_FAIL;
        result = profile->SetActive();
        
        if (result == S_OK) {
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)checkRunningProfileUsingAttributes:(DLABProfileAttributes*)attributes
{
    NSParameterAssert(attributes != nil);
    IDeckLinkProfile* profile = attributes.profile;
    if (profile) {
        HRESULT result = E_FAIL;
        bool isActive = false;
        result = profile->IsActive(&isActive);
        
        if (result == S_OK && isActive) {
            return TRUE;
        }
    }
    return FALSE;
}

@end
