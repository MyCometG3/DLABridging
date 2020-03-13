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

@property (nonatomic, assign, nullable) IDeckLinkProfile* profile;
@property (nonatomic, assign, nullable) IDeckLinkProfileAttributes* attributes;

@end

NS_ASSUME_NONNULL_END
