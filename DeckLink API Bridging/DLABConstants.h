//
//  DLABConstants.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

/**
 Swift-safe NS_ENUM/NS_OPTIONS definition
 
 NOTE: This constants are converted from DekLink API "10.9.x"
 NOTE: Basic renaming rules are:
 1. each enum type name BMDtypename => DLABtypename (DeckLink API bridging)
 1a. remove "s" at end of typename
 1b. No "ID" at end of typename
 2. each bmdValuename modified as typename + valuename (DLABtypename+valuename)
 3. a few NS_ENUM/NS_OPTIONS contains extention for easy to use ("// Non-native extention @@@@")
 */

/* =================================================================================== */
// MARK: - From DeckLinkAPIVersion.h
/* =================================================================================== */

/*
 Derived from: Blackmagic_DeckLink_SDK_10.9.5.zip @ 2017/07/20 UTC
 
 #define BLACKMAGIC_DECKLINK_API_VERSION					0x0a090500
 #define BLACKMAGIC_DECKLINK_API_VERSION_STRING			"10.9.5"
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
    DLABVideoOutputFlagDualStream3D                                   = 1 << 4
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
    
    DLABFrameFlagHasNoInputSource                                     = 1U << 31     // Non-native extention @@@@
};

/* Enum BMDVideoInputFlags - Flags applicable to video input */
typedef NS_OPTIONS(uint32_t, DLABVideoInputFlag)
{
    DLABVideoInputFlagDefault                                     = 0,
    DLABVideoInputFlagEnableFormatDetection                           = 1 << 0,
    DLABVideoInputFlagDualStream3D                                    = 1 << 1
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

/* Enum BMDDisplayModeSupport - Output mode supported flags */
typedef NS_ENUM(uint32_t, DLABDisplayModeSupportFlag)
{
    DLABDisplayModeSupportFlagNotSupported                                   = 0,
    DLABDisplayModeSupportFlagSupported,
    DLABDisplayModeSupportFlagSupportedWithConversion
};

/* Enum BMDTimecodeFormat - Timecode formats for frame metadata */
typedef NS_ENUM(uint32_t, DLABTimecodeFormat)
{
    DLABTimecodeFormatRP188VITC1                                        = 'rpv1',	// RP188 timecode where DBB1 equals VITC1 (line 9)
    DLABTimecodeFormatRP188VITC2                                        = 'rp12',	// RP188 timecode where DBB1 equals VITC2 (line 9 for progressive or line 571 for interlaced/PsF)
    DLABTimecodeFormatRP188LTC                                          = 'rplt',	// RP188 timecode where DBB1 equals LTC (line 10)
    DLABTimecodeFormatRP188Any                                          = 'rp18',	// For capture: return the first valid timecode in {VITC1, LTC ,VITC2} - For playback: set the timecode as VITC1
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

/* Enum BMDDeckLinkFrameMetadataID - DeckLink Frame Metadata ID */
typedef NS_ENUM(uint32_t, DLABDeckLinkFrameMetadata)
{
    DLABDeckLinkFrameMetadataHDRElectroOpticalTransferFunc        = 'eotf',	// EOTF in range 0-7 as per CEA 861.3
    DLABDeckLinkFrameMetadataCintelFilmType                       = 'cfty',	// Current film type
    DLABDeckLinkFrameMetadataCintelFilmGauge                      = 'cfga',	// Current film gauge
    DLABDeckLinkFrameMetadataCintelOffsetDetectedHorizontal       = 'odfh',	// Horizontal offset (pixels) detected in image
    DLABDeckLinkFrameMetadataCintelOffsetDetectedVertical         = 'odfv',	// Vertical offset (pixels) detected in image
    DLABDeckLinkFrameMetadataCintelOffsetAppliedHorizontal        = 'odah',	// Horizontal offset (pixels) applied to image
    DLABDeckLinkFrameMetadataCintelOffsetAppliedVertical          = 'odav',	// Vertical offset (pixels) applied to image
    DLABDeckLinkFrameMetadataCintelKeykodeLow                     = 'ckkl',	// Raw keykode value - low 64 bits
    DLABDeckLinkFrameMetadataCintelKeykodeHigh                    = 'ckkh',	// Raw keykode value - high 64 bits
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
    DLABDeckLinkFrameMetadataCintel16mmCropRequired               = 'c16c',	// The image should be cropped to 16mm size
    DLABDeckLinkFrameMetadataCintelInversionRequired              = 'cinv',	// The image should be colour inverted
    DLABDeckLinkFrameMetadataCintelFlipRequired                   = 'cflr',	// The image should be flipped horizontally
    DLABDeckLinkFrameMetadataCintelFocusAssistEnabled             = 'cfae',	// Focus Assist is currently enabled
    DLABDeckLinkFrameMetadataCintelKeykodeIsInterpolated          = 'kkii'	// The keykode for this frame is interpolated from nearby keykodes
};

/* Enum BMDDuplexMode - Duplex for configurable ports */
typedef NS_ENUM(uint32_t, DLABDuplexMode)
{
    DLABDuplexModeFull                                            = 'fdup',
    DLABDuplexModeHalf                                            = 'hdup'
};

/* Enum BMDDeckLinkAttributeID - DeckLink Attribute ID */
typedef NS_ENUM(uint32_t, DLABAttribute)
{
    /* Flags */
    
    DLABAttributeSupportsInternalKeying                            = 'keyi',
    DLABAttributeSupportsExternalKeying                            = 'keye',
    DLABAttributeSupportsHDKeying                                  = 'keyh',
    DLABAttributeSupportsInputFormatDetection                      = 'infd',
    DLABAttributeHasReferenceInput                                 = 'hrin',
    DLABAttributeHasSerialPort                                     = 'hspt',
    DLABAttributeHasAnalogVideoOutputGain                          = 'avog',
    DLABAttributeCanOnlyAdjustOverallVideoOutputGain               = 'ovog',
    DLABAttributeHasVideoInputAntiAliasingFilter                   = 'aafl',
    DLABAttributeHasBypass                                         = 'byps',
    DLABAttributeSupportsClockTimingAdjustment                     = 'ctad',
    DLABAttributeSupportsFullDuplex                                = 'fdup',
    DLABAttributeSupportsFullFrameReferenceInputTimingOffset       = 'frin',
    DLABAttributeSupportsSMPTELevelAOutput                         = 'lvla',
    DLABAttributeSupportsDualLinkSDI                               = 'sdls',
    DLABAttributeSupportsQuadLinkSDI                               = 'sqls',
    DLABAttributeSupportsIdleOutput                                = 'idou',
    DLABAttributeHasLTCTimecodeInput                               = 'hltc',
    DLABAttributeSupportsDuplexModeConfiguration                   = 'dupx',
    DLABAttributeSupportsHDRMetadata                               = 'hdrm',
    
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
    DLABAttributePairedDevicePersistentID                          = 'ppid',
    
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
    DLABDeckLinkStatusDuplexMode                                  = 'dupx',
    DLABDeckLinkStatusBusy                                        = 'busy',
    DLABDeckLinkStatusInterchangeablePanelType                    = 'icpt',
    
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

/* Enum BMDDuplexStatus - Duplex status of the device */
typedef NS_ENUM(uint32_t, DLABDuplexStatus)
{
    DLABDuplexStatusFullDuplex                                    = 'fdup',
    DLABDuplexStatusHalfDuplex                                    = 'hdup',
    DLABDuplexStatusSimplex                                       = 'splx',
    DLABDuplexStatusInactive                                      = 'inac'
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
    DLABVideoIOSupportNone = 0,             // Non-native extention @@@@
    
    DLABVideoIOSupportCapture                                     = 1 << 0,
    DLABVideoIOSupportPlayback                                    = 1 << 1
    
    , DLABVideoIOSupportInternalKeying = 1 << 16     // Non-native extention @@@@
    , DLABVideoIOSupportExternalKeying = 1 << 17     // Non-native extention @@@@
    , DLABVideoIOSupportHDKeying = 1 << 18     // Non-native extention @@@@
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
    DLABConfigurationDuplexMode                                  = 'dupx',
    
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
    DLABDisplayModeHD1080i50                                             = 'Hi50',
    DLABDisplayModeHD1080i5994                                           = 'Hi59',
    DLABDisplayModeHD1080i6000                                           = 'Hi60',	// N.B. This _really_ is 60.00 Hz.
    DLABDisplayModeHD1080p50                                             = 'Hp50',
    DLABDisplayModeHD1080p5994                                           = 'Hp59',
    DLABDisplayModeHD1080p6000                                           = 'Hp60',	// N.B. This _really_ is 60.00 Hz.
    
    /* HD 720 Modes */
    
    DLABDisplayModeHD720p50                                              = 'hp50',
    DLABDisplayModeHD720p5994                                            = 'hp59',
    DLABDisplayModeHD720p60                                              = 'hp60',
    
    /* 2k Modes */
    
    DLABDisplayMode2k2398                                                = '2k23',
    DLABDisplayMode2k24                                                  = '2k24',
    DLABDisplayMode2k25                                                  = '2k25',
    
    /* DCI Modes (output only) */
    
    DLABDisplayMode2kDCI2398                                             = '2d23',
    DLABDisplayMode2kDCI24                                               = '2d24',
    DLABDisplayMode2kDCI25                                               = '2d25',
    
    /* 4k Modes */
    
    DLABDisplayMode4K2160p2398                                           = '4k23',
    DLABDisplayMode4K2160p24                                             = '4k24',
    DLABDisplayMode4K2160p25                                             = '4k25',
    DLABDisplayMode4K2160p2997                                           = '4k29',
    DLABDisplayMode4K2160p30                                             = '4k30',
    DLABDisplayMode4K2160p50                                             = '4k50',
    DLABDisplayMode4K2160p5994                                           = '4k59',
    DLABDisplayMode4K2160p60                                             = '4k60',
    
    /* DCI Modes (output only) */
    
    DLABDisplayMode4kDCI2398                                             = '4d23',
    DLABDisplayMode4kDCI24                                               = '4d24',
    DLABDisplayMode4kDCI25                                               = '4d25',
    
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
    
    DLABPixelFormatDNxHR                                               = 'AVdh'
};

/* Enum BMDDisplayModeFlags - Flags to describe the characteristics of an IDeckLinkDisplayMode. */
typedef NS_OPTIONS(uint32_t, DLABDisplayModeFlag)
{
    DLABDisplayModeFlagSupports3D                                     = 1 << 0,
    DLABDisplayModeFlagColorspaceRec601                               = 1 << 1,
    DLABDisplayModeFlagColorspaceRec709                               = 1 << 2
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
    DLABTimecodeFlagColorFrame                                        = 1 << 2
};

/* Enum BMDVideoConnection - Video connection types */
typedef NS_OPTIONS(uint32_t, DLABVideoConnection)
{
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
