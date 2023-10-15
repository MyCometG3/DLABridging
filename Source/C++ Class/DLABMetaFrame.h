//
//  DLABMetaFrame.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2020/03/20.
//  Copyright © 2020-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>
#import <atomic>
#import <DeckLinkAPI_v11_5.h>

/*
 * Internal use only
 * This is C++ subclass from
 * IDeckLinkVideoFrame + IDeckLinkVideoFrameMetadataExtensions
 */

struct HDRMetadata {
    int64_t hdrElectroOpticalTransferFunc;  // bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc
    double hdrDisplayPrimariesRedX;         // bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX
    double hdrDisplayPrimariesRedY;         // bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY
    double hdrDisplayPrimariesGreenX;       // bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX
    double hdrDisplayPrimariesGreenY;       // bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY
    double hdrDisplayPrimariesBlueX;        // bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX
    double hdrDisplayPrimariesBlueY;        // bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY
    double hdrWhitePointX;                  // bmdDeckLinkFrameMetadataHDRWhitePointX
    double hdrWhitePointY;                  // bmdDeckLinkFrameMetadataHDRWhitePointY
    double hdrMaxDisplayMasteringLuminance; // bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance
    double hdrMinDisplayMasteringLuminance; // bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance
    double hdrMaximumContentLightLevel;     // bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel
    double hdrMaximumFrameAverageLightLevel;// bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel
    /*
     NOTE: bmdDeckLinkFrameMetadataColorspace = bmdColorspaceRec2020 (fixed value)
     */
};

/* =================================================================================== */

class DLABMetaFrame : public IDeckLinkVideoFrame, public IDeckLinkVideoFrameMetadataExtensions {
public:
    DLABMetaFrame(IDeckLinkMutableVideoFrame* frame, const HDRMetadata& metadata);
    virtual ~DLABMetaFrame();
    
    //
    HRESULT UpdateMutableVideoFrame(IDeckLinkMutableVideoFrame* frame);
    HRESULT UpdateHDRMetadata(const HDRMetadata& metadata);
    
    // IDeckLinkVideoFrame interface
    virtual long            GetWidth(void)          { return m_videoFrame->GetWidth(); }
    virtual long            GetHeight(void)         { return m_videoFrame->GetHeight(); }
    virtual long            GetRowBytes(void)       { return m_videoFrame->GetRowBytes(); }
    virtual BMDPixelFormat  GetPixelFormat(void)    { return m_videoFrame->GetPixelFormat(); }
    virtual BMDFrameFlags   GetFlags(void)          { return m_videoFrame->GetFlags() | bmdFrameContainsHDRMetadata; }
    virtual HRESULT         GetBytes(void **buffer) { return m_videoFrame->GetBytes(buffer); }
    virtual HRESULT         GetTimecode(BMDTimecodeFormat format, IDeckLinkTimecode **timecode) { return m_videoFrame->GetTimecode(format, timecode); }
    virtual HRESULT         GetAncillaryData(IDeckLinkVideoFrameAncillary **ancillary)          { return m_videoFrame->GetAncillaryData(ancillary); }
    
    // IDeckLinkVideoFrameMetadataExtensions interface
    virtual HRESULT         GetInt(BMDDeckLinkFrameMetadataID metadataID, int64_t *value);
    virtual HRESULT         GetFloat(BMDDeckLinkFrameMetadataID metadataID, double* value);
    virtual HRESULT         GetFlag(BMDDeckLinkFrameMetadataID metadataID, bool* value);
    virtual HRESULT         GetString(BMDDeckLinkFrameMetadataID metadataID, CFStringRef* value);
    virtual HRESULT         GetBytes(BMDDeckLinkFrameMetadataID metadataID, void* buffer, uint32_t* bufferSize);
    
    // Setter expansion for IDeckLinkVideoFrameMetadataExtensions interface
    virtual HRESULT         SetInt(BMDDeckLinkFrameMetadataID metadataID, int64_t value);
    virtual HRESULT         SetFloat(BMDDeckLinkFrameMetadataID metadataID, double value);
    virtual HRESULT         SetFlag(BMDDeckLinkFrameMetadataID metadataID, bool value);
    virtual HRESULT         SetString(BMDDeckLinkFrameMetadataID metadataID, CFStringRef value);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    IDeckLinkMutableVideoFrame* m_videoFrame;
    HDRMetadata                 m_metadata;
    std::atomic<ULONG> refCount;
};

// int
// bmdDeckLinkFrameMetadataColorspace                           = /* 'cspc' */ 0x63737063, // Colorspace of video frame (see BMDColorspace)
// bmdDeckLinkFrameMetadataHDRElectroOpticalTransferFunc        = /* 'eotf' */ 0x656F7466, // EOTF in range 0-7 as per CEA 861.3
//
// double
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedX              = /* 'hdrx' */ 0x68647278, // Red display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesRedY              = /* 'hdry' */ 0x68647279, // Red display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenX            = /* 'hdgx' */ 0x68646778, // Green display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesGreenY            = /* 'hdgy' */ 0x68646779, // Green display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueX             = /* 'hdbx' */ 0x68646278, // Blue display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRDisplayPrimariesBlueY             = /* 'hdby' */ 0x68646279, // Blue display primaries in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRWhitePointX                       = /* 'hdwx' */ 0x68647778, // White point in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRWhitePointY                       = /* 'hdwy' */ 0x68647779, // White point in range 0.0 - 1.0
// bmdDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance      = /* 'hdml' */ 0x68646D6C, // Max display mastering luminance in range 1 cd/m2 - 65535 cd/m2
// bmdDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance      = /* 'hmil' */ 0x686D696C, // Min display mastering luminance in range 0.0001 cd/m2 - 6.5535 cd/m2
// bmdDeckLinkFrameMetadataHDRMaximumContentLightLevel          = /* 'mcll' */ 0x6D636C6C, // Maximum Content Light Level in range 1 cd/m2 - 65535 cd/m2
// bmdDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel     = /* 'fall' */ 0x66616C6C, // Maximum Frame Average Light Level in range 1 cd/m2 - 65535 cd/m2
