//
//  DLABConstants.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017, 2019年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

/**
 Swift-safe NS_ENUM/NS_OPTIONS definition
 
 NOTE: This constants are converted from DekLink API "11.2.x"
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
 Derived from: Blackmagic_DeckLink_SDK_11.2.zip @ 2019/05/27 UTC
 
 #define BLACKMAGIC_DECKLINK_API_VERSION                    0x0b020000
 #define BLACKMAGIC_DECKLINK_API_VERSION_STRING            "11.2"
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

/* Enum BMDSupportedVideoModeFlags - Flags to describe supported video mode */
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
    DLABPacketTypeStreamInterruptedMarker                         = 'sint',	// A packet of this type marks the time when a video stream was interrupted, for example by a disconnected cable
    DLABPacketTypeStreamData                                      = 'sdat'	// Regular stream data
};

/* Enum BMDFrameFlags - Frame flags */
typedef NS_OPTIONS(uint32_t, DLABFrameFlag)
{
    DLABFrameFlagDefault                                          = 0,
    DLABFrameFlagFlipVertical                                     = 1 << 0,
    DLABFrameFlagContainsHDRMetadata                                  = 1 << 1,
    DLABFrameFlagContainsCintelMetadata                               = 1 << 2,
    
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
    DLABDetectedVideoInputFormatFlagDualStream3D                            = 1 << 2
};

/* Enum BMDDeckLinkCapturePassthroughMode - Enumerates whether the video output is electrically connected to the video input or if the clean switching mode is enabled */
typedef NS_ENUM(uint32_t, DLABDeckLinkCapturePassthroughMode)
{
    DLABDeckLinkCapturePassthroughModeDisabled                    = 'pdis',
    DLABDeckLinkCapturePassthroughModeDirect                      = 'pdir',
    DLABDeckLinkCapturePassthroughModeCleanSwitch                 = 'pcln'
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
    DLABReferenceStatusNotSupportedByHardware                           = 1 << 0,
    DLABReferenceStatusLocked                                           = 1 << 1
};

/* Enum BMDAudioFormat - Audio Format */
typedef NS_ENUM(uint32_t, DLABAudioFormat)
{
    DLABAudioFormatPCM                                            = 'lpcm'	// Linear signed PCM samples
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
    DLABAncillaryPacketFormatUInt8                                = 'ui08',
    DLABAncillaryPacketFormatUInt16                               = 'ui16',
    DLABAncillaryPacketFormatYCbCr10                              = 'v210'
};

/* Enum BMDTimecodeFormat - Timecode formats for frame metadata */
typedef NS_ENUM(uint32_t, DLABTimecodeFormat)
{
    DLABTimecodeFormatRP188VITC1                                        = 'rpv1',	// RP188 timecode where DBB1 equals VITC1 (line 9)
    DLABTimecodeFormatRP188VITC2                                        = 'rp12',	// RP188 timecode where DBB1 equals VITC2 (line 9 for progressive or line 571 for interlaced/PsF)
    DLABTimecodeFormatRP188LTC                                          = 'rplt',	// RP188 timecode where DBB1 equals LTC (line 10)
    DLABTimecodeFormatRP188HighFrameRate                                = 'rphr',   // RP188 timecode where DBB1 is an HFRTC (SMPTE ST 12-3), the only timecode allowing the frame value to go above 30
    DLABTimecodeFormatRP188Any                                          = 'rp18',   // Convenience for capture, returning the first valid timecode in {HFRTC (if supported), VITC1, LTC, VITC2}
    DLABTimecodeFormatVITC                                              = 'vitc',
    DLABTimecodeFormatVITCField2                                        = 'vit2',
    DLABTimecodeFormatSerial                                            = 'seri'
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
    DLABAudioOutputSwitchAESEBU                                   = 'aes ',
    DLABAudioOutputSwitchAnalog                                   = 'anlg'
};

/* Enum BMDVideoOutputConversionMode - Video/audio conversion mode */
typedef NS_ENUM(uint32_t, DLABVideoOutputConversionMode)
{
    DLABVideoOutputConversionModeNone                                   = 'none',
    DLABVideoOutputConversionModeLetterboxDownconversion                        = 'ltbx',
    DLABVideoOutputConversionModeAnamorphicDownconversion                       = 'amph',
    DLABVideoOutputConversionModeHD720toHD1080Conversion                        = '720c',
    DLABVideoOutputConversionModeHardwareLetterboxDownconversion                = 'HWlb',
    DLABVideoOutputConversionModeHardwareAnamorphicDownconversion               = 'HWam',
    DLABVideoOutputConversionModeHardwareCenterCutDownconversion                = 'HWcc',
    DLABVideoOutputConversionModeHardware720p1080pCrossconversion               = 'xcap',
    DLABVideoOutputConversionModeHardwareAnamorphic720pUpconversion             = 'ua7p',
    DLABVideoOutputConversionModeHardwareAnamorphic1080iUpconversion            = 'ua1i',
    DLABVideoOutputConversionModeHardwareAnamorphic149To720pUpconversion        = 'u47p',
    DLABVideoOutputConversionModeHardwareAnamorphic149To1080iUpconversion       = 'u41i',
    DLABVideoOutputConversionModeHardwarePillarbox720pUpconversion              = 'up7p',
    DLABVideoOutputConversionModeHardwarePillarbox1080iUpconversion             = 'up1i'
};

/* Enum BMDVideoInputConversionMode - Video input conversion mode */
typedef NS_ENUM(uint32_t, DLABVideoInputConversionMode)
{
    DLABVideoInputConversionModeNone                                    = 'none',
    DLABVideoInputConversionModeLetterboxDownconversionFromHD1080               = '10lb',
    DLABVideoInputConversionModeAnamorphicDownconversionFromHD1080              = '10am',
    DLABVideoInputConversionModeLetterboxDownconversionFromHD720                = '72lb',
    DLABVideoInputConversionModeAnamorphicDownconversionFromHD720               = '72am',
    DLABVideoInputConversionModeLetterboxUpconversion                           = 'lbup',
    DLABVideoInputConversionModeAnamorphicUpconversion                          = 'amup'
};

/* Enum BMDVideo3DPackingFormat - Video 3D packing format */
typedef NS_ENUM(uint32_t, DLABVideo3DPackingFormat)
{
    DLABVideo3DPackingFormatSidebySideHalf                              = 'sbsh',
    DLABVideo3DPackingFormatLinebyLine                                  = 'lbyl',
    DLABVideo3DPackingFormatTopAndBottom                                = 'tabo',
    DLABVideo3DPackingFormatFramePacking                                = 'frpk',
    DLABVideo3DPackingFormatLeftOnly                                    = 'left',
    DLABVideo3DPackingFormatRightOnly                                   = 'righ'
};

/* Enum BMDIdleVideoOutputOperation - Video output operation when not playing video */
typedef NS_ENUM(uint32_t, DLABIdleVideoOutputOperation)
{
    DLABIdleVideoOutputOperationBlack                                      = 'blac',
    DLABIdleVideoOutputOperationLastFrame                                  = 'lafa'
};

/* Enum BMDVideoEncoderFrameCodingMode - Video frame coding mode */
typedef NS_ENUM(uint32_t, DLABVideoEncoderFrameCodingMode)
{
    DLABVideoEncoderFrameCodingModeInter                          = 'inte',
    DLABVideoEncoderFrameCodingModeIntra                          = 'intr'
};

/* Enum BMDDNxHRLevel - DNxHR Levels */
typedef NS_ENUM(uint32_t, DLABDNxHRLevel)
{
    DLABDNxHRLevelSQ                                              = 'dnsq',
    DLABDNxHRLevelLB                                              = 'dnlb',
    DLABDNxHRLevelHQ                                              = 'dnhq',
    DLABDNxHRLevelHQX                                             = 'dhqx',
    DLABDNxHRLevel444                                             = 'd444'
};

/* Enum BMDLinkConfiguration - Video link configuration */
typedef NS_ENUM(uint32_t, DLABLinkConfiguration)
{
    DLABLinkConfigurationSingleLink                               = 'lcsl',
    DLABLinkConfigurationDualLink                                 = 'lcdl',
    DLABLinkConfigurationQuadLink                                 = 'lcql'
};

/* Enum BMDDeviceInterface - Device interface type */
typedef NS_ENUM(uint32_t, DLABDeviceInterface)
{
    DLABDeviceInterfacePCI                                        = 'pci ',
    DLABDeviceInterfaceUSB                                        = 'usb ',
    DLABDeviceInterfaceThunderbolt                                = 'thun'
};

/* Enum BMDColorspace - Colorspace */
typedef NS_ENUM(uint32_t, DLABColorspace)
{
    DLABColorspaceRec601                                          = 'r601',
    DLABColorspaceRec709                                          = 'r709',
    DLABColorspaceRec2020                                         = '2020'
};

/* Enum BMDDynamicRange - SDR or HDR */
typedef NS_ENUM(uint32_t, DLABDynamicRange)
{
    DLABDynamicRangeSDR                                           = 0,
    DLABDynamicRangeHDRStaticPQ                                   = 1 << 29,     // SMPTE ST 2084
    DLABDynamicRangeHDRStaticHLG                                  = 1 << 30      // ITU-R BT.2100-0
};

/* Enum BMDDeckLinkHDMIInputEDIDID - DeckLink HDMI Input EDID ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkHDMIInputEDID)
{
    DLABDeckLinkHDMIInputEDIDDynamicRange                         = 'HIDy'       // Parameter is of type BMDDynamicRange. Default is (bmdDynamicRangeSDR|bmdDynamicRangeHDRStaticPQ)
};

/* Enum BMDDeckLinkFrameMetadataID - DeckLink Frame Metadata ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkFrameMetadata)
{
    DLABDeckLinkFrameMetadataColorspace                           = 'cspc',      // Colorspace of video frame (see BMDColorspace)
    DLABDeckLinkFrameMetadataHDRElectroOpticalTransferFunc        = 'eotf',	// EOTF in range 0-7 as per CEA 861.3
    DLABDeckLinkFrameMetadataCintelFilmType                       = 'cfty',	// Current film type
    DLABDeckLinkFrameMetadataCintelFilmGauge                      = 'cfga',	// Current film gauge
    DLABDeckLinkFrameMetadataCintelKeykodeLow                     = 'ckkl',	// Raw keykode value - low 64 bits
    DLABDeckLinkFrameMetadataCintelKeykodeHigh                    = 'ckkh',	// Raw keykode value - high 64 bits
    DLABDeckLinkFrameMetadataCintelTile1Size                      = 'ct1s',      // Size in bytes of compressed raw tile 1
    DLABDeckLinkFrameMetadataCintelTile2Size                      = 'ct2s',      // Size in bytes of compressed raw tile 2
    DLABDeckLinkFrameMetadataCintelTile3Size                      = 'ct3s',      // Size in bytes of compressed raw tile 3
    DLABDeckLinkFrameMetadataCintelTile4Size                      = 'ct4s',      // Size in bytes of compressed raw tile 4
    DLABDeckLinkFrameMetadataCintelImageWidth                     = 'IWPx',      // Width in pixels of image
    DLABDeckLinkFrameMetadataCintelImageHeight                    = 'IHPx',      // Height in pixels of image
    DLABDeckLinkFrameMetadataCintelLinearMaskingRedInRed          = 'mrir',	// Red in red linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingGreenInRed        = 'mgir',	// Green in red linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingBlueInRed         = 'mbir',	// Blue in red linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingRedInGreen        = 'mrig',	// Red in green linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingGreenInGreen      = 'mgig',	// Green in green linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingBlueInGreen       = 'mbig',	// Blue in green linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingRedInBlue         = 'mrib',	// Red in blue linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingGreenInBlue       = 'mgib',	// Green in blue linear masking parameter
    DLABDeckLinkFrameMetadataCintelLinearMaskingBlueInBlue        = 'mbib',	// Blue in blue linear masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingRedInRed             = 'mlrr',	// Red in red log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingGreenInRed           = 'mlgr',	// Green in red log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingBlueInRed            = 'mlbr',	// Blue in red log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingRedInGreen           = 'mlrg',	// Red in green log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingGreenInGreen         = 'mlgg',	// Green in green log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingBlueInGreen          = 'mlbg',	// Blue in green log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingRedInBlue            = 'mlrb',	// Red in blue log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingGreenInBlue          = 'mlgb',	// Green in blue log masking parameter
    DLABDeckLinkFrameMetadataCintelLogMaskingBlueInBlue           = 'mlbb',	// Blue in blue log masking parameter
    DLABDeckLinkFrameMetadataCintelFilmFrameRate                  = 'cffr',      // Film frame rate
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesRedX              = 'hdrx',	// Red display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesRedY              = 'hdry',	// Red display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesGreenX            = 'hdgx',	// Green display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesGreenY            = 'hdgy',	// Green display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesBlueX             = 'hdbx',	// Blue display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRDisplayPrimariesBlueY             = 'hdby',	// Blue display primaries in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRWhitePointX                       = 'hdwx',	// White point in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRWhitePointY                       = 'hdwy',	// White point in range 0.0 - 1.0
    DLABDeckLinkFrameMetadataHDRMaxDisplayMasteringLuminance      = 'hdml',	// Max display mastering luminance in range 1 cd/m2 - 65535 cd/m2
    DLABDeckLinkFrameMetadataHDRMinDisplayMasteringLuminance      = 'hmil',	// Min display mastering luminance in range 0.0001 cd/m2 - 6.5535 cd/m2
    DLABDeckLinkFrameMetadataHDRMaximumContentLightLevel          = 'mcll',	// Maximum Content Light Level in range 1 cd/m2 - 65535 cd/m2
    DLABDeckLinkFrameMetadataHDRMaximumFrameAverageLightLevel     = 'fall',	// Maximum Frame Average Light Level in range 1 cd/m2 - 65535 cd/m2
    DLABDeckLinkFrameMetadataCintelOffsetToApplyHorizontal        = 'otah',      // Horizontal offset (pixels) to be applied to image
    DLABDeckLinkFrameMetadataCintelOffsetToApplyVertical          = 'otav',      // Vertical offset (pixels) to be applied to image
    DLABDeckLinkFrameMetadataCintelGainRed                        = 'LfRd',      // Red gain parameter to apply after log
    DLABDeckLinkFrameMetadataCintelGainGreen                      = 'LfGr',      // Green gain parameter to apply after log
    DLABDeckLinkFrameMetadataCintelGainBlue                       = 'LfBl',      // Blue gain parameter to apply after log
    DLABDeckLinkFrameMetadataCintelLiftRed                        = 'GnRd',      // Red lift parameter to apply after log and gain
    DLABDeckLinkFrameMetadataCintelLiftGreen                      = 'GnGr',      // Green lift parameter to apply after log and gain
    DLABDeckLinkFrameMetadataCintelLiftBlue                       = 'GnBl',      // Blue lift parameter to apply after log and gain
    DLABDeckLinkFrameMetadataCintelHDRGainRed                     = 'HGRd',      // Red gain parameter to apply to linear data for HDR Combination
    DLABDeckLinkFrameMetadataCintelHDRGainGreen                   = 'HGGr',      // Green gain parameter to apply to linear data for HDR Combination
    DLABDeckLinkFrameMetadataCintelHDRGainBlue                    = 'HGBl'       // Blue gain parameter to apply to linear data for HDR Combination
};

/* Enum BMDProfileID - Identifies a profile */
typedef NS_ENUM(uint32_t, DLABProfile)
{
    DLABProfileOneSubDeviceFullDuplex                             = '1dfd',
    DLABProfileOneSubDeviceHalfDuplex                             = '1dhd',
    DLABProfileTwoSubDevicesFullDuplex                            = '2dfd',
    DLABProfileTwoSubDevicesHalfDuplex                            = '2dhd',
    DLABProfileFourSubDevicesHalfDuplex                           = '4dhd'
};

/* Enum BMDHDMITimecodePacking - Packing form of timecode on HDMI */
typedef NS_ENUM(uint32_t, DLABHDMITimecodePacking)
{
    DLABHDMITimecodePackingIEEEOUI000085                          = 0x00008500,
    DLABHDMITimecodePackingIEEEOUI080046                          = 0x08004601,
    DLABHDMITimecodePackingIEEEOUI5CF9F0                          = 0x5CF9F003
};

/* Enum BMDDeckLinkAttributeID - DeckLink Attribute ID */
typedef NS_ENUM(uint32_t, DLABAttribute)
{
    /* Flags */
    
    DLABAttributeSupportsInternalKeying                            = 'keyi',
    DLABAttributeSupportsExternalKeying                            = 'keye',
    DLABAttributeSupportsInputFormatDetection                      = 'infd',
    DLABAttributeHasReferenceInput                                 = 'hrin',
    DLABAttributeHasSerialPort                                     = 'hspt',
    DLABAttributeHasAnalogVideoOutputGain                          = 'avog',
    DLABAttributeCanOnlyAdjustOverallVideoOutputGain               = 'ovog',
    DLABAttributeHasVideoInputAntiAliasingFilter                   = 'aafl',
    DLABAttributeHasBypass                                         = 'byps',
    DLABAttributeSupportsClockTimingAdjustment                     = 'ctad',
    DLABAttributeSupportsFullFrameReferenceInputTimingOffset       = 'frin',
    DLABAttributeSupportsSMPTELevelAOutput                         = 'lvla',
    DLABAttributeSupportsDualLinkSDI                               = 'sdls',
    DLABAttributeSupportsQuadLinkSDI                               = 'sqls',
    DLABAttributeSupportsIdleOutput                                = 'idou',
    DLABAttributeVANCRequires10BitYUVVideoFrames                   = 'vioY',      // Legacy product requires v210 active picture for IDeckLinkVideoFrameAncillaryPackets or 10-bit VANC
    DLABAttributeHasLTCTimecodeInput                               = 'hltc',
    DLABAttributeSupportsHDRMetadata                               = 'hdrm',
    DLABAttributeSupportsColorspaceMetadata                        = 'cmet',
    DLABAttributeSupportsHDMITimecode                              = 'htim',
    DLABAttributeSupportsHighFrameRateTimecode                     = 'HFRT',
    DLABAttributeSupportsSynchronizeToCaptureGroup                 = 'stcg',
    DLABAttributeSupportsSynchronizeToPlaybackGroup                = 'stpg',
    
    /* Integers */
    
    DLABAttributeMaximumAudioChannels                              = 'mach',
    DLABAttributeMaximumAnalogAudioInputChannels                   = 'iach',
    DLABAttributeMaximumAnalogAudioOutputChannels                  = 'aach',
    DLABAttributeNumberOfSubDevices                                = 'nsbd',
    DLABAttributeSubDeviceIndex                                    = 'subi',
    DLABAttributePersistentID                                      = 'peid',
    DLABAttributeDeviceGroupID                                     = 'dgid',
    DLABAttributeTopologicalID                                     = 'toid',
    DLABAttributeVideoOutputConnections                            = 'vocn',	// Returns a BMDVideoConnection bit field
    DLABAttributeVideoInputConnections                             = 'vicn',	// Returns a BMDVideoConnection bit field
    DLABAttributeAudioOutputConnections                            = 'aocn',	// Returns a BMDAudioConnection bit field
    DLABAttributeAudioInputConnections                             = 'aicn',	// Returns a BMDAudioConnection bit field
    DLABAttributeVideoIOSupport                                    = 'vios',	// Returns a BMDVideoIOSupport bit field
    DLABAttributeDeckControlConnections                            = 'dccn',	// Returns a BMDDeckControlConnection bit field
    DLABAttributeDeviceInterface                                   = 'dbus',	// Returns a BMDDeviceInterface
    DLABAttributeAudioInputRCAChannelCount                         = 'airc',
    DLABAttributeAudioInputXLRChannelCount                         = 'aixc',
    DLABAttributeAudioOutputRCAChannelCount                        = 'aorc',
    DLABAttributeAudioOutputXLRChannelCount                        = 'aoxc',
    DLABAttributeProfileID                                         = 'prid',      // Returns a BMDProfileID
    DLABAttributeDuplex                                            = 'dupx',
    
    /* Floats */
    
    DLABAttributeVideoInputGainMinimum                             = 'vigm',
    DLABAttributeVideoInputGainMaximum                             = 'vigx',
    DLABAttributeVideoOutputGainMinimum                            = 'vogm',
    DLABAttributeVideoOutputGainMaximum                            = 'vogx',
    DLABAttributeMicrophoneInputGainMinimum                        = 'migm',
    DLABAttributeMicrophoneInputGainMaximum                        = 'migx',
    
    /* Strings */
    
    DLABAttributeSerialPortDeviceName                              = 'slpn',
    DLABAttributeVendorName                                        = 'vndr',
    DLABAttributeDisplayName                                       = 'dspn',
    DLABAttributeModelName                                         = 'mdln',
    DLABAttributeDeviceHandle                                      = 'devh'
};

/* Enum BMDDeckLinkAPIInformationID - DeckLinkAPI information ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkAPIInformation)
{
    DLABDeckLinkAPIInformationVersion                                        = 'vers'
};

/* Enum BMDDeckLinkStatusID - DeckLink Status ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkStatus)
{
    /* Integers */
    
    DLABDeckLinkStatusDetectedVideoInputMode                      = 'dvim',
    DLABDeckLinkStatusDetectedVideoInputFlags                     = 'dvif',
    DLABDeckLinkStatusCurrentVideoInputMode                       = 'cvim',
    DLABDeckLinkStatusCurrentVideoInputPixelFormat                = 'cvip',
    DLABDeckLinkStatusCurrentVideoInputFlags                      = 'cvif',
    DLABDeckLinkStatusCurrentVideoOutputMode                      = 'cvom',
    DLABDeckLinkStatusCurrentVideoOutputFlags                     = 'cvof',
    DLABDeckLinkStatusPCIExpressLinkWidth                         = 'pwid',
    DLABDeckLinkStatusPCIExpressLinkSpeed                         = 'plnk',
    DLABDeckLinkStatusLastVideoOutputPixelFormat                  = 'opix',
    DLABDeckLinkStatusReferenceSignalMode                         = 'refm',
    DLABDeckLinkStatusReferenceSignalFlags                        = 'reff',
    DLABDeckLinkStatusBusy                                        = 'busy',
    DLABDeckLinkStatusInterchangeablePanelType                    = 'icpt',
    DLABDeckLinkStatusDeviceTemperature                           = 'dtmp',
    
    /* Flags */
    
    DLABDeckLinkStatusVideoInputSignalLocked                      = 'visl',
    DLABDeckLinkStatusReferenceSignalLocked                       = 'refl',
    DLABDeckLinkStatusReceivedEDID                                = 'edid'
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
    DLABDuplexModeFull                                                = 'dxfu',
    DLABDuplexModeHalf                                                = 'dxha',
    DLABDuplexModeSimplex                                             = 'dxsp',
    DLABDuplexModeInactive                                            = 'dxin'
};

/* Enum BMDPanelType - The type of interchangeable panel */
typedef NS_ENUM(uint32_t, DLABPanelType)
{
    DLABPanelTypeNotDetected                                          = 'npnl',
    DLABPanelTypeTeranexMiniSmartPanel                                = 'tmsm'
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
    , DLABVideoIOSupportHDKeying = 1 << 18     // Non-native extension @@@@
};

/* Enum BMD3DPreviewFormat - Linked Frame preview format */
typedef NS_ENUM(uint32_t, DLAB3DPreviewFormat)
{
    DLAB3DPreviewFormatDefault                                    = 'defa',
    DLAB3DPreviewFormatLeftOnly                                   = 'left',
    DLAB3DPreviewFormatRightOnly                                  = 'righ',
    DLAB3DPreviewFormatSideBySide                                 = 'side',
    DLAB3DPreviewFormatTopBottom                                  = 'topb'
};

/* Enum BMDNotifications - Events that can be subscribed through IDeckLinkNotification */
typedef NS_ENUM(uint32_t, DLABNotification)
{
    DLABNotificationPreferencesChanged                                        = 'pref',
    DLABNotificationStatusChanged                                             = 'stat'
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIConfiguration.h
/* =================================================================================== */

/* Enum BMDDeckLinkConfigurationID - DeckLink Configuration ID */
typedef NS_ENUM(uint32_t, DLABConfiguration)
{
    /* Serial port Flags */
    
    DLABConfigurationSwapSerialRxTx                              = 'ssrt',
    
    /* Video Input/Output Integers */
    
    DLABConfigurationHDMI3DPackingFormat                         = '3dpf',
    DLABConfigurationBypass                                      = 'byps',
    DLABConfigurationClockTimingAdjustment                       = 'ctad',
    
    /* Audio Input/Output Flags */
    
    DLABConfigurationAnalogAudioConsumerLevels                   = 'aacl',
    
    /* Video output flags */
    
    DLABConfigurationFieldFlickerRemoval                         = 'fdfr',
    DLABConfigurationHD1080p24ToHD1080i5994Conversion            = 'to59',
    DLABConfiguration444SDIVideoOutput                           = '444o',
    DLABConfigurationBlackVideoOutputDuringCapture               = 'bvoc',
    DLABConfigurationLowLatencyVideoOutput                       = 'llvo',
    DLABConfigurationDownConversionOnAllAnalogOutput             = 'caao',
    DLABConfigurationSMPTELevelAOutput                           = 'smta',
    DLABConfigurationRec2020Output                               = 'rec2',  // Ensure output is Rec.2020 colorspace
    DLABConfigurationQuadLinkSDIVideoOutputSquareDivisionSplit   = 'SDQS',
    
    /* Video Output Flags */
    
    DLABConfigurationOutput1080pAsPsF                            = 'pfpr',
    
    /* Video Output Integers */
    
    DLABConfigurationVideoOutputConnection                       = 'vocn',
    DLABConfigurationVideoOutputConversionMode                   = 'vocm',
    DLABConfigurationAnalogVideoOutputFlags                      = 'avof',
    DLABConfigurationReferenceInputTimingOffset                  = 'glot',
    DLABConfigurationVideoOutputIdleOperation                    = 'voio',
    DLABConfigurationDefaultVideoOutputMode                      = 'dvom',
    DLABConfigurationDefaultVideoOutputModeFlags                 = 'dvof',
    DLABConfigurationSDIOutputLinkConfiguration                  = 'solc',
    DLABConfigurationHDMITimecodePacking                         = 'htpk',
    DLABConfigurationPlaybackGroup                               = 'plgr',
    
    /* Video Output Floats */
    
    DLABConfigurationVideoOutputComponentLumaGain                = 'oclg',
    DLABConfigurationVideoOutputComponentChromaBlueGain          = 'occb',
    DLABConfigurationVideoOutputComponentChromaRedGain           = 'occr',
    DLABConfigurationVideoOutputCompositeLumaGain                = 'oilg',
    DLABConfigurationVideoOutputCompositeChromaGain              = 'oicg',
    DLABConfigurationVideoOutputSVideoLumaGain                   = 'oslg',
    DLABConfigurationVideoOutputSVideoChromaGain                 = 'oscg',
    
    /* Video Input Flags */
    
    DLABConfigurationVideoInputScanning                          = 'visc',	// Applicable to H264 Pro Recorder only
    DLABConfigurationUseDedicatedLTCInput                        = 'dltc',	// Use timecode from LTC input instead of SDI stream
    DLABConfigurationSDIInput3DPayloadOverride                   = '3dds',
    
    /* Video Input Flags */
    
    DLABConfigurationCapture1080pAsPsF                           = 'cfpr',
    
    /* Video Input Integers */
    
    DLABConfigurationVideoInputConnection                        = 'vicn',
    DLABConfigurationAnalogVideoInputFlags                       = 'avif',
    DLABConfigurationVideoInputConversionMode                    = 'vicm',
    DLABConfiguration32PulldownSequenceInitialTimecodeFrame      = 'pdif',
    DLABConfigurationVANCSourceLine1Mapping                      = 'vsl1',
    DLABConfigurationVANCSourceLine2Mapping                      = 'vsl2',
    DLABConfigurationVANCSourceLine3Mapping                      = 'vsl3',
    DLABConfigurationCapturePassThroughMode                      = 'cptm',
    DLABConfigurationCaptureGroup                                = 'cpgr',
    
    /* Video Input Floats */
    
    DLABConfigurationVideoInputComponentLumaGain                 = 'iclg',
    DLABConfigurationVideoInputComponentChromaBlueGain           = 'iccb',
    DLABConfigurationVideoInputComponentChromaRedGain            = 'iccr',
    DLABConfigurationVideoInputCompositeLumaGain                 = 'iilg',
    DLABConfigurationVideoInputCompositeChromaGain               = 'iicg',
    DLABConfigurationVideoInputSVideoLumaGain                    = 'islg',
    DLABConfigurationVideoInputSVideoChromaGain                  = 'iscg',
    
    /* Audio Input Flags */
    
    DLABConfigurationMicrophonePhantomPower                      = 'mphp',
    
    /* Audio Input Integers */
    
    DLABConfigurationAudioInputConnection                        = 'aicn',
    
    /* Audio Input Floats */
    
    DLABConfigurationAnalogAudioInputScaleChannel1               = 'ais1',
    DLABConfigurationAnalogAudioInputScaleChannel2               = 'ais2',
    DLABConfigurationAnalogAudioInputScaleChannel3               = 'ais3',
    DLABConfigurationAnalogAudioInputScaleChannel4               = 'ais4',
    DLABConfigurationDigitalAudioInputScale                      = 'dais',
    DLABConfigurationMicrophoneInputGain                         = 'micg',
    
    /* Audio Output Integers */
    
    DLABConfigurationAudioOutputAESAnalogSwitch                  = 'aoaa',
    
    /* Audio Output Floats */
    
    DLABConfigurationAnalogAudioOutputScaleChannel1              = 'aos1',
    DLABConfigurationAnalogAudioOutputScaleChannel2              = 'aos2',
    DLABConfigurationAnalogAudioOutputScaleChannel3              = 'aos3',
    DLABConfigurationAnalogAudioOutputScaleChannel4              = 'aos4',
    DLABConfigurationDigitalAudioOutputScale                     = 'daos',
    DLABConfigurationHeadphoneVolume                             = 'hvol',
    
    /* Device Information Strings */
    
    DLABConfigurationDeviceInformationLabel                      = 'dila',
    DLABConfigurationDeviceInformationSerialNumber               = 'disn',
    DLABConfigurationDeviceInformationCompany                    = 'dico',
    DLABConfigurationDeviceInformationPhone                      = 'diph',
    DLABConfigurationDeviceInformationEmail                      = 'diem',
    DLABConfigurationDeviceInformationDate                       = 'dida',
    
    /* Deck Control Integers */
    
    DLABConfigurationDeckControlConnection                       = 'dcco'
};

/* Enum BMDDeckLinkEncoderConfigurationID - DeckLink Encoder Configuration ID */
typedef NS_ENUM(uint32_t, DLABEncoderConfiguration)
{
    /* Video Encoder Integers */
    
    DLABEncoderConfigurationPreferredBitDepth                    = 'epbr',
    DLABEncoderConfigurationFrameCodingMode                      = 'efcm',
    
    /* HEVC/H.265 Encoder Integers */
    
    DLABEncoderConfigurationH265TargetBitrate                    = 'htbr',
    
    /* DNxHR/DNxHD Compression ID */
    
    DLABEncoderConfigurationDNxHRCompressionID                   = 'dcid',
    
    /* DNxHR/DNxHD Level */
    
    DLABEncoderConfigurationDNxHRLevel                           = 'dlev',
    
    /* Encoded Sample Decriptions */
    
    DLABEncoderConfigurationMPEG4SampleDescription               = 'stsE',	// Full MPEG4 sample description (aka SampleEntry of an 'stsd' atom-box). Useful for MediaFoundation, QuickTime, MKV and more
    DLABEncoderConfigurationMPEG4CodecSpecificDesc               = 'esds'	// Sample description extensions only (atom stream, each with size and fourCC header). Useful for AVFoundation, VideoToolbox, MKV and more
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIDeckControl.h
/* =================================================================================== */

/* Enum BMDDeckControlMode - DeckControl mode */
typedef NS_ENUM(uint32_t, DLABDeckControlMode)
{
    DLABDeckControlNotOpened                                      = 'ntop',
    DLABDeckControlVTRControlMode                                 = 'vtrc',
    DLABDeckControlExportMode                                     = 'expm',
    DLABDeckControlCaptureMode                                    = 'capm'
};

/* Enum BMDDeckControlEvent - DeckControl event */
typedef NS_ENUM(uint32_t, DLABDeckControlEvent)
{
    DLABDeckControlEventAbortedEvent                                   = 'abte',	// This event is triggered when a capture or edit-to-tape operation is aborted.
    
    /* Export-To-Tape events */
    
    DLABDeckControlEventPrepareForExportEvent                          = 'pfee',	// This event is triggered a few frames before reaching the in-point. IDeckLinkInput::StartScheduledPlayback() should be called at this point.
    DLABDeckControlEventExportCompleteEvent                            = 'exce',	// This event is triggered a few frames after reaching the out-point. At this point, it is safe to stop playback.
    
    /* Capture events */
    
    DLABDeckControlEventPrepareForCaptureEvent                         = 'pfce',	// This event is triggered a few frames before reaching the in-point. The serial timecode attached to IDeckLinkVideoInputFrames is now valid.
    DLABDeckControlEventCaptureCompleteEvent                           = 'ccev'	// This event is triggered a few frames after reaching the out-point.
};

/* Enum BMDDeckControlVTRControlState - VTR Control state */
typedef NS_ENUM(uint32_t, DLABDeckControlVTRControl)
{
    DLABDeckControlVTRControlNotInVTRControlMode                            = 'nvcm',
    DLABDeckControlVTRControlPlaying                              = 'vtrp',
    DLABDeckControlVTRControlRecording                            = 'vtrr',
    DLABDeckControlVTRControlStill                                = 'vtra',
    DLABDeckControlVTRControlShuttleForward                       = 'vtsf',
    DLABDeckControlVTRControlShuttleReverse                       = 'vtsr',
    DLABDeckControlVTRControlJogForward                           = 'vtjf',
    DLABDeckControlVTRControlJogReverse                           = 'vtjr',
    DLABDeckControlVTRControlStopped                              = 'vtro'
};

/* Enum BMDDeckControlStatusFlags - Deck Control status flags */
typedef NS_OPTIONS(uint32_t, DLABDeckControlStatus)
{
    DLABDeckControlStatusDeckConnected                            = 1 << 0,
    DLABDeckControlStatusRemoteMode                               = 1 << 1,
    DLABDeckControlStatusRecordInhibited                          = 1 << 2,
    DLABDeckControlStatusCassetteOut                              = 1 << 3
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
    DLABDeckControlErrorNoError                                        = 'noer',
    DLABDeckControlErrorModeError                                      = 'moer',
    DLABDeckControlErrorMissedInPointError                             = 'mier',
    DLABDeckControlErrorDeckTimeoutError                               = 'dter',
    DLABDeckControlErrorCommandFailedError                             = 'cfer',
    DLABDeckControlErrorDeviceAlreadyOpenedError                       = 'dalo',
    DLABDeckControlErrorFailedToOpenDeviceError                        = 'fder',
    DLABDeckControlErrorInLocalModeError                               = 'lmer',
    DLABDeckControlErrorEndOfTapeError                                 = 'eter',
    DLABDeckControlErrorUserAbortError                                 = 'uaer',
    DLABDeckControlErrorNoTapeInDeckError                              = 'nter',
    DLABDeckControlErrorNoVideoFromCardError                           = 'nvfc',
    DLABDeckControlErrorNoCommunicationError                           = 'ncom',
    DLABDeckControlErrorBufferTooSmallError                            = 'btsm',
    DLABDeckControlErrorBadChecksumError                               = 'chks',
    DLABDeckControlErrorUnknownError                                   = 'uner'
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIModes.h
/* =================================================================================== */

/* Enum BMDDisplayMode - Video display modes */
typedef NS_ENUM(uint32_t, DLABDisplayMode)
{
    /* SD Modes */
    
    DLABDisplayModeNTSC                                                  = 'ntsc',
    DLABDisplayModeNTSC2398                                              = 'nt23',	// 3:2 pulldown
    DLABDisplayModePAL                                                   = 'pal ',
    DLABDisplayModeNTSCp                                                 = 'ntsp',
    DLABDisplayModePALp                                                  = 'palp',
    
    /* HD 1080 Modes */
    
    DLABDisplayModeHD1080p2398                                           = '23ps',
    DLABDisplayModeHD1080p24                                             = '24ps',
    DLABDisplayModeHD1080p25                                             = 'Hp25',
    DLABDisplayModeHD1080p2997                                           = 'Hp29',
    DLABDisplayModeHD1080p30                                             = 'Hp30',
    DLABDisplayModeHD1080p4795                                           = 'Hp47',
    DLABDisplayModeHD1080p48                                             = 'Hp48',
    DLABDisplayModeHD1080p50                                             = 'Hp50',
    DLABDisplayModeHD1080p5994                                           = 'Hp59',
    DLABDisplayModeHD1080p6000                                           = 'Hp60',	// N.B. This _really_ is 60.00 Hz.
    DLABDisplayModeHD1080p9590                                           = 'Hp95',
    DLABDisplayModeHD1080p96                                             = 'Hp96',
    DLABDisplayModeHD1080p100                                            = 'Hp10',
    DLABDisplayModeHD1080p11988                                          = 'Hp11',
    DLABDisplayModeHD1080p120                                            = 'Hp12',
    DLABDisplayModeHD1080i50                                             = 'Hi50',
    DLABDisplayModeHD1080i5994                                           = 'Hi59',
    DLABDisplayModeHD1080i6000                                           = 'Hi60',  // N.B. This _really_ is 60.00 Hz.
    
    /* HD 720 Modes */
    
    DLABDisplayModeHD720p50                                              = 'hp50',
    DLABDisplayModeHD720p5994                                            = 'hp59',
    DLABDisplayModeHD720p60                                              = 'hp60',
    
    /* 2K Modes */
    
    DLABDisplayMode2k2398                                                = '2k23',
    DLABDisplayMode2k24                                                  = '2k24',
    DLABDisplayMode2k25                                                  = '2k25',
    
    /* 2K DCI Modes */
    
    DLABDisplayMode2kDCI2398                                             = '2d23',
    DLABDisplayMode2kDCI24                                               = '2d24',
    DLABDisplayMode2kDCI25                                               = '2d25',
    DLABDisplayMode2kDCI2997                                             = '2d29',
    DLABDisplayMode2kDCI30                                               = '2d30',
    DLABDisplayMode2kDCI4795                                             = '2d47',
    DLABDisplayMode2kDCI48                                               = '2d48',
    DLABDisplayMode2kDCI50                                               = '2d50',
    DLABDisplayMode2kDCI5994                                             = '2d59',
    DLABDisplayMode2kDCI60                                               = '2d60',
    DLABDisplayMode2kDCI9590                                             = '2d95',
    DLABDisplayMode2kDCI96                                               = '2d96',
    DLABDisplayMode2kDCI100                                              = '2d10',
    DLABDisplayMode2kDCI11988                                            = '2d11',
    DLABDisplayMode2kDCI120                                              = '2d12',
    
    /* 4K Modes */
    
    DLABDisplayMode4K2160p2398                                           = '4k23',
    DLABDisplayMode4K2160p24                                             = '4k24',
    DLABDisplayMode4K2160p25                                             = '4k25',
    DLABDisplayMode4K2160p2997                                           = '4k29',
    DLABDisplayMode4K2160p30                                             = '4k30',
    DLABDisplayMode4K2160p4795                                           = '4k47',
    DLABDisplayMode4K2160p48                                             = '4k48',
    DLABDisplayMode4K2160p50                                             = '4k50',
    DLABDisplayMode4K2160p5994                                           = '4k59',
    DLABDisplayMode4K2160p60                                             = '4k60',
    DLABDisplayMode4K2160p9590                                           = '4k95',
    DLABDisplayMode4K2160p96                                             = '4k96',
    DLABDisplayMode4K2160p100                                            = '4k10',
    DLABDisplayMode4K2160p11988                                          = '4k11',
    DLABDisplayMode4K2160p120                                            = '4k12',
    
    /* 4K DCI Modes */
    
    DLABDisplayMode4kDCI2398                                             = '4d23',
    DLABDisplayMode4kDCI24                                               = '4d24',
    DLABDisplayMode4kDCI25                                               = '4d25',
    DLABDisplayMode4kDCI2997                                             = '4d29',
    DLABDisplayMode4kDCI30                                               = '4d30',
    DLABDisplayMode4kDCI4795                                             = '4d47',
    DLABDisplayMode4kDCI48                                               = '4d48',
    DLABDisplayMode4kDCI50                                               = '4d50',
    DLABDisplayMode4kDCI5994                                             = '4d59',
    DLABDisplayMode4kDCI60                                               = '4d60',
    DLABDisplayMode4kDCI9590                                             = '4d95',
    DLABDisplayMode4kDCI96                                               = '4d96',
    DLABDisplayMode4kDCI100                                              = '4d10',
    DLABDisplayMode4kDCI11988                                            = '4d11',
    DLABDisplayMode4kDCI120                                              = '4d12',
    
    /* 8K UHD Modes */
    
    DLABDisplayMode8K4320p2398                                           = '8k23',
    DLABDisplayMode8K4320p24                                             = '8k24',
    DLABDisplayMode8K4320p25                                             = '8k25',
    DLABDisplayMode8K4320p2997                                           = '8k29',
    DLABDisplayMode8K4320p30                                             = '8k30',
    DLABDisplayMode8K4320p4795                                           = '8k47',
    DLABDisplayMode8K4320p48                                             = '8k48',
    DLABDisplayMode8K4320p50                                             = '8k50',
    DLABDisplayMode8K4320p5994                                           = '8k59',
    DLABDisplayMode8K4320p60                                             = '8k60',
    
    /* 8K DCI Modes */
    
    DLABDisplayMode8kDCI2398                                             = '8d23',
    DLABDisplayMode8kDCI24                                               = '8d24',
    DLABDisplayMode8kDCI25                                               = '8d25',
    DLABDisplayMode8kDCI2997                                             = '8d29',
    DLABDisplayMode8kDCI30                                               = '8d30',
    DLABDisplayMode8kDCI4795                                             = '8d47',
    DLABDisplayMode8kDCI48                                               = '8d48',
    DLABDisplayMode8kDCI50                                               = '8d50',
    DLABDisplayMode8kDCI5994                                             = '8d59',
    DLABDisplayMode8kDCI60                                               = '8d60',
    
    /* PC Modes */
    
    DLABDisplayMode640x480p60                                            = 'vga6',
    DLABDisplayMode800x600p60                                            = 'svg6',
    DLABDisplayMode1440x900p50                                           = 'wxg5',
    DLABDisplayMode1440x900p60                                           = 'wxg6',
    DLABDisplayMode1440x1080p50                                          = 'sxg5',
    DLABDisplayMode1440x1080p60                                          = 'sxg6',
    DLABDisplayMode1600x1200p50                                          = 'uxg5',
    DLABDisplayMode1600x1200p60                                          = 'uxg6',
    DLABDisplayMode1920x1200p50                                          = 'wux5',
    DLABDisplayMode1920x1200p60                                          = 'wux6',
    DLABDisplayMode1920x1440p50                                          = '1945',
    DLABDisplayMode1920x1440p60                                          = '1946',
    DLABDisplayMode2560x1440p50                                          = 'wqh5',
    DLABDisplayMode2560x1440p60                                          = 'wqh6',
    DLABDisplayMode2560x1600p50                                          = 'wqx5',
    DLABDisplayMode2560x1600p60                                          = 'wqx6',
    
    /* RAW Modes for Cintel (input only) */
    
    DLABDisplayModeCintelRAW                                             = 'rwci',  // Frame size up to 4096x3072, variable frame rate
    DLABDisplayModeCintelCompressedRAW                                   = 'rwcc',  // Frame size up to 4096x3072, variable frame rate
    
    /* Special Modes */
    
    DLABDisplayModeUnknown                                               = 'iunk'
};

/* Enum BMDFieldDominance - Video field dominance */
typedef NS_ENUM(uint32_t, DLABFieldDominance)
{
    DLABFieldDominanceUnknown                                     = 0,
    DLABFieldDominanceLowerFieldFirst                                           = 'lowr',
    DLABFieldDominanceUpperFieldFirst                                           = 'uppr',
    DLABFieldDominanceProgressiveFrame                                          = 'prog',
    DLABFieldDominanceProgressiveSegmentedFrame                                 = 'psf '
};

/* Enum BMDPixelFormat - Video pixel formats supported for output/input */
typedef NS_ENUM(uint32_t, DLABPixelFormat)
{
    DLABPixelFormatUnspecified                                         = 0,
    DLABPixelFormat8BitYUV                                             = '2vuy',
    DLABPixelFormat10BitYUV                                            = 'v210',
    DLABPixelFormat8BitARGB                                            = 32,
    DLABPixelFormat8BitBGRA                                            = 'BGRA',
    DLABPixelFormat10BitRGB                                            = 'r210',	// Big-endian RGB 10-bit per component with SMPTE video levels (64-960). Packed as 2:10:10:10
    DLABPixelFormat12BitRGB                                            = 'R12B',	// Big-endian RGB 12-bit per component with full range (0-4095). Packed as 12-bit per component
    DLABPixelFormat12BitRGBLE                                          = 'R12L',	// Little-endian RGB 12-bit per component with full range (0-4095). Packed as 12-bit per component
    DLABPixelFormat10BitRGBXLE                                         = 'R10l',	// Little-endian 10-bit RGB with SMPTE video levels (64-940)
    DLABPixelFormat10BitRGBX                                           = 'R10b',	// Big-endian 10-bit RGB with SMPTE video levels (64-940)
    DLABPixelFormatH265                                                = 'hev1',	// High Efficiency Video Coding (HEVC/h.265)
    
    /* AVID DNxHR */
    
    DLABPixelFormatDNxHR                                               = 'AVdh',
    
    /* Cintel formats */
    
    DLABPixelFormat12BitRAWGRBG                                        = 'r12p',  // 12-bit RAW data for bayer pattern GRBG
    DLABPixelFormat12BitRAWJPEG                                        = 'r16p'   // 12-bit RAW data arranged in tiles and JPEG compressed
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
    DLABStreamingDeviceModeIdle                                       = 'idle',
    DLABStreamingDeviceModeEncoding                                   = 'enco',
    DLABStreamingDeviceModeStopping                                   = 'stop',
    DLABStreamingDeviceModeUnknown                                    = 'munk'
};

/* Enum BMDStreamingEncodingFrameRate - Encoded frame rates */
typedef NS_ENUM(uint32_t, DLABStreamingEncodingFrameRate)
{
    /* Interlaced rates */
    
    DLABStreamingEncodedFrameRate50i                              = 'e50i',
    DLABStreamingEncodedFrameRate5994i                            = 'e59i',
    DLABStreamingEncodedFrameRate60i                              = 'e60i',
    
    /* Progressive rates */
    
    DLABStreamingEncodedFrameRate2398p                            = 'e23p',
    DLABStreamingEncodedFrameRate24p                              = 'e24p',
    DLABStreamingEncodedFrameRate25p                              = 'e25p',
    DLABStreamingEncodedFrameRate2997p                            = 'e29p',
    DLABStreamingEncodedFrameRate30p                              = 'e30p',
    DLABStreamingEncodedFrameRate50p                              = 'e50p',
    DLABStreamingEncodedFrameRate5994p                            = 'e59p',
    DLABStreamingEncodedFrameRate60p                              = 'e60p'
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
    DLABStreamingVideoCodecH264                                   = 'H264'
};

/* Enum BMDStreamingH264Profile - H264 encoding profile */
typedef NS_ENUM(uint32_t, DLABStreamingH264Profile)
{
    DLABStreamingH264ProfileHigh                                  = 'high',
    DLABStreamingH264ProfileMain                                  = 'main',
    DLABStreamingH264ProfileBaseline                              = 'base'
};

/* Enum BMDStreamingH264Level - H264 encoding level */
typedef NS_ENUM(uint32_t, DLABStreamingH264Level)
{
    DLABStreamingH264Level12                                      = 'lv12',
    DLABStreamingH264Level13                                      = 'lv13',
    DLABStreamingH264Level2                                       = 'lv2 ',
    DLABStreamingH264Level21                                      = 'lv21',
    DLABStreamingH264Level22                                      = 'lv22',
    DLABStreamingH264Level3                                       = 'lv3 ',
    DLABStreamingH264Level31                                      = 'lv31',
    DLABStreamingH264Level32                                      = 'lv32',
    DLABStreamingH264Level4                                       = 'lv4 ',
    DLABStreamingH264Level41                                      = 'lv41',
    DLABStreamingH264Level42                                      = 'lv42'
};

/* Enum BMDStreamingH264EntropyCoding - H264 entropy coding */
typedef NS_ENUM(uint32_t, DLABStreamingH264EntropyCoding)
{
    DLABStreamingH264EntropyCodingCAVLC                           = 'EVLC',
    DLABStreamingH264EntropyCodingCABAC                           = 'EBAC'
};

/* Enum BMDStreamingAudioCodec - Audio codecs */
typedef NS_ENUM(uint32_t, DLABStreamingAudioCodec)
{
    DLABStreamingAudioCodecAAC                                    = 'AAC '
};

/* Enum BMDStreamingEncodingModePropertyID - Encoding mode properties */
typedef NS_ENUM(uint32_t, DLABStreamingEncodingProperty)
{
    /* Integers, Video Properties */
    
    DLABStreamingEncodingPropertyVideoFrameRate                   = 'vfrt',	// Uses values of type BMDStreamingEncodingFrameRate
    DLABStreamingEncodingPropertyVideoBitRateKbps                 = 'vbrt',
    
    /* Integers, H264 Properties */
    
    DLABStreamingEncodingPropertyH264Profile                      = 'hprf',
    DLABStreamingEncodingPropertyH264Level                        = 'hlvl',
    DLABStreamingEncodingPropertyH264EntropyCoding                = 'hent',
    
    /* Flags, H264 Properties */
    
    DLABStreamingEncodingPropertyH264HasBFrames                   = 'hBfr',
    
    /* Integers, Audio Properties */
    
    DLABStreamingEncodingPropertyAudioCodec                       = 'acdc',
    DLABStreamingEncodingPropertyAudioSampleRate                  = 'asrt',
    DLABStreamingEncodingPropertyAudioChannelCount                = 'achc',
    DLABStreamingEncodingPropertyAudioBitRateKbps                 = 'abrt'
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
    DLABTimecodeFlagEmbedRecordingTrigger                             = 1 << 3,  // On SDI recording trigger utilises a user-bit
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
// MARK: - From DeckLinkAPI_v10_11.h
/* =================================================================================== */

/* DEPRECATED@11.0 */ /* Enum BMDDisplayModeSupport_v10_11 - Output mode supported flags */
typedef NS_ENUM(uint32_t, DLABDisplayModeSupportFlag1011)
{
    DLABDisplayModeSupportFlag1011NotSupported                                   = 0,
    DLABDisplayModeSupportFlag1011Supported,
    DLABDisplayModeSupportFlag1011SupportedWithConversion
};

/* DEPRECATED@11.0 */ /* Enum BMDDuplexMode_v10_11 - Duplex for configurable ports */
typedef NS_ENUM(uint32_t, DLABDuplexMode1011)
{
    DLABDuplexMode1011Full                                            = 'fdup',
    DLABDuplexMode1011Half                                            = 'hdup'
};

/* DEPRECATED@11.0 */ /* Enum BMDDeckLinkAttributeID_v10_11 - DeckLink Attribute ID */
typedef NS_ENUM(uint32_t, DLABAttribute1011)
{
    /* Flags */
    
    DLABAttribute1011SupportsDuplexModeConfiguration                   = 'dupx',
    DLABAttribute1011SupportsHDKeying                                  = 'keyh',
    
    /* Integers */
    
    DLABAttribute1011PairedDevicePersistentID                          = 'ppid',
    DLABAttribute1011SupportsFullDuplex                                = 'fdup',
};

/* DEPRECATED@11.0 */ /* Enum BMDDeckLinkStatusID_v10_11 - DeckLink Status ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkStatus1011)
{
    DLABDeckLinkStatus1011DuplexMode                                  = 'dupx',
};

/* DEPRECATED@11.0 */ /* Enum BMDDuplexStatus_v10_11 - Duplex status of the device */
typedef NS_ENUM(uint32_t, DLABDuplexStatus1011)
{
    DLABDuplexStatus1011FullDuplex                                    = 'fdup',
    DLABDuplexStatus1011HalfDuplex                                    = 'hdup',
    DLABDuplexStatus1011Simplex                                       = 'splx',
    DLABDuplexStatus1011Inactive                                      = 'inac'
};

/* =================================================================================== */
// MARK: - From DeckLinkAPIConfiguration_v10_11.h
/* =================================================================================== */

/* DEPRECATED@11.0 */ /* Enum BMDDeckLinkConfigurationID - DeckLink Configuration ID */
typedef NS_ENUM(uint32_t, DLABConfiguration1011)
{
    /* Video Input/Output Integers */
    
    DLABConfiguration1011DuplexMode                                  = 'dupx',
};

/* =================================================================================== */
