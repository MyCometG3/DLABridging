//
//  DLABAncillaryPacket.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/02/26.
//  Copyright © 2020-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <DLABAncillaryPacket.h>

DLABAncillaryPacket::DLABAncillaryPacket(void)
: refCount(1), _did(0), _sdid(0), _line(0), _dataStreamIndex(0)
{
}

// Utility

HRESULT DLABAncillaryPacket::Update(uint8_t did, uint8_t sdid, uint32_t line, uint8_t dataStreamIndex, NSData* data)
{
    if (data) {
        char* ptr = (char*) data.bytes;
        size_t length = (size_t) data.length;
        vbuf.resize(length);
        vbuf.shrink_to_fit();
        if (ptr && length) {
            memcpy(&vbuf[0], ptr, length);
        }
        
        _did = did;
        _sdid = sdid;
        _line = line;
        _dataStreamIndex = dataStreamIndex;
        
        return S_OK;
    }
    return E_INVALIDARG;
}

// IDeckLinkAncillaryPacket

HRESULT DLABAncillaryPacket::GetBytes(BMDAncillaryPacketFormat format, const void** data, uint32_t* size)
{
    if (format != bmdAncillaryPacketFormatUInt8) {
        return E_NOTIMPL;
    }
    if (size)
        *size = (uint32_t)vbuf.size();
    if (data)
        *data = vbuf.data();
    return S_OK;
}

uint8_t DLABAncillaryPacket::GetDID (void)
{
    return _did;
}

uint8_t DLABAncillaryPacket::GetSDID(void){
    return _sdid;
}

uint32_t DLABAncillaryPacket::GetLineNumber(void)
{
    return _line;
}

uint8_t DLABAncillaryPacket::GetDataStreamIndex(void)
{
    return _dataStreamIndex;
}

// IUnknown

HRESULT DLABAncillaryPacket::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    return E_NOINTERFACE;
}

ULONG DLABAncillaryPacket::AddRef()
{
    ULONG newRefValue = ++refCount;
    return newRefValue;
}

ULONG DLABAncillaryPacket::Release()
{
    ULONG newRefValue = --refCount;
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
