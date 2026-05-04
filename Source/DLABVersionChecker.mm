//
//  DLABVersionChecker.mm
//  DLABridging
//
//  Created by Copilot on 2026/04/30.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABVersionChecker.h>
#import <DLABBridgingSupport.h>
#import <DLABConstants.h>
#import <DeckLinkAPI.h>

#import <dispatch/dispatch.h>

@interface DLABVersionChecker ()
{
    int _apiVersion;
}

- (instancetype)initPrivate;
- (int)fetchAPIVersion;
- (int)apiVersion;
- (BOOL)isBeforeVersion:(int)version;
- (BOOL)isAtLeastVersion:(int)version;

@end

@implementation DLABVersionChecker

+ (instancetype)sharedChecker
{
    static DLABVersionChecker *sharedChecker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedChecker = [[self alloc] initPrivate];
    });
    return sharedChecker;
}

+ (int)apiVersion
{
    return [[self sharedChecker] apiVersion];
}

+ (BOOL)isBeforeVersion:(int)version
{
    return [[self sharedChecker] isBeforeVersion:version];
}

+ (BOOL)isAtLeastVersion:(int)version
{
    return [[self sharedChecker] isAtLeastVersion:version];
}

+ (BOOL)checkPre1105
{
    return [self isBeforeVersion:0x0b050000];
}

+ (BOOL)checkPre110501
{
    return [self isBeforeVersion:0x0b050100];
}

+ (BOOL)checkPre1400
{
    return [self isBeforeVersion:0x0e000000];
}

+ (BOOL)checkPre1403
{
    return [self isBeforeVersion:0x0e030000];
}

+ (BOOL)checkPre1503
{
    return [self isBeforeVersion:0x0f030000];
}

+ (BOOL)checkPre1600
{
    return [self isBeforeVersion:0x10000000];
}

- (instancetype)init
{
    DLABRaiseUnavailableSingletonInit(self, @"sharedChecker");
    return nil;
}

- (instancetype)initPrivate
{
    if (self = [super init]) {
        _apiVersion = [self fetchAPIVersion];
    }
    return self;
}

- (int)fetchAPIVersion
{
    int version = 0;
    IDeckLinkAPIInformation* api = CreateDeckLinkAPIInformationInstance();
    if (api) {
        int64_t newIntValue = 0;
        HRESULT result = api->GetInt(DLABDeckLinkAPIInformationVersion, &newIntValue);
        if (result == S_OK) {
            version = (int)newIntValue;
        }
        api->Release();
    }
    return version;
}

- (int)apiVersion
{
    return _apiVersion;
}

- (BOOL)isBeforeVersion:(int)version
{
    return self.apiVersion < version;
}

- (BOOL)isAtLeastVersion:(int)version
{
    return self.apiVersion >= version;
}

@end
