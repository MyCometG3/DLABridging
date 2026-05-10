//
//  DLABVideoFramePool.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2024/08/26.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

#import <DLABVideoFramePool.h>
#import <DLABVideoSetting+Internal.h>

static const int kMaxOutputVideoFrameCount = 8;

@interface DLABVideoFramePool ()
{
    NSMutableSet *_frameSet;
    NSMutableSet *_idleSet;
}
@end

@implementation DLABVideoFramePool

- (instancetype)init
{
    self = [super init];
    if (self) {
        _frameSet = [NSMutableSet set];
        _idleSet = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc
{
    [self freeFrames];
}

- (BOOL)prepareWithOutput:(IDeckLinkOutput *)output
                  setting:(DLABVideoSetting *)setting
{
    BOOL ret = NO;
    HRESULT result = E_FAIL;
    if (output && setting) {
        @synchronized (self) {
            BOOL initialSetup = (_frameSet.count == 0);
            int expandingUnit = initialSetup ? 4 : 2;
            
            BOOL needsExpansion = (_idleSet.count == 0);
            if (needsExpansion) {
                int32_t width = (int32_t)setting.width;
                int32_t height = (int32_t)setting.height;
                int32_t rowBytes = (int32_t)setting.rowBytes;
                BMDPixelFormat pixelFormat = setting.pixelFormat;
                BMDFrameFlags flags = setting.outputFlag;
                
                for (int i = 0; i < expandingUnit; i++) {
                    BOOL poolIsFull = (_frameSet.count >= kMaxOutputVideoFrameCount);
                    if (poolIsFull) break;
                    
                    IDeckLinkMutableVideoFrame *outFrame = NULL;
                    result = output->CreateVideoFrame(width, height, rowBytes,
                                                      pixelFormat, flags, &outFrame);
                    if (result) break;
                    
                    NSValue* ptrValue = [NSValue valueWithPointer:(void*)outFrame];
                    [_frameSet addObject:ptrValue];
                    [_idleSet addObject:ptrValue];
                }
            }
            ret = (_idleSet.count > 0);
        }
    }
    return ret;
}

- (IDeckLinkMutableVideoFrame *)reserveFrame
{
    IDeckLinkMutableVideoFrame *outFrame = NULL;
    @synchronized (self) {
        NSValue* ptrValue = [_idleSet anyObject];
        if (ptrValue) {
            [_idleSet removeObject:ptrValue];
            outFrame = (IDeckLinkMutableVideoFrame *)ptrValue.pointerValue;
        }
    }
    return outFrame;
}

- (BOOL)releaseFrame:(IDeckLinkMutableVideoFrame *)frame
{
    BOOL result = NO;
    @synchronized (self) {
        NSValue* ptrValue = [NSValue valueWithPointer:(void*)frame];
        NSValue* orgValue = [_frameSet member:ptrValue];
        if (orgValue) {
            [_idleSet addObject:orgValue];
            result = YES;
        }
    }
    return result;
}

- (void)freeFrames
{
    @synchronized (self) {
        for (NSValue *ptrValue in _frameSet) {
            IDeckLinkMutableVideoFrame *outFrame = (IDeckLinkMutableVideoFrame *)ptrValue.pointerValue;
            if (outFrame) {
                outFrame->Release();
            }
        }
        [_idleSet removeAllObjects];
        [_frameSet removeAllObjects];
    }
}

@end
