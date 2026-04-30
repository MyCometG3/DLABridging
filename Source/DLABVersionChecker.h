//
//  DLABVersionChecker.h
//  DLABridging
//
//  Created by Copilot on 2026/04/30.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLABVersionChecker : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedChecker;

+ (int)apiVersion;
+ (BOOL)isBeforeVersion:(int)version;
+ (BOOL)isAtLeastVersion:(int)version;

+ (BOOL)checkPre1105;
+ (BOOL)checkPre110501;
+ (BOOL)checkPre1400;
+ (BOOL)checkPre1403;
+ (BOOL)checkPre1503;
+ (BOOL)checkPre1600;

@end

NS_ASSUME_NONNULL_END
