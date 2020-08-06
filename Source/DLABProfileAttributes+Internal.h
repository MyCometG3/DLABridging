//
//  DLABProfileAttributes+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/14.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABProfileAttributes.h"
#import "DeckLinkAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABProfileAttributes ()

- (nullable instancetype) initWithProfile:(IDeckLinkProfile*) profile NS_DESIGNATED_INITIALIZER;

/* =================================================================================== */
// MARK: - (Private) - error helper
/* =================================================================================== */

/**
 Utility method to fill (NSError * _Nullable * _Nullable)
 
 @param description string for NSLocalizedDescriptionKey
 @param failureReason string for NSLocalizedFailureReasonErrorKey
 @param result error code
 @param error pointer to (NSError*)
 @return YES if no error, NO if failed
 */
- (BOOL) post:(nullable NSString*)description
       reason:(nullable NSString*)failureReason
         code:(NSInteger)result
           to:(NSError * _Nullable * _Nullable)error;

/* =================================================================================== */
// MARK: -
/* =================================================================================== */

@property (nonatomic, assign, nullable) IDeckLinkProfile* profile;
@property (nonatomic, assign, nullable) IDeckLinkProfileAttributes* attributes;

@end

NS_ASSUME_NONNULL_END
