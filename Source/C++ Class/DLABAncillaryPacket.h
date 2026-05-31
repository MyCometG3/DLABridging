//
//  DLABAncillaryPacket.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/02/26.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <DeckLinkAPI_v15_2.h>
#import <atomic>
#import <mutex>
#import <vector>

/*
 * Internal use only
 * This is C++ subclass from
 * IDeckLinkAncillaryPacket / IDeckLinkAncillaryPacket_v15_2
 */

class DLABAncillaryPacket : public IDeckLinkAncillaryPacket, public IDeckLinkAncillaryPacket_v15_2
{
public:
    DLABAncillaryPacket(void);
    
    // Utility
    HRESULT Update(uint8_t did, uint8_t sdid, uint32_t line, uint8_t dataStreamIndex, NSData* data);
    HRESULT Update(uint8_t did, uint8_t sdid, uint32_t line, uint8_t dataStreamIndex, BMDAncillaryDataSpace dataSpace, NSData* data); // Added in v15_3 or later
    
    // IDeckLinkAncillaryPacket
    // The returned byte pointer references internal storage and becomes invalid after Update().
    HRESULT GetBytes(BMDAncillaryPacketFormat format, const void** data, uint32_t* size) override;
    uint8_t GetDID (void) override;
    uint8_t GetSDID(void) override;
    uint32_t GetLineNumber(void) override;
    uint8_t GetDataStreamIndex(void) override;
    BMDAncillaryDataSpace GetDataSpace(void) override; // Added in v15_3 or later
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG AddRef() override { return ++refCount; }
    ULONG Release() override {
        ULONG newRefValue = --refCount;
        if (newRefValue == 0) {
            delete this;
            return 0;
        }
        return newRefValue;
    }
    
private:
    uint8_t _did;
    uint8_t _sdid;
    uint32_t _line;
    uint8_t _dataStreamIndex;
    BMDAncillaryDataSpace _dataSpace = bmdAncillaryDataSpaceVANC; // Added in v15_3 or later
    std::vector<char> vbuf;
    std::mutex stateMutex;
    std::atomic<ULONG> refCount;
};
