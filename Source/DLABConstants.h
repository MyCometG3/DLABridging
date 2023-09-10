//
//  DLABConstants.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>

/**
 Swift-safe NS_ENUM/NS_OPTIONS definition
 
 NOTE: This constants are converted from DekLink API "11.5.x"
 NOTE: Basic renaming rules are:
 1. each enum type name BMDtypename => DLABtypename (DeckLink API bridging)
 1a. remove "s" at end of typename
 1b. No "ID" at end of typename
 2. each bmdValuename modified as typename + valuename (DLABtypename+valuename)
 3. a few NS_ENUM/NS_OPTIONS contains extension for easy to use ("// Non-native extension @@@@")
 */

/* =================================================================================== */
// MARK: - From DeckLinkAPIVersion.h
/* =================================================================================== */

/*
 Derived from: Blackmagic_DeckLink_SDK_12.5.1.zip @ 2023/07/03 UTC
 
 #define BLACKMAGIC_DECKLINK_API_VERSION                    0x0c050100
 #define BLACKMAGIC_DECKLINK_API_VERSION_STRING            "12.5.1"
 */

/* =================================================================================== */
// MARK: - From DeckLinkAPI.h
/* =================================================================================== */

/* Enum BMDVideoOutputFlags - Flags to control the output of ancillary data along with video. */
typedef NS_OPTIONS(uint32_t, DLABVideoOutputFlag)
{
    DLABVideoOutputFlagDefault                                    = 0,
    DLABVideoOutputFlagVANC                                           = 1 << 0,
    DLABVideoOutputFlagVITC                                           = 1 << 1,
    DLABVideoOutputFlagRP188                                          = 1 << 2,
    DLABVideoOutputFlagDualStream3D                                   = 1 << 4,
    DLABVideoOutputFlagSynchronizeToPlaybackGroup                     = 1 << 6
};

/* Enum BMDSupportedVideoModeFlags - Flags to describe supported video modes */
typedef NS_OPTIONS(uint32_t, DLABSupportedVideoModeFlag)
{
    DLABSupportedVideoModeFlagDefault                                 = 0,
    DLABSupportedVideoModeFlagKeying                                  = 1 << 0,
    DLABSupportedVideoModeFlagDualStream3D                            = 1 << 1,
    DLABSupportedVideoModeFlagSDISingleLink                           = 1 << 2,
    DLABSupportedVideoModeFlagSDIDualLink                             = 1 << 3,
    DLABSupportedVideoModeFlagSDIQuadLink                             = 1 << 4,
    DLABSupportedVideoModeFlagInAnyProfile                            = 1 << 5
};

/* Enum BMDPacketType - Type of packet */
typedef NS_ENUM(uint32_t, DLABPacketType)
{
    DLABPacketTypeStreamInterruptedMarker                         = /* 'sint' */ 0x73696E74,    // A packet of this type marks the time when a video stream was interrupted, for example by a disconnected cable
    DLABPacketTypeStreamData                                      = /* 'sdat' */ 0x73646174    // Regular stream data
};

/* Enum BMDFrameFlags - Frame flags */
typedef NS_OPTIONS(uint32_t, DLABFrameFlag)
{
    DLABFrameFlagDefault                                          = 0,
    DLABFrameFlagFlipVertical                                     = 1 << 0,
    DLABFrameFlagContainsHDRMetadata                                  = 1 << 1,
    
    /* Flags that are applicable only to instances of IDeckLinkVideoInputFrame */
    
    DLABFrameFlagCapturedAsPsF                                        = 1 << 30,
    DLABFrameFlagHasNoInputSource                                     = 1U << 31     // Non-native extension @@@@
};

/* Enum BMDVideoInputFlags - Flags applicable to video input */
typedef NS_OPTIONS(uint32_t, DLABVideoInputFlag)
{
    DLABVideoInputFlagDefault                                     = 0,
    DLABVideoInputFlagEnableFormatDetection                           = 1 << 0,
    DLABVideoInputFlagDualStream3D                                    = 1 << 1,
    DLABVideoInputFlagSynchronizeToCaptureGroup                       = 1 << 2
};

/* Enum BMDVideoInputFormatChangedEvents - Bitmask passed to the VideoInputFormatChanged notification to identify the properties of the input signal that have changed */
typedef NS_OPTIONS(uint32_t, DLABVideoInputFormatChangedEvent)
{
    DLABVideoInputFormatChangedEventDisplayModeChanged                              = 1 << 0,
    DLABVideoInputFormatChangedEventFieldDominanceChanged                           = 1 << 1,
    DLABVideoInputFormatChangedEventColorspaceChanged                               = 1 << 2
};

/* Enum BMDDetectedVideoInputFormatFlags - Flags passed to the VideoInputFormatChanged notification to describe the detected video input signal */
typedef NS_OPTIONS(uint32_t, DLABDetectedVideoInputFormatFlag)
{
    DLABDetectedVideoInputFormatFlagYCbCr422                                = 1 << 0,
    DLABDetectedVideoInputFormatFlagRGB444                                  = 1 << 1,
    DLABDetectedVideoInputFormatFlagDualStream3D                            = 1 << 2,
    DLABDetectedVideoInputFormatFlag12BitDepth                              = 1 << 3,
    DLABDetectedVideoInputFormatFlag10BitDepth                              = 1 << 4,
    DLABDetectedVideoInputFormatFlag8BitDepth                               = 1 << 5
};

/* Enum BMDDeckLinkCapturePassthroughMode - Enumerates whether the video output is electrically connected to the video input or if the clean switching mode is enabled */
typedef NS_ENUM(uint32_t, DLABDeckLinkCapturePassthroughMode)
{
    DLABDeckLinkCapturePassthroughModeDisabled                    = /* 'pdis' */ 0x70646973,
    DLABDeckLinkCapturePassthroughModeDirect                      = /* 'pdir' */ 0x70646972,
    DLABDeckLinkCapturePassthroughModeCleanSwitch                 = /* 'pcln' */ 0x70636C6E
};

/* Enum BMDOutputFrameCompletionResult - Frame Completion Callback */
typedef NS_ENUM(uint32_t, DLABOutputFrameCompletionResult)
{
    DLABOutputFrameCompletionResultCompleted,
    DLABOutputFrameCompletionResultDisplayedLate,
    DLABOutputFrameCompletionResultDropped,
    DLABOutputFrameCompletionResultFlushed
};

/* Enum BMDReferenceStatus - GenLock input status */
typedef NS_OPTIONS(uint32_t, DLABReferenceStatus)
{
    DLABReferenceStatusUnlocked                                         = 0,
    DLABReferenceStatusNotSupportedByHardware                           = 1 << 0,
    DLABReferenceStatusLocked                                           = 1 << 1
};

/* Enum BMDAudioFormat - Audio Format */
typedef NS_ENUM(uint32_t, DLABAudioFormat)
{
    DLABAudioFormatPCM                                            = /* 'lpcm' */ 0x6C70636D    // Linear signed PCM samples
};

/* Enum BMDAudioSampleRate - Audio sample rates supported for output/input */
typedef NS_ENUM(uint32_t, DLABAudioSampleRate)
{
    DLABAudioSampleRate48kHz                                      = 48000
};

/* Enum BMDAudioSampleType - Audio sample sizes supported for output/input */
typedef NS_ENUM(uint32_t, DLABAudioSampleType)
{
    DLABAudioSampleType16bitInteger                               = 16,
    DLABAudioSampleType32bitInteger                               = 32
};

/* Enum BMDAudioOutputStreamType - Audio output stream type */
typedef NS_ENUM(uint32_t, DLABAudioOutputStreamType)
{
    DLABAudioOutputStreamTypeContinuous,
    DLABAudioOutputStreamTypeContinuousDontResample,
    DLABAudioOutputStreamTypeTimestamped
};

/* Enum BMDAncillaryPacketFormat - Ancillary packet format */
typedef NS_ENUM(uint32_t, DLABAncillaryPacketFormat)
{
    DLABAncillaryPacketFormatUInt8                                = /* 'ui08' */ 0x75693038,
    DLABAncillaryPacketFormatUInt16                               = /* 'ui16' */ 0x75693136,
    DLABAncillaryPacketFormatYCbCr10                              = /* 'v210' */ 0x76323130
};

/* Enum BMDTimecodeFormat - Timecode formats for frame metadata */
typedef NS_ENUM(uint32_t, DLABTimecodeFormat)
{
    DLABTimecodeFormatRP188VITC1                                        = /* 'rpv1' */ 0x72707631,    // RP188 timecode where DBB1 equals VITC1 (line 9)
    DLABTimecodeFormatRP188VITC2                                        = /* 'rp12' */ 0x72703132,    // RP188 timecode where DBB1 equals VITC2 (line 9 for progressive or line 571 for interlaced/PsF)
    DLABTimecodeFormatRP188LTC                                          = /* 'rplt' */ 0x72706C74,    // RP188 timecode where DBB1 equals LTC (line 10)
    DLABTimecodeFormatRP188HighFrameRate                                = /* 'rphr' */ 0x72706872,    // RP188 timecode where DBB1 is an HFRTC (SMPTE ST 12-3), the only timecode allowing the frame value to go above 30
    DLABTimecodeFormatRP188Any                                          = /* 'rp18' */ 0x72703138,    // Convenience for capture, returning the first valid timecode in {HFRTC (if supported), VITC1, VITC2, LTC }
    DLABTimecodeFormatVITC                                              = /* 'vitc' */ 0x76697463,
    DLABTimecodeFormatVITCField2                                        = /* 'vit2' */ 0x76697432,
    DLABTimecodeFormatSerial                                            = /* 'seri' */ 0x73657269
};

/* Enum BMDAnalogVideoFlags - Analog video display flags */
typedef NS_OPTIONS(uint32_t, DLABAnalogVideoFlag)
{
    DLABAnalogVideoFlagCompositeSetup75                           = 1 << 0,
    DLABAnalogVideoFlagComponentBetacamLevels                     = 1 << 1
};

/* Enum BMDAudioOutputAnalogAESSwitch - Audio output Analog/AESEBU switch */
typedef NS_ENUM(uint32_t, DLABAudioOutputSwitch)
{
    DLABAudioOutputSwitchAESEBU                                   = /* 'aes ' */ 0x61657320,
    DLABAudioOutputSwitchAnalog                                   = /* 'anlg' */ 0x616E6C67
};

/* Enum BMDVideoOutputConversionMode - Video/audio conversion mode */
typedef NS_ENUM(uint32_t, DLABVideoOutputConversionMode)
{
    DLABVideoOutputConversionModeNone                                   = /* 'none' */ 0x6E6F6E65,
    DLABVideoOutputConversionModeLetterboxDownconversion                        = /* 'ltbx' */ 0x6C746278,
    DLABVideoOutputConversionModeAnamorphicDownconversion                       = /* 'amph' */ 0x616D7068,
    DLABVideoOutputConversionModeHD720toHD1080Conversion                        = /* '720c' */ 0x37323063,
    DLABVideoOutputConversionModeHardwareLetterboxDownconversion                = /* 'HWlb' */ 0x48576C62,
    DLABVideoOutputConversionModeHardwareAnamorphicDownconversion               = /* 'HWam' */ 0x4857616D,
    DLABVideoOutputConversionModeHardwareCenterCutDownconversion                = /* 'HWcc' */ 0x48576363,
    DLABVideoOutputConversionModeHardware720p1080pCrossconversion               = /* 'xcap' */ 0x78636170,
    DLABVideoOutputConversionModeHardwareAnamorphic720pUpconversion             = /* 'ua7p' */ 0x75613770,
    DLABVideoOutputConversionModeHardwareAnamorphic1080iUpconversion            = /* 'ua1i' */ 0x75613169,
    DLABVideoOutputConversionModeHardwareAnamorphic149To720pUpconversion        = /* 'u47p' */ 0x75343770,
    DLABVideoOutputConversionModeHardwareAnamorphic149To1080iUpconversion       = /* 'u41i' */ 0x75343169,
    DLABVideoOutputConversionModeHardwarePillarbox720pUpconversion              = /* 'up7p' */ 0x75703770,
    DLABVideoOutputConversionModeHardwarePillarbox1080iUpconversion             = /* 'up1i' */ 0x75703169
};

/* Enum BMDVideoInputConversionMode - Video input conversion mode */
typedef NS_ENUM(uint32_t, DLABVideoInputConversionMode)
{
    DLABVideoInputConversionModeNone                                    = /* 'none' */ 0x6E6F6E65,
    DLABVideoInputConversionModeLetterboxDownconversionFromHD1080               = /* '10lb' */ 0x31306C62,
    DLABVideoInputConversionModeAnamorphicDownconversionFromHD1080              = /* '10am' */ 0x3130616D,
    DLABVideoInputConversionModeLetterboxDownconversionFromHD720                = /* '72lb' */ 0x37326C62,
    DLABVideoInputConversionModeAnamorphicDownconversionFromHD720               = /* '72am' */ 0x3732616D,
    DLABVideoInputConversionModeLetterboxUpconversion                           = /* 'lbup' */ 0x6C627570,
    DLABVideoInputConversionModeAnamorphicUpconversion                          = /* 'amup' */ 0x616D7570
};

/* Enum BMDVideo3DPackingFormat - Video 3D packing format */
typedef NS_ENUM(uint32_t, DLABVideo3DPackingFormat)
{
    DLABVideo3DPackingFormatSidebySideHalf                              = /* 'sbsh' */ 0x73627368,
    DLABVideo3DPackingFormatLinebyLine                                  = /* 'lbyl' */ 0x6C62796C,
    DLABVideo3DPackingFormatTopAndBottom                                = /* 'tabo' */ 0x7461626F,
    DLABVideo3DPackingFormatFramePacking                                = /* 'frpk' */ 0x6672706B,
    DLABVideo3DPackingFormatLeftOnly                                    = /* 'left' */ 0x6C656674,
    DLABVideo3DPackingFormatRightOnly                                   = /* 'righ' */ 0x72696768
};

/* Enum BMDIdleVideoOutputOperation - Video output operation when not playing video */
typedef NS_ENUM(uint32_t, DLABIdleVideoOutputOperation)
{
    DLABIdleVideoOutputOperationBlack                                      = /* 'blac' */ 0x626C6163,
    DLABIdleVideoOutputOperationLastFrame                                  = /* 'lafa' */ 0x6C616661
};

/* Enum BMDVideoEncoderFrameCodingMode - Video frame coding mode */
typedef NS_ENUM(uint32_t, DLABVideoEncoderFrameCodingMode)
{
    DLABVideoEncoderFrameCodingModeInter                          = /* 'inte' */ 0x696E7465,
    DLABVideoEncoderFrameCodingModeIntra                          = /* 'intr' */ 0x696E7472
};

/* Enum BMDDNxHRLevel - DNxHR Levels */
typedef NS_ENUM(uint32_t, DLABDNxHRLevel)
{
    DLABDNxHRLevelSQ                                              = /* 'dnsq' */ 0x646E7371,
    DLABDNxHRLevelLB                                              = /* 'dnlb' */ 0x646E6C62,
    DLABDNxHRLevelHQ                                              = /* 'dnhq' */ 0x646E6871,
    DLABDNxHRLevelHQX                                             = /* 'dhqx' */ 0x64687178,
    DLABDNxHRLevel444                                             = /* 'd444' */ 0x64343434
};

/* Enum BMDLinkConfiguration - Video link configuration */
typedef NS_ENUM(uint32_t, DLABLinkConfiguration)
{
    DLABLinkConfigurationSingleLink                               = /* 'lcsl' */ 0x6C63736C,
    DLABLinkConfigurationDualLink                                 = /* 'lcdl' */ 0x6C63646C,
    DLABLinkConfigurationQuadLink                                 = /* 'lcql' */ 0x6C63716C
};

/* Enum BMDDeviceInterface - Device interface type */
typedef NS_ENUM(uint32_t, DLABDeviceInterface)
{
    DLABDeviceInterfacePCI                                        = /* 'pci ' */ 0x70636920,
    DLABDeviceInterfaceUSB                                        = /* 'usb ' */ 0x75736220,
    DLABDeviceInterfaceThunderbolt                                = /* 'thun' */ 0x7468756E
};

/* Enum BMDColorspace - Colorspace */
typedef NS_ENUM(uint32_t, DLABColorspace)
{
    DLABColorspaceRec601                                          = /* 'r601' */ 0x72363031,
    DLABColorspaceRec709                                          = /* 'r709' */ 0x72373039,
    DLABColorspaceRec2020                                         = /* '2020' */ 0x32303230
};

/* Enum BMDDynamicRange - SDR or HDR */
typedef NS_ENUM(uint32_t, DLABDynamicRange)
{
    DLABDynamicRangeSDR                                           = 0,          // Standard Dynamic Range in accordance with SMPTE ST 2036-1
    DLABDynamicRangeHDRStaticPQ                                   = 1 << 29,    // High Dynamic Range PQ in accordance with SMPTE ST 2084
    DLABDynamicRangeHDRStaticHLG                                  = 1 << 30     // High Dynamic Range HLG in accordance with ITU-R BT.2100-0
};

/* Enum BMDDeckLinkHDMIInputEDIDID - DeckLink HDMI Input EDID ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkHDMIInputEDID)
{
    
    /* Integers */
    
    DLABDeckLinkHDMIInputEDIDDynamicRange                         = /* 'HIDy' */ 0x48494479    // Parameter is of type BMDDynamicRange. Default is (bmdDynamicRangeSDR|bmdDynamicRangeHDRStaticPQ)
};

/* Enum BMDDeckLinkFrameMetadataID - DeckLink Frame Metadata ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkFrameMetadata)
{
    
    /* Colorspace Metadata - Integers */
    
    DLABDeckLinkFrameMetadataColorspace                           = /* 'cspc' */ 0x63737063,    // Colorspace of video frame (see BMDColorspace)
    
    /* HDR Metadata - Integers */
    
    DLABDeckLinkFrameMetadataHDRElectroOpticalTransferFunc        = /* 'eotf' */ 0x656F7466,    // EOTF in range 0-7 as per CEA 861.3
    
    /* HDR Metadata - Floats */
    
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesRedX              = /* 'hdrx' */ 0x68647278,    // Red display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesRedY              = /* 'hdry' */ 0x68647279,    // Red display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesGreenX            = /* 'hdgx' */ 0x68646778,    // Green display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesGreenY            = /* 'hdgy' */ 0x68646779,    // Green display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesBlueX             = /* 'hdbx' */ 0x68646278,    // Blue display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesBlueY             = /* 'hdby' */ 0x68646279,    // Blue display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRWhitePointX                       = /* 'hdwx' */ 0x68647778,    // White point in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRWhitePointY                       = /* 'hdwy' */ 0x68647779,    // White point in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance      = /* 'hdml' */ 0x68646D6C,    // Max display mastering luminance in range 1 cd/m2 - 65535 cd/m2
    DLABDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance      = /* 'hmil' */ 0x686D696C,    // Min display mastering luminance in range 0.0001 cd/m2 - 6.5535 cd/m2
    DLABDeckLinkFrameMetadataHDRMaximumContentLightLevel          = /* 'mcll' */ 0x6D636C6C,    // Maximum Content Light Level in range 1 cd/m2 - 65535 cd/m2
    DLABDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel     = /* 'fall' */ 0x66616C6C,    // Maximum Frame Average Light Level in range 1 cd/m2 - 65535 cd/m2
};

/* Enum BMDProfileID - Identifies a profile */
typedef NS_ENUM(uint32_t, DLABProfile)
{
    DLABProfileOneSubDeviceFullDuplex                             = /* '1dfd' */ 0x31646664,
    DLABProfileOneSubDeviceHalfDuplex                             = /* '1dhd' */ 0x31646864,
    DLABProfileTwoSubDevicesFullDuplex                            = /* '2dfd' */ 0x32646664,
    DLABProfileTwoSubDevicesHalfDuplex                            = /* '2dhd' */ 0x32646864,
    DLABProfileFourSubDevicesHalfDuplex                           = /* '4dhd' */ 0x34646864
};

/* Enum BMDHDMITimecodePacking - Packing form of timecode on HDMI */
typedef NS_ENUM(uint32_t, DLABHDMITimecodePacking)
{
    DLABHDMITimecodePackingIEEEOUI000085                          = 0x00008500,
    DLABHDMITimecodePackingIEEEOUI080046                          = 0x08004601,
    DLABHDMITimecodePackingIEEEOUI5CF9F0                          = 0x5CF9F003
};

/* Enum BMDInternalKeyingAncillaryDataSource - Source for VANC and timecode data when performing internal keying */
typedef NS_ENUM(uint32_t, DLABInternalKeyingAncillaryDataSource)
{
    DLABInternalKeyingAncillaryDataSourceFromInputSignal            = /* 'ikai' */ 0x696B6169,
    DLABInternalKeyingAncillaryDataSourceFromKeyFrame               = /* 'ikak' */ 0x696B616B
};

/* Enum BMDDeckLinkAttributeID - DeckLink Attribute ID */
typedef NS_ENUM(uint32_t, DLABAttribute)
{
    /* Flags */
    
    DLABAttributeSupportsInternalKeying                            = /* 'keyi' */ 0x6B657969,
    DLABAttributeSupportsExternalKeying                            = /* 'keye' */ 0x6B657965,
    DLABAttributeSupportsInputFormatDetection                      = /* 'infd' */ 0x696E6664,
    DLABAttributeHasReferenceInput                                 = /* 'hrin' */ 0x6872696E,
    DLABAttributeHasSerialPort                                     = /* 'hspt' */ 0x68737074,
    DLABAttributeHasAnalogVideoOutputGain                          = /* 'avog' */ 0x61766F67,
    DLABAttributeCanOnlyAdjustOverallVideoOutputGain               = /* 'ovog' */ 0x6F766F67,
    DLABAttributeHasVideoInputAntiAliasingFilter                   = /* 'aafl' */ 0x6161666C,
    DLABAttributeHasBypass                                         = /* 'byps' */ 0x62797073,
    DLABAttributeSupportsClockTimingAdjustment                     = /* 'ctad' */ 0x63746164,
    DLABAttributeSupportsFullFrameReferenceInputTimingOffset       = /* 'frin' */ 0x6672696E,
    DLABAttributeSupportsSMPTELevelAOutput                         = /* 'lvla' */ 0x6C766C61,
    DLABAttributeSupportsAutoSwitchingPPsFOnInput                  = /* 'apsf' */ 0x61707366,
    DLABAttributeSupportsDualLinkSDI                               = /* 'sdls' */ 0x73646C73,
    DLABAttributeSupportsQuadLinkSDI                               = /* 'sqls' */ 0x73716C73,
    DLABAttributeSupportsIdleOutput                                = /* 'idou' */ 0x69646F75,
    DLABAttributeVANCRequires10BitYUVVideoFrames                   = /* 'vioY' */ 0x76696F59,    // Legacy product requires v210 active picture for IDeckLinkVideoFrameAncillaryPackets or 10-bit VANC
    DLABAttributeHasLTCTimecodeInput                               = /* 'hltc' */ 0x686C7463,
    DLABAttributeSupportsHDRMetadata                               = /* 'hdrm' */ 0x6864726D,
    DLABAttributeSupportsColorspaceMetadata                        = /* 'cmet' */ 0x636D6574,
    DLABAttributeSupportsHDMITimecode                              = /* 'htim' */ 0x6874696D,
    DLABAttributeSupportsHighFrameRateTimecode                     = /* 'HFRT' */ 0x48465254,
    DLABAttributeSupportsSynchronizeToCaptureGroup                 = /* 'stcg' */ 0x73746367,
    DLABAttributeSupportsSynchronizeToPlaybackGroup                = /* 'stpg' */ 0x73747067,
    
    /* Integers */
    
    DLABAttributeMaximumAudioChannels                              = /* 'mach' */ 0x6D616368,
    DLABAttributeMaximumAnalogAudioInputChannels                   = /* 'iach' */ 0x69616368,
    DLABAttributeMaximumAnalogAudioOutputChannels                  = /* 'aach' */ 0x61616368,
    DLABAttributeNumberOfSubDevices                                = /* 'nsbd' */ 0x6E736264,
    DLABAttributeSubDeviceIndex                                    = /* 'subi' */ 0x73756269,
    DLABAttributePersistentID                                      = /* 'peid' */ 0x70656964,
    DLABAttributeDeviceGroupID                                     = /* 'dgid' */ 0x64676964,
    DLABAttributeTopologicalID                                     = /* 'toid' */ 0x746F6964,
    DLABAttributeVideoOutputConnections                            = /* 'vocn' */ 0x766F636E,    // Returns a BMDVideoConnection bit field
    DLABAttributeVideoInputConnections                             = /* 'vicn' */ 0x7669636E,    // Returns a BMDVideoConnection bit field
    DLABAttributeAudioOutputConnections                            = /* 'aocn' */ 0x616F636E,    // Returns a BMDAudioConnection bit field
    DLABAttributeAudioInputConnections                             = /* 'aicn' */ 0x6169636E,    // Returns a BMDAudioConnection bit field
    DLABAttributeVideoIOSupport                                    = /* 'vios' */ 0x76696F73,    // Returns a BMDVideoIOSupport bit field
    DLABAttributeDeckControlConnections                            = /* 'dccn' */ 0x6463636E,    // Returns a BMDDeckControlConnection bit field
    DLABAttributeDeviceInterface                                   = /* 'dbus' */ 0x64627573,    // Returns a BMDDeviceInterface
    DLABAttributeAudioInputRCAChannelCount                         = /* 'airc' */ 0x61697263,
    DLABAttributeAudioInputXLRChannelCount                         = /* 'aixc' */ 0x61697863,
    DLABAttributeAudioOutputRCAChannelCount                        = /* 'aorc' */ 0x616F7263,
    DLABAttributeAudioOutputXLRChannelCount                        = /* 'aoxc' */ 0x616F7863,
    DLABAttributeProfileID                                         = /* 'prid' */ 0x70726964,    // Returns a BMDProfileID
    DLABAttributeDuplex                                            = /* 'dupx' */ 0x64757078,
    DLABAttributeMinimumPrerollFrames                              = /* 'mprf' */ 0x6D707266,
    DLABAttributeSupportedDynamicRange                             = /* 'sudr' */ 0x73756472,
    
    /* Floats */
    
    DLABAttributeVideoInputGainMinimum                             = /* 'vigm' */ 0x7669676D,
    DLABAttributeVideoInputGainMaximum                             = /* 'vigx' */ 0x76696778,
    DLABAttributeVideoOutputGainMinimum                            = /* 'vogm' */ 0x766F676D,
    DLABAttributeVideoOutputGainMaximum                            = /* 'vogx' */ 0x766F6778,
    DLABAttributeMicrophoneInputGainMinimum                        = /* 'migm' */ 0x6D69676D,
    DLABAttributeMicrophoneInputGainMaximum                        = /* 'migx' */ 0x6D696778,
    
    /* Strings */
    
    DLABAttributeSerialPortDeviceName                              = /* 'slpn' */ 0x736C706E,
    DLABAttributeVendorName                                        = /* 'vndr' */ 0x766E6472,
    DLABAttributeDisplayName                                       = /* 'dspn' */ 0x6473706E,
    DLABAttributeModelName                                         = /* 'mdln' */ 0x6D646C6E,
    DLABAttributeDeviceHandle                                      = /* 'devh' */ 0x64657668
};

/* Enum BMDDeckLinkAPIInformationID - DeckLinkAPI information ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkAPIInformation)
{
    
    /* Integer or String */
    
    DLABDeckLinkAPIInformationVersion                                        = /* 'vers' */ 0x76657273
};

/* Enum BMDDeckLinkStatusID - DeckLink Status ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkStatus)
{
    /* Integers */
    
    DLABDeckLinkStatusDetectedVideoInputMode                      = /* 'dvim' */ 0x6476696D,
    DLABDeckLinkStatusDetectedVideoInputFormatFlags               = /* 'dvff' */ 0x64766666,
    DLABDeckLinkStatusDetectedVideoInputFieldDominance            = /* 'dvfd' */ 0x64766664,
    DLABDeckLinkStatusDetectedVideoInputColorspace                = /* 'dscl' */ 0x6473636C,
    DLABDeckLinkStatusDetectedVideoInputDynamicRange              = /* 'dsdr' */ 0x64736472,
    DLABDeckLinkStatusDetectedSDILinkConfiguration                = /* 'dslc' */ 0x64736C63,
    DLABDeckLinkStatusCurrentVideoInputMode                       = /* 'cvim' */ 0x6376696D,
    DLABDeckLinkStatusCurrentVideoInputPixelFormat                = /* 'cvip' */ 0x63766970,
    DLABDeckLinkStatusCurrentVideoInputFlags                      = /* 'cvif' */ 0x63766966,
    DLABDeckLinkStatusCurrentVideoOutputMode                      = /* 'cvom' */ 0x63766F6D,
    DLABDeckLinkStatusCurrentVideoOutputFlags                     = /* 'cvof' */ 0x63766F66,
    DLABDeckLinkStatusPCIExpressLinkWidth                         = /* 'pwid' */ 0x70776964,
    DLABDeckLinkStatusPCIExpressLinkSpeed                         = /* 'plnk' */ 0x706C6E6B,
    DLABDeckLinkStatusLastVideoOutputPixelFormat                  = /* 'opix' */ 0x6F706978,
    DLABDeckLinkStatusReferenceSignalMode                         = /* 'refm' */ 0x7265666D,
    DLABDeckLinkStatusReferenceSignalFlags                        = /* 'reff' */ 0x72656666,
    DLABDeckLinkStatusBusy                                        = /* 'busy' */ 0x62757379,
    DLABDeckLinkStatusInterchangeablePanelType                    = /* 'icpt' */ 0x69637074,
    DLABDeckLinkStatusDeviceTemperature                           = /* 'dtmp' */ 0x64746D70,
    
    /* Flags */
    
    DLABDeckLinkStatusVideoInputSignalLocked                      = /* 'visl' */ 0x7669736C,
    DLABDeckLinkStatusReferenceSignalLocked                       = /* 'refl' */ 0x7265666C,
    
    /* Bytes */
    
    DLABDeckLinkStatusReceivedEDID                                = /* 'edid' */ 0x65646964
};

/* Enum BMDDeckLinkVideoStatusFlags -  */
typedef NS_OPTIONS(uint32_t, DLABDeckLinkVideoStatusFlag)
{
    DLABDeckLinkVideoStatusFlagPsF                                    = 1 << 0,
    DLABDeckLinkVideoStatusFlagDualStream3D                           = 1 << 1
};

/* Enum BMDDuplexMode - Duplex of the device */
typedef NS_ENUM(uint32_t, DLABDuplexMode)
{
    DLABDuplexModeFull                                                = /* 'dxfu' */ 0x64786675,
    DLABDuplexModeHalf                                                = /* 'dxha' */ 0x64786861,
    DLABDuplexModeSimplex                                             = /* 'dxsp' */ 0x64787370,
    DLABDuplexModeInactive                                            = /* 'dxin' */ 0x6478696E
};

/* Enum BMDPanelType - The type of interchangeable panel */
typedef NS_ENUM(uint32_t, DLABPanelType)
{
    DLABPanelTypeNotDetected                                          = /* 'npnl' */ 0x6E706E6C,
    DLABPanelTypeTeranexMiniSmartPanel                                = /* 'tmsm' */ 0x746D736D
};

/* Enum BMDDeviceBusyState - Current device busy state */
typedef NS_OPTIONS(uint32_t, DLABDeviceBusyState)
{
    DLABDeviceBusyStateCaptureBusy                                         = 1 << 0,
    DLABDeviceBusyStatePlaybackBusy                                        = 1 << 1,
    DLABDeviceBusyStateSerialPortBusy                                      = 1 << 2
};

/* Enum BMDVideoIOSupport - Device video input/output support */
typedef NS_OPTIONS(uint32_t, DLABVideoIOSupport)
{
    DLABVideoIOSupportNone = 0,             // Non-native extension @@@@
    
    DLABVideoIOSupportCapture                                     = 1 << 0,
    DLABVideoIOSupportPlayback                                    = 1 << 1
    
    , DLABVideoIOSupportInternalKeying = 1 << 16     // Non-native extension @@@@
    , DLABVideoIOSupportExternalKeying = 1 << 17     // Non-native extension @@@@
};

/* Enum BMD3DPreviewFormat - Linked Frame preview format */
typedef NS_ENUM(uint32_t, DLAB3DPreviewFormat)
{
    DLAB3DPreviewFormatDefault                                    = /* 'defa' */ 0x64656661,
    DLAB3DPreviewFormatLeftOnly                                   = /* 'left' */ 0x6C656674,
    DLAB3DPreviewFormatRightOnly                                  = /* 'righ' */ 0x72696768,
    DLAB3DPreviewFormatSideBySide                                 = /* 'side' */ 0x73696465,
    DLAB3DPreviewFormatTopBottom                                  = /* 'topb' */ 0x746F7062
};

/* Enum BMDNotifications - Events that can be subscribed through IDeckLinkNotification */
typedef NS_ENUM(uint32_t, DLABNotification)
{
    DLABNotificationPreferencesChanged                                        = /* 'pref' */ 0x70726566,
    DLABNotificationStatusChanged                                             = /* 'stat' */ 0x73746174
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIConfiguration.h
/* =================================================================================== */

/* Enum BMDDeckLinkConfigurationID - DeckLink Configuration ID */
typedef NS_ENUM(uint32_t, DLABConfiguration)
{
    /* Serial port Flags */
    
    DLABConfigurationSwapSerialRxTx                              = /* 'ssrt' */ 0x73737274,
    
    /* Video Input/Output Integers */
    
    DLABConfigurationHDMI3DPackingFormat                         = /* '3dpf' */ 0x33647066,
    DLABConfigurationBypass                                      = /* 'byps' */ 0x62797073,
    DLABConfigurationClockTimingAdjustment                       = /* 'ctad' */ 0x63746164,
    
    /* Audio Input/Output Flags */
    
    DLABConfigurationAnalogAudioConsumerLevels                   = /* 'aacl' */ 0x6161636C,
    DLABConfigurationSwapHDMICh3AndCh4OnInput                    = /* 'hi34' */ 0x68693334,
    DLABConfigurationSwapHDMICh3AndCh4OnOutput                   = /* 'ho34' */ 0x686F3334,
    
    /* Video Output flags */
    
    DLABConfigurationFieldFlickerRemoval                         = /* 'fdfr' */ 0x66646672,
    DLABConfigurationHD1080p24ToHD1080i5994Conversion            = /* 'to59' */ 0x746F3539,
    DLABConfiguration444SDIVideoOutput                           = /* '444o' */ 0x3434346F,
    DLABConfigurationBlackVideoOutputDuringCapture               = /* 'bvoc' */ 0x62766F63,
    DLABConfigurationLowLatencyVideoOutput                       = /* 'llvo' */ 0x6C6C766F,
    DLABConfigurationDownConversionOnAllAnalogOutput             = /* 'caao' */ 0x6361616F,
    DLABConfigurationSMPTELevelAOutput                           = /* 'smta' */ 0x736D7461,
    DLABConfigurationRec2020Output                               = /* 'rec2' */ 0x72656332,    // Ensure output is Rec.2020 colorspace
    DLABConfigurationQuadLinkSDIVideoOutputSquareDivisionSplit   = /* 'SDQS' */ 0x53445153,
    DLABConfigurationOutput1080pAsPsF                            = /* 'pfpr' */ 0x70667072,
    
    /* Video Output Integers */
    
    DLABConfigurationVideoOutputConnection                       = /* 'vocn' */ 0x766F636E,
    DLABConfigurationVideoOutputConversionMode                   = /* 'vocm' */ 0x766F636D,
    DLABConfigurationAnalogVideoOutputFlags                      = /* 'avof' */ 0x61766F66,
    DLABConfigurationReferenceInputTimingOffset                  = /* 'glot' */ 0x676C6F74,
    DLABConfigurationVideoOutputIdleOperation                    = /* 'voio' */ 0x766F696F,
    DLABConfigurationDefaultVideoOutputMode                      = /* 'dvom' */ 0x64766F6D,
    DLABConfigurationDefaultVideoOutputModeFlags                 = /* 'dvof' */ 0x64766F66,
    DLABConfigurationSDIOutputLinkConfiguration                  = /* 'solc' */ 0x736F6C63,
    DLABConfigurationHDMITimecodePacking                         = /* 'htpk' */ 0x6874706B,
    DLABConfigurationPlaybackGroup                               = /* 'plgr' */ 0x706C6772,
    
    /* Video Output Floats */
    
    DLABConfigurationVideoOutputComponentLumaGain                = /* 'oclg' */ 0x6F636C67,
    DLABConfigurationVideoOutputComponentChromaBlueGain          = /* 'occb' */ 0x6F636362,
    DLABConfigurationVideoOutputComponentChromaRedGain           = /* 'occr' */ 0x6F636372,
    DLABConfigurationVideoOutputCompositeLumaGain                = /* 'oilg' */ 0x6F696C67,
    DLABConfigurationVideoOutputCompositeChromaGain              = /* 'oicg' */ 0x6F696367,
    DLABConfigurationVideoOutputSVideoLumaGain                   = /* 'oslg' */ 0x6F736C67,
    DLABConfigurationVideoOutputSVideoChromaGain                 = /* 'oscg' */ 0x6F736367,
    
    /* Video Input Flags */
    
    DLABConfigurationVideoInputScanning                          = /* 'visc' */ 0x76697363,    // Applicable to H264 Pro Recorder only
    DLABConfigurationUseDedicatedLTCInput                        = /* 'dltc' */ 0x646C7463,    // Use timecode from LTC input instead of SDI stream
    DLABConfigurationSDIInput3DPayloadOverride                   = /* '3dds' */ 0x33646473,
    DLABConfigurationCapture1080pAsPsF                           = /* 'cfpr' */ 0x63667072,
    
    /* Video Input Integers */
    
    DLABConfigurationVideoInputConnection                        = /* 'vicn' */ 0x7669636E,
    DLABConfigurationAnalogVideoInputFlags                       = /* 'avif' */ 0x61766966,
    DLABConfigurationVideoInputConversionMode                    = /* 'vicm' */ 0x7669636D,
    DLABConfiguration32PulldownSequenceInitialTimecodeFrame      = /* 'pdif' */ 0x70646966,
    DLABConfigurationVANCSourceLine1Mapping                      = /* 'vsl1' */ 0x76736C31,
    DLABConfigurationVANCSourceLine2Mapping                      = /* 'vsl2' */ 0x76736C32,
    DLABConfigurationVANCSourceLine3Mapping                      = /* 'vsl3' */ 0x76736C33,
    DLABConfigurationCapturePassThroughMode                      = /* 'cptm' */ 0x6370746D,
    DLABConfigurationCaptureGroup                                = /* 'cpgr' */ 0x63706772,
    
    /* Video Input Floats */
    
    DLABConfigurationVideoInputComponentLumaGain                 = /* 'iclg' */ 0x69636C67,
    DLABConfigurationVideoInputComponentChromaBlueGain           = /* 'iccb' */ 0x69636362,
    DLABConfigurationVideoInputComponentChromaRedGain            = /* 'iccr' */ 0x69636372,
    DLABConfigurationVideoInputCompositeLumaGain                 = /* 'iilg' */ 0x69696C67,
    DLABConfigurationVideoInputCompositeChromaGain               = /* 'iicg' */ 0x69696367,
    DLABConfigurationVideoInputSVideoLumaGain                    = /* 'islg' */ 0x69736C67,
    DLABConfigurationVideoInputSVideoChromaGain                  = /* 'iscg' */ 0x69736367,
    
    /* Keying Integers */
    
    DLABConfigurationInternalKeyingAncillaryDataSource           = /* 'ikas' */ 0x696B6173,
    
    /* Audio Input Flags */
    
    DLABConfigurationMicrophonePhantomPower                      = /* 'mphp' */ 0x6D706870,
    
    /* Audio Input Integers */
    
    DLABConfigurationAudioInputConnection                        = /* 'aicn' */ 0x6169636E,
    
    /* Audio Input Floats */
    
    DLABConfigurationAnalogAudioInputScaleChannel1               = /* 'ais1' */ 0x61697331,
    DLABConfigurationAnalogAudioInputScaleChannel2               = /* 'ais2' */ 0x61697332,
    DLABConfigurationAnalogAudioInputScaleChannel3               = /* 'ais3' */ 0x61697333,
    DLABConfigurationAnalogAudioInputScaleChannel4               = /* 'ais4' */ 0x61697334,
    DLABConfigurationDigitalAudioInputScale                      = /* 'dais' */ 0x64616973,
    DLABConfigurationMicrophoneInputGain                         = /* 'micg' */ 0x6D696367,
    
    /* Audio Output Integers */
    
    DLABConfigurationAudioOutputAESAnalogSwitch                  = /* 'aoaa' */ 0x616F6161,
    
    /* Audio Output Floats */
    
    DLABConfigurationAnalogAudioOutputScaleChannel1              = /* 'aos1' */ 0x616F7331,
    DLABConfigurationAnalogAudioOutputScaleChannel2              = /* 'aos2' */ 0x616F7332,
    DLABConfigurationAnalogAudioOutputScaleChannel3              = /* 'aos3' */ 0x616F7333,
    DLABConfigurationAnalogAudioOutputScaleChannel4              = /* 'aos4' */ 0x616F7334,
    DLABConfigurationDigitalAudioOutputScale                     = /* 'daos' */ 0x64616F73,
    DLABConfigurationHeadphoneVolume                             = /* 'hvol' */ 0x68766F6C,
    
    /* Device Information Strings */
    
    DLABConfigurationDeviceInformationLabel                      = /* 'dila' */ 0x64696C61,
    DLABConfigurationDeviceInformationSerialNumber               = /* 'disn' */ 0x6469736E,
    DLABConfigurationDeviceInformationCompany                    = /* 'dico' */ 0x6469636F,
    DLABConfigurationDeviceInformationPhone                      = /* 'diph' */ 0x64697068,
    DLABConfigurationDeviceInformationEmail                      = /* 'diem' */ 0x6469656D,
    DLABConfigurationDeviceInformationDate                       = /* 'dida' */ 0x64696461,
    
    /* Deck Control Integers */
    
    DLABConfigurationDeckControlConnection                       = /* 'dcco' */ 0x6463636F
};

/* Enum BMDDeckLinkEncoderConfigurationID - DeckLink Encoder Configuration ID */
typedef NS_ENUM(uint32_t, DLABEncoderConfiguration)
{
    /* Video Encoder Integers */
    
    DLABEncoderConfigurationPreferredBitDepth                    = /* 'epbr' */ 0x65706272,
    DLABEncoderConfigurationFrameCodingMode                      = /* 'efcm' */ 0x6566636D,
    
    /* HEVC/H.265 Encoder Integers */
    
    DLABEncoderConfigurationH265TargetBitrate                    = /* 'htbr' */ 0x68746272,
    
    /* DNxHR/DNxHD Compression ID */
    
    DLABEncoderConfigurationDNxHRCompressionID                   = /* 'dcid' */ 0x64636964,
    
    /* DNxHR/DNxHD Level */
    
    DLABEncoderConfigurationDNxHRLevel                           = /* 'dlev' */ 0x646C6576,
    
    /* Encoded Sample Decriptions */
    
    DLABEncoderConfigurationMPEG4SampleDescription               = /* 'stsE' */ 0x73747345,    // Full MPEG4 sample description (aka SampleEntry of an 'stsd' atom-box). Useful for MediaFoundation, QuickTime, MKV and more
    DLABEncoderConfigurationMPEG4CodecSpecificDesc               = /* 'esds' */ 0x65736473    // Sample description extensions only (atom stream, each with size and fourCC header). Useful for AVFoundation, VideoToolbox, MKV and more
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIDeckControl.h
/* =================================================================================== */

/* Enum BMDDeckControlMode - DeckControl mode */
typedef NS_ENUM(uint32_t, DLABDeckControlMode)
{
    DLABDeckControlModeNotOpened                                      = /* 'ntop' */ 0x6E746F70,
    DLABDeckControlModeVTRControlMode                                 = /* 'vtrc' */ 0x76747263,
    DLABDeckControlModeExportMode                                     = /* 'expm' */ 0x6578706D,
    DLABDeckControlModeCaptureMode                                    = /* 'capm' */ 0x6361706D
};

/* Enum BMDDeckControlEvent - DeckControl event */
typedef NS_ENUM(uint32_t, DLABDeckControlEvent)
{
    DLABDeckControlEventAbortedEvent                                   = /* 'abte' */ 0x61627465,    // This event is triggered when a capture or edit-to-tape operation is aborted.
    
    /* Export-To-Tape events */
    
    DLABDeckControlEventPrepareForExportEvent                          = /* 'pfee' */ 0x70666565,    // This event is triggered a few frames before reaching the in-point. IDeckLinkInput::StartScheduledPlayback should be called at this point.
    DLABDeckControlEventExportCompleteEvent                            = /* 'exce' */ 0x65786365,    // This event is triggered a few frames after reaching the out-point. At this point, it is safe to stop playback. Upon reception of this event the deck's control mode is set back to bmdDeckControlVTRControlMode.
    
    /* Capture events */
    
    DLABDeckControlEventPrepareForCaptureEvent                         = /* 'pfce' */ 0x70666365,    // This event is triggered a few frames before reaching the in-point. The serial timecode attached to IDeckLinkVideoInputFrames is now valid.
    DLABDeckControlEventCaptureCompleteEvent                           = /* 'ccev' */ 0x63636576    // This event is triggered a few frames after reaching the out-point. Upon receptio    n of this event the deck's control mode is set back to bmdDeckControlVTRControlMode.
};

/* Enum BMDDeckControlVTRControlState - VTR Control state */
typedef NS_ENUM(uint32_t, DLABDeckControlVTRControlState)
{
    DLABDeckControlVTRControlStateNotInVTRControlMode                            = /* 'nvcm' */ 0x6E76636D,
    DLABDeckControlVTRControlStatePlaying                              = /* 'vtrp' */ 0x76747270,
    DLABDeckControlVTRControlStateRecording                            = /* 'vtrr' */ 0x76747272,
    DLABDeckControlVTRControlStateStill                                = /* 'vtra' */ 0x76747261,
    DLABDeckControlVTRControlStateShuttleForward                       = /* 'vtsf' */ 0x76747366,
    DLABDeckControlVTRControlStateShuttleReverse                       = /* 'vtsr' */ 0x76747372,
    DLABDeckControlVTRControlStateJogForward                           = /* 'vtjf' */ 0x76746A66,
    DLABDeckControlVTRControlStateJogReverse                           = /* 'vtjr' */ 0x76746A72,
    DLABDeckControlVTRControlStateStopped                              = /* 'vtro' */ 0x7674726F
};

/* Enum BMDDeckControlStatusFlags - Deck Control status flags */
typedef NS_OPTIONS(uint32_t, DLABDeckControlStatusFlag)
{
    DLABDeckControlStatusFlagDeckConnected                            = 1 << 0,
    DLABDeckControlStatusFlagRemoteMode                               = 1 << 1,
    DLABDeckControlStatusFlagRecordInhibited                          = 1 << 2,
    DLABDeckControlStatusFlagCassetteOut                              = 1 << 3
};

/* Enum BMDDeckControlExportModeOpsFlags - Export mode flags */
typedef NS_OPTIONS(uint32_t, DLABDeckControlExportModeOps)
{
    DLABDeckControlExportModeOpsInsertVideo                          = 1 << 0,
    DLABDeckControlExportModeOpsInsertAudio1                         = 1 << 1,
    DLABDeckControlExportModeOpsInsertAudio2                         = 1 << 2,
    DLABDeckControlExportModeOpsInsertAudio3                         = 1 << 3,
    DLABDeckControlExportModeOpsInsertAudio4                         = 1 << 4,
    DLABDeckControlExportModeOpsInsertAudio5                         = 1 << 5,
    DLABDeckControlExportModeOpsInsertAudio6                         = 1 << 6,
    DLABDeckControlExportModeOpsInsertAudio7                         = 1 << 7,
    DLABDeckControlExportModeOpsInsertAudio8                         = 1 << 8,
    DLABDeckControlExportModeOpsInsertAudio9                         = 1 << 9,
    DLABDeckControlExportModeOpsInsertAudio10                        = 1 << 10,
    DLABDeckControlExportModeOpsInsertAudio11                        = 1 << 11,
    DLABDeckControlExportModeOpsInsertAudio12                        = 1 << 12,
    DLABDeckControlExportModeOpsInsertTimeCode                       = 1 << 13,
    DLABDeckControlExportModeOpsInsertAssemble                       = 1 << 14,
    DLABDeckControlExportModeOpsInsertPreview                        = 1 << 15,
    DLABDeckControlExportModeOpsUseManualExport                                = 1 << 16
};

/* Enum BMDDeckControlError - Deck Control error */
typedef NS_ENUM(uint32_t, DLABDeckControlError)
{
    DLABDeckControlErrorNoError                                        = /* 'noer' */ 0x6E6F6572,
    DLABDeckControlErrorModeError                                      = /* 'moer' */ 0x6D6F6572,
    DLABDeckControlErrorMissedInPointError                             = /* 'mier' */ 0x6D696572,
    DLABDeckControlErrorDeckTimeoutError                               = /* 'dter' */ 0x64746572,
    DLABDeckControlErrorCommandFailedError                             = /* 'cfer' */ 0x63666572,
    DLABDeckControlErrorDeviceAlreadyOpenedError                       = /* 'dalo' */ 0x64616C6F,
    DLABDeckControlErrorFailedToOpenDeviceError                        = /* 'fder' */ 0x66646572,
    DLABDeckControlErrorInLocalModeError                               = /* 'lmer' */ 0x6C6D6572,
    DLABDeckControlErrorEndOfTapeError                                 = /* 'eter' */ 0x65746572,
    DLABDeckControlErrorUserAbortError                                 = /* 'uaer' */ 0x75616572,
    DLABDeckControlErrorNoTapeInDeckError                              = /* 'nter' */ 0x6E746572,
    DLABDeckControlErrorNoVideoFromCardError                           = /* 'nvfc' */ 0x6E766663,
    DLABDeckControlErrorNoCommunicationError                           = /* 'ncom' */ 0x6E636F6D,
    DLABDeckControlErrorBufferTooSmallError                            = /* 'btsm' */ 0x6274736D,
    DLABDeckControlErrorBadChecksumError                               = /* 'chks' */ 0x63686B73,
    DLABDeckControlErrorUnknownError                                   = /* 'uner' */ 0x756E6572
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIModes.h
/* =================================================================================== */

/* Enum BMDDisplayMode - Video display modes */
typedef NS_ENUM(uint32_t, DLABDisplayMode)
{
    /* SD Modes */
    
    DLABDisplayModeNTSC                                                  = /* 'ntsc' */ 0x6E747363,
    DLABDisplayModeNTSC2398                                              = /* 'nt23' */ 0x6E743233,    // 3:2 pulldown
    DLABDisplayModePAL                                                   = /* 'pal ' */ 0x70616C20,
    DLABDisplayModeNTSCp                                                 = /* 'ntsp' */ 0x6E747370,
    DLABDisplayModePALp                                                  = /* 'palp' */ 0x70616C70,
    
    /* HD 1080 Modes */
    
    DLABDisplayModeHD1080p2398                                           = /* '23ps' */ 0x32337073,
    DLABDisplayModeHD1080p24                                             = /* '24ps' */ 0x32347073,
    DLABDisplayModeHD1080p25                                             = /* 'Hp25' */ 0x48703235,
    DLABDisplayModeHD1080p2997                                           = /* 'Hp29' */ 0x48703239,
    DLABDisplayModeHD1080p30                                             = /* 'Hp30' */ 0x48703330,
    DLABDisplayModeHD1080p4795                                           = /* 'Hp47' */ 0x48703437,
    DLABDisplayModeHD1080p48                                             = /* 'Hp48' */ 0x48703438,
    DLABDisplayModeHD1080p50                                             = /* 'Hp50' */ 0x48703530,
    DLABDisplayModeHD1080p5994                                           = /* 'Hp59' */ 0x48703539,
    DLABDisplayModeHD1080p6000                                           = /* 'Hp60' */ 0x48703630,    // N.B. This _really_ is 60.00 Hz.
    DLABDisplayModeHD1080p9590                                           = /* 'Hp95' */ 0x48703935,
    DLABDisplayModeHD1080p96                                             = /* 'Hp96' */ 0x48703936,
    DLABDisplayModeHD1080p100                                            = /* 'Hp10' */ 0x48703130,
    DLABDisplayModeHD1080p11988                                          = /* 'Hp11' */ 0x48703131,
    DLABDisplayModeHD1080p120                                            = /* 'Hp12' */ 0x48703132,
    DLABDisplayModeHD1080i50                                             = /* 'Hi50' */ 0x48693530,
    DLABDisplayModeHD1080i5994                                           = /* 'Hi59' */ 0x48693539,
    DLABDisplayModeHD1080i6000                                           = /* 'Hi60' */ 0x48693630,    // N.B. This _really_ is 60.00 Hz.
    
    /* HD 720 Modes */
    
    DLABDisplayModeHD720p50                                              = /* 'hp50' */ 0x68703530,
    DLABDisplayModeHD720p5994                                            = /* 'hp59' */ 0x68703539,
    DLABDisplayModeHD720p60                                              = /* 'hp60' */ 0x68703630,
    
    /* 2K Modes */
    
    DLABDisplayMode2k2398                                                = /* '2k23' */ 0x326B3233,
    DLABDisplayMode2k24                                                  = /* '2k24' */ 0x326B3234,
    DLABDisplayMode2k25                                                  = /* '2k25' */ 0x326B3235,
    
    /* 2K DCI Modes */
    
    DLABDisplayMode2kDCI2398                                             = /* '2d23' */ 0x32643233,
    DLABDisplayMode2kDCI24                                               = /* '2d24' */ 0x32643234,
    DLABDisplayMode2kDCI25                                               = /* '2d25' */ 0x32643235,
    DLABDisplayMode2kDCI2997                                             = /* '2d29' */ 0x32643239,
    DLABDisplayMode2kDCI30                                               = /* '2d30' */ 0x32643330,
    DLABDisplayMode2kDCI4795                                             = /* '2d47' */ 0x32643437,
    DLABDisplayMode2kDCI48                                               = /* '2d48' */ 0x32643438,
    DLABDisplayMode2kDCI50                                               = /* '2d50' */ 0x32643530,
    DLABDisplayMode2kDCI5994                                             = /* '2d59' */ 0x32643539,
    DLABDisplayMode2kDCI60                                               = /* '2d60' */ 0x32643630,
    DLABDisplayMode2kDCI9590                                             = /* '2d95' */ 0x32643935,
    DLABDisplayMode2kDCI96                                               = /* '2d96' */ 0x32643936,
    DLABDisplayMode2kDCI100                                              = /* '2d10' */ 0x32643130,
    DLABDisplayMode2kDCI11988                                            = /* '2d11' */ 0x32643131,
    DLABDisplayMode2kDCI120                                              = /* '2d12' */ 0x32643132,
    
    /* 4K Modes */
    
    DLABDisplayMode4K2160p2398                                           = /* '4k23' */ 0x346B3233,
    DLABDisplayMode4K2160p24                                             = /* '4k24' */ 0x346B3234,
    DLABDisplayMode4K2160p25                                             = /* '4k25' */ 0x346B3235,
    DLABDisplayMode4K2160p2997                                           = /* '4k29' */ 0x346B3239,
    DLABDisplayMode4K2160p30                                             = /* '4k30' */ 0x346B3330,
    DLABDisplayMode4K2160p4795                                           = /* '4k47' */ 0x346B3437,
    DLABDisplayMode4K2160p48                                             = /* '4k48' */ 0x346B3438,
    DLABDisplayMode4K2160p50                                             = /* '4k50' */ 0x346B3530,
    DLABDisplayMode4K2160p5994                                           = /* '4k59' */ 0x346B3539,
    DLABDisplayMode4K2160p60                                             = /* '4k60' */ 0x346B3630,
    DLABDisplayMode4K2160p9590                                           = /* '4k95' */ 0x346B3935,
    DLABDisplayMode4K2160p96                                             = /* '4k96' */ 0x346B3936,
    DLABDisplayMode4K2160p100                                            = /* '4k10' */ 0x346B3130,
    DLABDisplayMode4K2160p11988                                          = /* '4k11' */ 0x346B3131,
    DLABDisplayMode4K2160p120                                            = /* '4k12' */ 0x346B3132,
    
    /* 4K DCI Modes */
    
    DLABDisplayMode4kDCI2398                                             = /* '4d23' */ 0x34643233,
    DLABDisplayMode4kDCI24                                               = /* '4d24' */ 0x34643234,
    DLABDisplayMode4kDCI25                                               = /* '4d25' */ 0x34643235,
    DLABDisplayMode4kDCI2997                                             = /* '4d29' */ 0x34643239,
    DLABDisplayMode4kDCI30                                               = /* '4d30' */ 0x34643330,
    DLABDisplayMode4kDCI4795                                             = /* '4d47' */ 0x34643437,
    DLABDisplayMode4kDCI48                                               = /* '4d48' */ 0x34643438,
    DLABDisplayMode4kDCI50                                               = /* '4d50' */ 0x34643530,
    DLABDisplayMode4kDCI5994                                             = /* '4d59' */ 0x34643539,
    DLABDisplayMode4kDCI60                                               = /* '4d60' */ 0x34643630,
    DLABDisplayMode4kDCI9590                                             = /* '4d95' */ 0x34643935,
    DLABDisplayMode4kDCI96                                               = /* '4d96' */ 0x34643936,
    DLABDisplayMode4kDCI100                                              = /* '4d10' */ 0x34643130,
    DLABDisplayMode4kDCI11988                                            = /* '4d11' */ 0x34643131,
    DLABDisplayMode4kDCI120                                              = /* '4d12' */ 0x34643132,
    
    /* 8K UHD Modes */
    
    DLABDisplayMode8K4320p2398                                           = /* '8k23' */ 0x386B3233,
    DLABDisplayMode8K4320p24                                             = /* '8k24' */ 0x386B3234,
    DLABDisplayMode8K4320p25                                             = /* '8k25' */ 0x386B3235,
    DLABDisplayMode8K4320p2997                                           = /* '8k29' */ 0x386B3239,
    DLABDisplayMode8K4320p30                                             = /* '8k30' */ 0x386B3330,
    DLABDisplayMode8K4320p4795                                           = /* '8k47' */ 0x386B3437,
    DLABDisplayMode8K4320p48                                             = /* '8k48' */ 0x386B3438,
    DLABDisplayMode8K4320p50                                             = /* '8k50' */ 0x386B3530,
    DLABDisplayMode8K4320p5994                                           = /* '8k59' */ 0x386B3539,
    DLABDisplayMode8K4320p60                                             = /* '8k60' */ 0x386B3630,
    
    /* 8K DCI Modes */
    
    DLABDisplayMode8kDCI2398                                             = /* '8d23' */ 0x38643233,
    DLABDisplayMode8kDCI24                                               = /* '8d24' */ 0x38643234,
    DLABDisplayMode8kDCI25                                               = /* '8d25' */ 0x38643235,
    DLABDisplayMode8kDCI2997                                             = /* '8d29' */ 0x38643239,
    DLABDisplayMode8kDCI30                                               = /* '8d30' */ 0x38643330,
    DLABDisplayMode8kDCI4795                                             = /* '8d47' */ 0x38643437,
    DLABDisplayMode8kDCI48                                               = /* '8d48' */ 0x38643438,
    DLABDisplayMode8kDCI50                                               = /* '8d50' */ 0x38643530,
    DLABDisplayMode8kDCI5994                                             = /* '8d59' */ 0x38643539,
    DLABDisplayMode8kDCI60                                               = /* '8d60' */ 0x38643630,
    
    /* PC Modes */
    
    DLABDisplayMode640x480p60                                            = /* 'vga6' */ 0x76676136,
    DLABDisplayMode800x600p60                                            = /* 'svg6' */ 0x73766736,
    DLABDisplayMode1440x900p50                                           = /* 'wxg5' */ 0x77786735,
    DLABDisplayMode1440x900p60                                           = /* 'wxg6' */ 0x77786736,
    DLABDisplayMode1440x1080p50                                          = /* 'sxg5' */ 0x73786735,
    DLABDisplayMode1440x1080p60                                          = /* 'sxg6' */ 0x73786736,
    DLABDisplayMode1600x1200p50                                          = /* 'uxg5' */ 0x75786735,
    DLABDisplayMode1600x1200p60                                          = /* 'uxg6' */ 0x75786736,
    DLABDisplayMode1920x1200p50                                          = /* 'wux5' */ 0x77757835,
    DLABDisplayMode1920x1200p60                                          = /* 'wux6' */ 0x77757836,
    DLABDisplayMode1920x1440p50                                          = /* '1945' */ 0x31393435,
    DLABDisplayMode1920x1440p60                                          = /* '1946' */ 0x31393436,
    DLABDisplayMode2560x1440p50                                          = /* 'wqh5' */ 0x77716835,
    DLABDisplayMode2560x1440p60                                          = /* 'wqh6' */ 0x77716836,
    DLABDisplayMode2560x1600p50                                          = /* 'wqx5' */ 0x77717835,
    DLABDisplayMode2560x1600p60                                          = /* 'wqx6' */ 0x77717836,
    
    /* Special Modes */
    
    DLABDisplayModeUnknown                                               = /* 'iunk' */ 0x69756E6B
};

/* Enum BMDFieldDominance - Video field dominance */
typedef NS_ENUM(uint32_t, DLABFieldDominance)
{
    DLABFieldDominanceUnknown                                     = 0,
    DLABFieldDominanceLowerFieldFirst                                           = /* 'lowr' */ 0x6C6F7772,
    DLABFieldDominanceUpperFieldFirst                                           = /* 'uppr' */ 0x75707072,
    DLABFieldDominanceProgressiveFrame                                          = /* 'prog' */ 0x70726F67,
    DLABFieldDominanceProgressiveSegmentedFrame                                 = /* 'psf ' */ 0x70736620
};

/* Enum BMDPixelFormat - Video pixel formats supported for output/input */
typedef NS_ENUM(uint32_t, DLABPixelFormat)
{
    DLABPixelFormatUnspecified                                         = 0,
    DLABPixelFormat8BitYUV                                             = /* '2vuy' */ 0x32767579,
    DLABPixelFormat10BitYUV                                            = /* 'v210' */ 0x76323130,
    DLABPixelFormat8BitARGB                                            = 32,
    DLABPixelFormat8BitBGRA                                            = /* 'BGRA' */ 0x42475241,
    DLABPixelFormat10BitRGB                                            = /* 'r210' */ 0x72323130,    // Big-endian RGB 10-bit per component with SMPTE video levels (64-960). Packed as 2:10:10:10
    DLABPixelFormat12BitRGB                                            = /* 'R12B' */ 0x52313242,    // Big-endian RGB 12-bit per component with full range (0-4095). Packed as 12-bit per component
    DLABPixelFormat12BitRGBLE                                          = /* 'R12L' */ 0x5231324C,    // Little-endian RGB 12-bit per component with full range (0-4095). Packed as 12-bit per component
    DLABPixelFormat10BitRGBXLE                                         = /* 'R10l' */ 0x5231306C,    // Little-endian 10-bit RGB with SMPTE video levels (64-940)
    DLABPixelFormat10BitRGBX                                           = /* 'R10b' */ 0x52313062,    // Big-endian 10-bit RGB with SMPTE video levels (64-940)
    DLABPixelFormatH265                                                = /* 'hev1' */ 0x68657631,    // High Efficiency Video Coding (HEVC/h.265)
    
    /* AVID DNxHR */
    
    DLABPixelFormatDNxHR                                               = /* 'AVdh' */ 0x41566468
};

/* Enum BMDDisplayModeFlags - Flags to describe the characteristics of an IDeckLinkDisplayMode. */
typedef NS_OPTIONS(uint32_t, DLABDisplayModeFlag)
{
    DLABDisplayModeFlagSupports3D                                     = 1 << 0,
    DLABDisplayModeFlagColorspaceRec601                               = 1 << 1,
    DLABDisplayModeFlagColorspaceRec709                               = 1 << 2,
    DLABDisplayModeFlagColorspaceRec2020                              = 1 << 3
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIStreaming.h
/* =================================================================================== */

/* Enum BMDStreamingDeviceMode - Device modes */
typedef NS_ENUM(uint32_t, DLABStreamingDeviceMode)
{
    DLABStreamingDeviceModeIdle                                       = /* 'idle' */ 0x69646C65,
    DLABStreamingDeviceModeEncoding                                   = /* 'enco' */ 0x656E636F,
    DLABStreamingDeviceModeStopping                                   = /* 'stop' */ 0x73746F70,
    DLABStreamingDeviceModeUnknown                                    = /* 'munk' */ 0x6D756E6B
};

/* Enum BMDStreamingEncodingFrameRate - Encoded frame rates */
typedef NS_ENUM(uint32_t, DLABStreamingEncodingFrameRate)
{
    /* Interlaced rates */
    
    DLABStreamingEncodedFrameRate50i                              = /* 'e50i' */ 0x65353069,
    DLABStreamingEncodedFrameRate5994i                            = /* 'e59i' */ 0x65353969,
    DLABStreamingEncodedFrameRate60i                              = /* 'e60i' */ 0x65363069,
    
    /* Progressive rates */
    
    DLABStreamingEncodedFrameRate2398p                            = /* 'e23p' */ 0x65323370,
    DLABStreamingEncodedFrameRate24p                              = /* 'e24p' */ 0x65323470,
    DLABStreamingEncodedFrameRate25p                              = /* 'e25p' */ 0x65323570,
    DLABStreamingEncodedFrameRate2997p                            = /* 'e29p' */ 0x65323970,
    DLABStreamingEncodedFrameRate30p                              = /* 'e30p' */ 0x65333070,
    DLABStreamingEncodedFrameRate50p                              = /* 'e50p' */ 0x65353070,
    DLABStreamingEncodedFrameRate5994p                            = /* 'e59p' */ 0x65353970,
    DLABStreamingEncodedFrameRate60p                              = /* 'e60p' */ 0x65363070
};

/* Enum BMDStreamingEncodingSupport - Output encoding mode supported flag */
typedef NS_ENUM(uint32_t, DLABStreamingEncodingMode)
{
    DLABStreamingEncodingModeNotSupported                         = 0,
    DLABStreamingEncodingModeSupported,
    DLABStreamingEncodingModeSupportedWithChanges
};

/* Enum BMDStreamingVideoCodec - Video codecs */
typedef NS_ENUM(uint32_t, DLABStreamingVideoCodec)
{
    DLABStreamingVideoCodecH264                                   = /* 'H264' */ 0x48323634
};

/* Enum BMDStreamingH264Profile - H264 encoding profile */
typedef NS_ENUM(uint32_t, DLABStreamingH264Profile)
{
    DLABStreamingH264ProfileHigh                                  = /* 'high' */ 0x68696768,
    DLABStreamingH264ProfileMain                                  = /* 'main' */ 0x6D61696E,
    DLABStreamingH264ProfileBaseline                              = /* 'base' */ 0x62617365
};

/* Enum BMDStreamingH264Level - H264 encoding level */
typedef NS_ENUM(uint32_t, DLABStreamingH264Level)
{
    DLABStreamingH264Level12                                      = /* 'lv12' */ 0x6C763132,
    DLABStreamingH264Level13                                      = /* 'lv13' */ 0x6C763133,
    DLABStreamingH264Level2                                       = /* 'lv2 ' */ 0x6C763220,
    DLABStreamingH264Level21                                      = /* 'lv21' */ 0x6C763231,
    DLABStreamingH264Level22                                      = /* 'lv22' */ 0x6C763232,
    DLABStreamingH264Level3                                       = /* 'lv3 ' */ 0x6C763320,
    DLABStreamingH264Level31                                      = /* 'lv31' */ 0x6C763331,
    DLABStreamingH264Level32                                      = /* 'lv32' */ 0x6C763332,
    DLABStreamingH264Level4                                       = /* 'lv4 ' */ 0x6C763420,
    DLABStreamingH264Level41                                      = /* 'lv41' */ 0x6C763431,
    DLABStreamingH264Level42                                      = /* 'lv42' */ 0x6C763432
};

/* Enum BMDStreamingH264EntropyCoding - H264 entropy coding */
typedef NS_ENUM(uint32_t, DLABStreamingH264EntropyCoding)
{
    DLABStreamingH264EntropyCodingCAVLC                           = /* 'EVLC' */ 0x45564C43,
    DLABStreamingH264EntropyCodingCABAC                           = /* 'EBAC' */ 0x45424143
};

/* Enum BMDStreamingAudioCodec - Audio codecs */
typedef NS_ENUM(uint32_t, DLABStreamingAudioCodec)
{
    DLABStreamingAudioCodecAAC                                    = /* 'AAC ' */ 0x41414320
};

/* Enum BMDStreamingEncodingModePropertyID - Encoding mode properties */
typedef NS_ENUM(uint32_t, DLABStreamingEncodingProperty)
{
    /* Integers, Video Properties */
    
    DLABStreamingEncodingPropertyVideoFrameRate                   = /* 'vfrt' */ 0x76667274,    // Uses values of type BMDStreamingEncodingFrameRate
    DLABStreamingEncodingPropertyVideoBitRateKbps                 = /* 'vbrt' */ 0x76627274,
    
    /* Integers, H264 Properties */
    
    DLABStreamingEncodingPropertyH264Profile                      = /* 'hprf' */ 0x68707266,
    DLABStreamingEncodingPropertyH264Level                        = /* 'hlvl' */ 0x686C766C,
    DLABStreamingEncodingPropertyH264EntropyCoding                = /* 'hent' */ 0x68656E74,
    
    /* Flags, H264 Properties */
    
    DLABStreamingEncodingPropertyH264HasBFrames                   = /* 'hBfr' */ 0x68426672,
    
    /* Integers, Audio Properties */
    
    DLABStreamingEncodingPropertyAudioCodec                       = /* 'acdc' */ 0x61636463,
    DLABStreamingEncodingPropertyAudioSampleRate                  = /* 'asrt' */ 0x61737274,
    DLABStreamingEncodingPropertyAudioChannelCount                = /* 'achc' */ 0x61636863,
    DLABStreamingEncodingPropertyAudioBitRateKbps                 = /* 'abrt' */ 0x61627274
};

/* =================================================================================== */
// MARK: - From DeckLinkAPITypes.h
/* =================================================================================== */

// Type Declarations

typedef int64_t DLABTimeValue;
typedef int64_t DLABTimeScale;
typedef uint32_t DLABTimecodeBCD;
typedef uint32_t DLABTimecodeUserBits;

/* Enum BMDTimecodeFlags - Timecode flags */
typedef NS_OPTIONS(uint32_t, DLABTimecodeFlag)
{
    DLABTimecodeFlagDefault                                       = 0,
    DLABTimecodeFlagIsDropFrame                                       = 1 << 0,
    DLABTimecodeFlagFieldMark                                         = 1 << 1,
    DLABTimecodeFlagColorFrame                                        = 1 << 2,
    DLABTimecodeFlagEmbedRecordingTrigger                             = 1 << 3,  // On SDI recording trigger utilises a user-bit.
    DLABTimecodeFlagRecordingTriggered                                = 1 << 4
};

/* Enum BMDVideoConnection - Video connection types */
typedef NS_OPTIONS(uint32_t, DLABVideoConnection)
{
    DLABVideoConnectionUnspecified                                = 0,
    DLABVideoConnectionSDI                                        = 1 << 0,
    DLABVideoConnectionHDMI                                       = 1 << 1,
    DLABVideoConnectionOpticalSDI                                 = 1 << 2,
    DLABVideoConnectionComponent                                  = 1 << 3,
    DLABVideoConnectionComposite                                  = 1 << 4,
    DLABVideoConnectionSVideo                                     = 1 << 5
};

/* Enum BMDAudioConnection - Audio connection types */
typedef NS_OPTIONS(uint32_t, DLABAudioConnection)
{
    DLABAudioConnectionEmbedded                                   = 1 << 0,
    DLABAudioConnectionAESEBU                                     = 1 << 1,
    DLABAudioConnectionAnalog                                     = 1 << 2,
    DLABAudioConnectionAnalogXLR                                  = 1 << 3,
    DLABAudioConnectionAnalogRCA                                  = 1 << 4,
    DLABAudioConnectionMicrophone                                 = 1 << 5,
    DLABAudioConnectionHeadphones                                 = 1 << 6
};

/* Enum BMDDeckControlConnection - Deck control connections */
typedef NS_OPTIONS(uint32_t, DLABDeckControlConnection)
{
    DLABDeckControlConnectionRS422Remote1                         = 1 << 0,
    DLABDeckControlConnectionRS422Remote2                         = 1 << 1
};

/* =================================================================================== */
