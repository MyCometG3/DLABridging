//
//  DLABQueryInterfaceAny.h
//  DLABridging
//
//  Created by GitHub Copilot on 2026/04/30.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <DeckLinkAPI.h>
#include <cstring>
#include <initializer_list>

#if defined(__cplusplus)

/* =================================================================================== */
// MARK: - Internal QueryInterface helper
/* =================================================================================== */

/**
 * Try multiple IID candidates and return the first matching interface.
 *
 * - source: Any COM/DeckLink object that exposes QueryInterface(REFIID, void**)
 * - out:    Typed output interface pointer
 * - iids:   One or more interface IDs to try in order
 */
template <typename SourceT, typename OutputT>
static inline HRESULT DLABQueryInterfaceAny(SourceT* source,
                                            OutputT** out,
                                            std::initializer_list<REFIID> iids)
{
    if (!out) {
        return E_POINTER;
    }
    *out = nullptr;
    
    if (!source) {
        return E_NOINTERFACE;
    }
    
    for (REFIID iid : iids) {
        OutputT* candidate = nullptr;
        HRESULT hr = source->QueryInterface(iid, reinterpret_cast<void**>(&candidate));
        if (SUCCEEDED(hr) && candidate) {
            *out = candidate;
            return S_OK;
        }
        
        if (candidate) {
            candidate->Release();
        }
    }
    
    return E_NOINTERFACE;
}

/**
 * Variadic convenience overload.
 *
 * Example:
 *   DLABQueryInterfaceAny(source, &out, &IID_A, &IID_B, &IID_C);
 */
template <typename SourceT, typename OutputT, typename... Rest>
static inline HRESULT DLABQueryInterfaceAny(SourceT* source,
                                            OutputT** out,
                                            REFIID firstIID,
                                            const Rest... rest)
{
    return DLABQueryInterfaceAny(source, out, { firstIID, rest... });
}

/**
 * Release helper for COM-style pointers.
 */
template <typename T>
static inline void DLABReleaseIfNeeded(T*& ptr)
{
    if (ptr) {
        ptr->Release();
        ptr = nullptr;
    }
}

/**
 * Check whether an IID matches one candidate IID.
 */
static inline bool DLABIIDMatchesAny(REFIID iid, REFIID candidate)
{
    return memcmp(&iid, &candidate, sizeof(REFIID)) == 0;
}

/**
 * Check whether an IID matches one of multiple candidate IIDs.
 */
template <typename... Rest>
static inline bool DLABIIDMatchesAny(REFIID iid,
                                     REFIID firstIID,
                                     const Rest... rest)
{
    return DLABIIDMatchesAny(iid, firstIID) || DLABIIDMatchesAny(iid, rest...);
}

#endif // defined(__cplusplus)
