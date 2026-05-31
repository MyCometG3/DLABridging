//
//  DLABAncillaryPacket.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/02/26.
//  Copyright © 2020-2026 MyCometG3. All rights reserved.
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
    return Update(did, sdid, line, dataStreamIndex, bmdAncillaryDataSpaceVANC, data);
}

HRESULT DLABAncillaryPacket::Update(uint8_t did, uint8_t sdid, uint32_t line, uint8_t dataStreamIndex, BMDAncillaryDataSpace dataSpace, NSData* data)
{
    if (!data) {
        return E_INVALIDARG;
    }
    
    std::lock_guard<std::mutex> lock(stateMutex);
    
    const uint8_t* ptr = (const uint8_t*)data.bytes;
    const size_t length = (size_t)data.length;
    if (length == 0) {
        vbuf.clear();
    } else {
        vbuf.assign((const char*)ptr, (const char*)ptr + length);
    }
    
    _did = did;
    _sdid = sdid;
    _line = line;
    _dataStreamIndex = dataStreamIndex;
    _dataSpace = dataSpace;
    
    return S_OK;
}

// IDeckLinkAncillaryPacket

HRESULT DLABAncillaryPacket::GetBytes(BMDAncillaryPacketFormat format, const void** data, uint32_t* size)
{
    if (format != bmdAncillaryPacketFormatUInt8) {
        return E_NOTIMPL;
    }
    
    std::lock_guard<std::mutex> lock(stateMutex);
    if (size) {
        *size = (uint32_t)vbuf.size();
    }
    if (data) {
        *data = vbuf.empty() ? nullptr : vbuf.data();
    }
    return S_OK;
}

uint8_t DLABAncillaryPacket::GetDID (void)
{
    std::lock_guard<std::mutex> lock(stateMutex);
    return _did;
}

uint8_t DLABAncillaryPacket::GetSDID(void){
    std::lock_guard<std::mutex> lock(stateMutex);
    return _sdid;
}

uint32_t DLABAncillaryPacket::GetLineNumber(void)
{
    std::lock_guard<std::mutex> lock(stateMutex);
    return _line;
}

uint8_t DLABAncillaryPacket::GetDataStreamIndex(void)
{
    std::lock_guard<std::mutex> lock(stateMutex);
    return _dataStreamIndex;
}

BMDAncillaryDataSpace DLABAncillaryPacket::GetDataSpace (void)
{
    std::lock_guard<std::mutex> lock(stateMutex);
    return _dataSpace;
}

// IUnknown

HRESULT DLABAncillaryPacket::QueryInterface(REFIID iid, LPVOID *ppv)
{
    if (!ppv) {
        return E_POINTER;
    }
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkAncillaryPacket*>(this);
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkAncillaryPacket, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkAncillaryPacket*>(this);
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkAncillaryPacket_v15_2, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkAncillaryPacket_v15_2*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}
