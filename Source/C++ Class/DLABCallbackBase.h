//
//  DLABCallbackBase.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2024/09/09.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import <cstdint>
#import <atomic>

/// CRTP base for COM callback classes that share the same pattern:
/// a __weak delegate, an atomic refCount, and standard AddRef/Release.
/// Does NOT inherit from IUnknown — each concrete class explicitly
/// overrides AddRef/Release and delegates to the base to avoid diamond
/// issues with the COM interface hierarchy.
template <typename Derived, typename DelegateT>
class DLABCallbackBase {
protected:
    __weak DelegateT delegate;
    std::atomic<uint32_t> refCount{1};
    
public:
    explicit DLABCallbackBase(DelegateT delegate) : delegate(delegate) {}
    
    uint32_t AddRef() {
        return ++refCount;
    }
    
    uint32_t Release() {
        uint32_t newRefValue = --refCount;
        if (newRefValue == 0) {
            delete static_cast<Derived *>(this);
            return 0;
        }
        return newRefValue;
    }
};
