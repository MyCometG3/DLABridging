//
//  DLABFrameMetadata+Internal.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/15.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABFrameMetadata.h"
#import "DeckLinkAPI.h"
#import "DLABMetaFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABFrameMetadata ()

// For Output (mutable)
- (nullable instancetype) initWithOutputFrame:(IDeckLinkMutableVideoFrame*) frame NS_DESIGNATED_INITIALIZER;
@property (nonatomic, assign, nullable, readonly) IDeckLinkMutableVideoFrame* outputFrame;
@property (nonatomic, assign, nullable, readonly) DLABMetaFrame* metaframe;

// For Input (immutable)
- (nullable instancetype) initWithInputFrame:(IDeckLinkVideoFrame*) frame NS_DESIGNATED_INITIALIZER;
@property (nonatomic, assign, nullable, readonly) IDeckLinkVideoFrame* inputFrame;

@end

NS_ASSUME_NONNULL_END
