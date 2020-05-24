//
//  DLABMetaFrame.cpp
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/20.
//  Copyright © 2020 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#include "DLABMetaFrame.h"
#include "stdexcept"

DLABMetaFrame::DLABMetaFrame(IDeckLinkMutableVideoFrame* frame, const HDRMetadata& metadata)
: refCount(1), m_videoFrame(frame), m_metadata(metadata)
{
    if (m_videoFrame) {
        m_videoFrame->AddRef();
    } else {
        throw std::invalid_argument("invalid_argument:IDeckLinkMutableVideoFrame*");
    }
}

DLABMetaFrame::~DLABMetaFrame()
{
    m_videoFrame->Release();
}

//

HRESULT DLABMetaFrame::UpdateMutableVideoFrame(IDeckLinkMutableVideoFrame *frame)
{
    HRESULT result = S_OK;
    
    if (frame) {
        if (m_videoFrame) m_videoFrame->Release();
        m_videoFrame = frame;
    } else {
        result = E_INVALIDARG;
    }
    
    return result;
}

HRESULT DLABMetaFrame::UpdateHDRMetadata(const HDRMetadata &metadata)
{
    HRESULT result = S_OK;
    
    m_metadata = metadata;
    
    return result;
}

// IDeckLinkVideoFrameMetadataExtensions interface

HRESULT DLABMetaFrame::GetInt(BMDDeckLinkFrameMetadataID metadataID, int64_t* value)
{
    HRESULT result = S_OK;
    
    switch (metadataID)
    {
        case bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc:
            *value = m_metadata.hdrElectroOpticalTransferFunc;
            break;
        case bmdDeckLinkFrameMetadataColorspace:
            // HDR required Rec2020 (fixed value)
            *value = bmdColorspaceRec2020;
            break;
        default:
            value = nullptr;
            result = E_INVALIDARG;
    }
    
    return result;
}

HRESULT DLABMetaFrame::GetFloat(BMDDeckLinkFrameMetadataID metadataID, double* value)
{
    HRESULT result = S_OK;
    
    switch (metadataID)
    {
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX:
            *value = m_metadata.hdrDisplayPrimariesRedX;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY:
            *value = m_metadata.hdrDisplayPrimariesRedY;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX:
            *value = m_metadata.hdrDisplayPrimariesGreenX;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY:
            *value = m_metadata.hdrDisplayPrimariesGreenY;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX:
            *value = m_metadata.hdrDisplayPrimariesBlueX;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY:
            *value = m_metadata.hdrDisplayPrimariesBlueY;
            break;
        case bmdDeckLinkFrameMetadataHDRWhitePointX:
            *value = m_metadata.hdrWhitePointX;
            break;
        case bmdDeckLinkFrameMetadataHDRWhitePointY:
            *value = m_metadata.hdrWhitePointY;
            break;
        case bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance:
            *value = m_metadata.hdrMaxDisplayMasteringLuminance;
            break;
        case bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance:
            *value = m_metadata.hdrMinDisplayMasteringLuminance;
            break;
        case bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel:
            *value = m_metadata.hdrMaximumContentLightLevel;
            break;
        case bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel:
            *value = m_metadata.hdrMaximumFrameAverageLightLevel;
            break;
        default:
            value = nullptr;
            result = E_INVALIDARG;
    }

    return result;
}

HRESULT DLABMetaFrame::GetFlag(BMDDeckLinkFrameMetadataID metadataID, bool* value)
{
    // Not expecting GetFlag
    return E_INVALIDARG;
}

HRESULT DLABMetaFrame::GetString(BMDDeckLinkFrameMetadataID metadataID, CFStringRef* value)
{
    // Not expecting GetString
    return E_INVALIDARG;
}

HRESULT DLABMetaFrame::GetBytes(BMDDeckLinkFrameMetadataID metadataID, void* buffer, uint32_t* bufferSize)
{
    // Not expecting GetBytes
    return E_INVALIDARG;
}

//

HRESULT DLABMetaFrame::SetInt(BMDDeckLinkFrameMetadataID metadataID, int64_t value)
{
    HRESULT result = S_OK;
    
    switch (metadataID)
    {
        case bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc:
            m_metadata.hdrElectroOpticalTransferFunc = value;
            break;
        case bmdDeckLinkFrameMetadataColorspace:
            if (value == bmdColorspaceRec2020) {
                // HDR required Rec2020 (fixed value)
            } else {
                result = E_INVALIDARG;
            }
            break;
        default:
            result = E_INVALIDARG;
    }
    
    return result;
}

HRESULT DLABMetaFrame::SetFloat(BMDDeckLinkFrameMetadataID metadataID, double value)
{
    HRESULT result = S_OK;
    
    switch (metadataID)
    {
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX:
            m_metadata.hdrDisplayPrimariesRedX = value;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY:
            m_metadata.hdrDisplayPrimariesRedY = value;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX:
            m_metadata.hdrDisplayPrimariesGreenX = value;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY:
            m_metadata.hdrDisplayPrimariesGreenY = value;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX:
            m_metadata.hdrDisplayPrimariesBlueX = value;
            break;
        case bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY:
            m_metadata.hdrDisplayPrimariesBlueY = value;
            break;
        case bmdDeckLinkFrameMetadataHDRWhitePointX:
            m_metadata.hdrWhitePointX = value;
            break;
        case bmdDeckLinkFrameMetadataHDRWhitePointY:
            m_metadata.hdrWhitePointY = value;
            break;
        case bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance:
            m_metadata.hdrMaxDisplayMasteringLuminance = value;
            break;
        case bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance:
            m_metadata.hdrMinDisplayMasteringLuminance = value;
            break;
        case bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel:
            m_metadata.hdrMaximumContentLightLevel = value;
            break;
        case bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel:
            m_metadata.hdrMaximumFrameAverageLightLevel = value;
            break;
        default:
            result = E_INVALIDARG;
    }
    
    return result;
}

HRESULT DLABMetaFrame::SetFlag(BMDDeckLinkFrameMetadataID metadataID, bool value)
{
    // Not expecting SetFlag
    return E_INVALIDARG;
}

HRESULT DLABMetaFrame::SetString(BMDDeckLinkFrameMetadataID metadataID, CFStringRef value)
{
    // Not expecting SetFlag
    return E_INVALIDARG;
}

// IUnknown

HRESULT DLABMetaFrame::QueryInterface(REFIID iid, LPVOID *ppv)
{
    *ppv = NULL;
    CFUUIDBytes iunknown = CFUUIDGetUUIDBytes(IUnknownUUID);
    if (memcmp(&iid, &iunknown, sizeof(REFIID)) == 0) {
        *ppv = this;
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkVideoFrame, sizeof(REFIID)) == 0) {
        *ppv = static_cast<IDeckLinkVideoFrame*>(this);
        AddRef();
        return S_OK;
    }
    if (memcmp(&iid, &IID_IDeckLinkVideoFrameMetadataExtensions, sizeof(REFIID)) == 0)
    {
        *ppv = static_cast<IDeckLinkVideoFrameMetadataExtensions*>(this);
        AddRef();
        return S_OK;
    }
    return E_NOINTERFACE;
}

ULONG DLABMetaFrame::AddRef()
{
    int32_t newRefValue = OSAtomicIncrement32(&refCount);
    return newRefValue;
}

ULONG DLABMetaFrame::Release()
{
    int32_t newRefValue = OSAtomicDecrement32(&refCount);
    if (newRefValue == 0) {
        delete this;
        return 0;
    }
    return newRefValue;
}
