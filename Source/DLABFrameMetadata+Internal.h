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

#import "DeckLinkAPI_v11_5.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLABFrameMetadata ()

- (nullable instancetype) initWithOutputFrame:(IDeckLinkMutableVideoFrame*) frame NS_DESIGNATED_INITIALIZER;
- (nullable instancetype) initWithInputFrame:(IDeckLinkVideoFrame*) frame NS_DESIGNATED_INITIALIZER;

// For Output (mutable)
@property (nonatomic, assign, nullable, readonly) IDeckLinkMutableVideoFrame* outputFrame;
@property (nonatomic, assign, nullable, readonly) DLABMetaFrame* metaframe;

// For Input (immutable)
@property (nonatomic, assign, nullable, readonly) IDeckLinkVideoFrame* inputFrame;

//
@property (nonatomic, assign) HDRMetadata metadata;

@end

NS_ASSUME_NONNULL_END
