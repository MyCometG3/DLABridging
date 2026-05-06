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
- (BOOL)isLessThanVersion:(int)version;
- (BOOL)isAtMostVersion:(int)version;
- (BOOL)isAtLeastVersion:(int)version;
- (BOOL)isGreaterThanVersion:(int)version;

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

+ (BOOL)isLessThanVersion:(int)version
{
    return [[self sharedChecker] isLessThanVersion:version];
}

+ (BOOL)isAtMostVersion:(int)version
{
    return [[self sharedChecker] isAtMostVersion:version];
}

+ (BOOL)isAtLeastVersion:(int)version
{
    return [[self sharedChecker] isAtLeastVersion:version];
}

+ (BOOL)isGreaterThanVersion:(int)version
{
    return [[self sharedChecker] isGreaterThanVersion:version];
}

// Convenience methods for specific versions

+ (BOOL)checkPre1105
{
    return [self isLessThanVersion:0x0b050000];
}

+ (BOOL)checkPre110501
{
    return [self isLessThanVersion:0x0b050100];
}

+ (BOOL)checkPre1106
{
    return [self isLessThanVersion:0x0b060000];
}

+ (BOOL)checkPre1401
{
    return [self isLessThanVersion:0x0e010000];
}

+ (BOOL)checkPre1403
{
    return [self isLessThanVersion:0x0e030000];
}

+ (BOOL)checkPre1503
{
    return [self isLessThanVersion:0x0f030000];
}

+ (BOOL)checkPre1600
{
    return [self isLessThanVersion:0x10000000];
}

/* =================================================================================== */
// MARK: Instance methods
/* =================================================================================== */

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

- (BOOL)isLessThanVersion:(int)version
{
    return self.apiVersion < version;
}

- (BOOL)isAtMostVersion:(int)version
{
    return self.apiVersion <= version;
}

- (BOOL)isAtLeastVersion:(int)version
{
    return self.apiVersion >= version;
}

- (BOOL)isGreaterThanVersion:(int)version
{
    return self.apiVersion > version;
}

@end
