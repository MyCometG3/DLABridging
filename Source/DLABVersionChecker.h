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
+ (BOOL)isLessThanVersion:(int)version;
+ (BOOL)isAtMostVersion:(int)version;
+ (BOOL)isAtLeastVersion:(int)version;
+ (BOOL)isGreaterThanVersion:(int)version;

+ (BOOL)checkPre1105;   // <= 11.4
+ (BOOL)checkPre110501; // <= 11.5
+ (BOOL)checkPre1106;   // <= 11.5.1
+ (BOOL)checkPre1401;   // <= 14.0
+ (BOOL)checkPre1403;   // <= 14.2.1
+ (BOOL)checkPre1503;   // <= 15.2
+ (BOOL)checkPre1600;   // <= 15.3.1

@end

NS_ASSUME_NONNULL_END
