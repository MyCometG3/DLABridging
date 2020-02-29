//
//  DLABAncillaryPacket.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/02/26.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>

#import <vector>

/*
 * Internal use only
 * This is C++ subclass from
 * IDeckLinkAncillaryPacket
 */
class DLABAncillaryPacket : public IDeckLinkAncillaryPacket
{
public:
    DLABAncillaryPacket(void);
    
    // Utility
    HRESULT Update(uint8_t did, uint8_t sdid, uint32_t line, uint8_t dataStreamIndex, NSData* data);
    
    // IDeckLinkAncillaryPacket
    HRESULT GetBytes(BMDAncillaryPacketFormat format, const void** data, uint32_t* size);
    uint8_t GetDID (void);
    uint8_t GetSDID(void);
    uint32_t GetLineNumber(void);
    uint8_t GetDataStreamIndex(void);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    uint8_t _did;
    uint8_t _sdid;
    uint32_t _line;
    uint8_t _dataStreamIndex;
    std::vector<char> vbuf;
    int32_t refCount;
};
