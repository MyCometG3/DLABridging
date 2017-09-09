//
//  DLABTimecodeSetting+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import "DLABTimecodeSetting.h"
#import "DeckLinkAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABTimecodeSetting ()

/**
 Create DLABTimecode instance from IDeckLinkTimecode object.

 @param format Specify value of either RP188 family or VITC family.
 @param timecodeObj IDeckLinkTimecode Object.
 @param userBits Extra userBits(uint32_t) for timecode.
 @return Instance of DLABTimecode.
 */
- (nullable instancetype) initWithTimecodeFormat:(BMDTimecodeFormat)format
                                     timecodeObj:(IDeckLinkTimecode*)timecodeObj
                                        userBits:(BMDTimecodeUserBits)userBits;

@end

NS_ASSUME_NONNULL_END
