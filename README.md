## DLABridging.framework

Simple Objective-C++ wrapper for Blackmagic DeckLink API (C++ APIs).

- __Requirement__: macOS 26.x, 15.x, 14.x, 13.x, 12.x, 11.x.
- __Capture Device__: Blackmagic DeckLink devices/UltraStudio devices.
- __Restriction__: Compressed/Synchronized/IP captures are not supported.
- __Dependency__: DeckLinkAPI.framework from Blackmagic_Desktop_Video_Macintosh (11.4-11.7, 12.0-12.9, 14.0-14.2, 15.0-15.3.1, **16.0**)
- __Architecture__: Universal binary (x86_64 + arm64)

NOTE: This framework is under development.

#### About unsupported feature(s):

    : Following interfaces are not supported. (Section # are from SDK 16.0 pdf)
    : 2.5.8 IDeckLinkVideoFrame3DExtensions
    : 2.5.25 IDeckLinkGLScreenPreviewHelper
    : 2.5.26 IDeckLinkCocoaScreenPreviewCallback
    : 2.5.27 IDeckLinkDX9ScreenPreviewHelper
    : 2.5.34 IDeckLinkEncoderInput
    : 2.5.35 IDeckLinkEncoderInputCallback
    : 2.5.36 IDeckLinkEncoderPacket
    : 2.5.37 IDeckLinkEncoderVideoPacket
    : 2.5.38 IDeckLinkEncoderAudioPacket
    : 2.5.39 IDeckLinkH265NALPacket
    : 2.5.40 IDeckLinkEncoderConfiguration
    : 2.5.43 IDeckLinkVideoConversion
    : 2.5.49 IDeckLinkMetalScreenPreviewHelper
    : 2.5.50 IDeckLinkWPFDX9ScreenPreviewHelper
    : 2.5.51 IDeckLinkMacOutput
    : 2.5.52 IDeckLinkMacVideoBuffer
    : 2.5.53 IDeckLinkVideoBuffer
    : 2.5.54 IDeckLinkVideoBufferAllocatorProvider
    : 2.5.55 IDeckLinkVideoBufferAllocator
    : 2.5.57 IDeckLinkIPExtensions
    : 2.5.58 IDeckLinkIPFlowIterator
    : 2.5.59 IDeckLinkIPFlow
    : 2.5.60 IDeckLinkIPFlowAttributes
    : 2.5.61 IDeckLinkIPFlowStatus
    : 2.5.62 IDeckLinkIPFlowSetting
    : 2.6.x Any Streaming Interface APIs

#### Basic usage (capture)

###### 1. Find DLABDevice using DLABBrowser
    import Cocoa
    import DLABridging
    var device :DLABDevice? = nil
    var running :Bool = false
    do {
      let browser = DLABBrowser()
      _ = browser.registerDevicesForInput()
      let deviceList = browser.allDevices
      device = deviceList.first!
    }

###### 2. Start input stream
    if let device = device {
      try device.setInputScreenPreviewTo(parentView)

      // Choose one input connection pair
      let videoConnection :DLABVideoConnection = .HDMI
      let audioConnection :DLABAudioConnection = .embedded
      // let videoConnection :DLABVideoConnection = .sVideo
      // let audioConnection :DLABAudioConnection = .analogRCA

      // To prepare SD Video setting
      var vSetting:DLABVideoSetting? = nil
      try vSetting = device.createInputVideoSetting(of: .modeNTSC,
                                                    pixelFormat: .format8BitYUV,
                                                    inputFlag: [])

      // To prepare Audio setting (use 8ch for HDMI surround)
      var aSetting:DLABAudioSetting? = nil
      let audioChannelCount: UInt32 = (videoConnection == .HDMI && audioConnection == .embedded) ? 8 : 2
      try aSetting = device.createInputAudioSetting(of: .type16bitInteger,
                                                    channelCount: audioChannelCount,
                                                    sampleRate: .rate48kHz)

      // To support NTSC-SD CleanAperture and PixelAspectRatio
      if let vSetting = vSetting {
        try vSetting.addClapExt(ofWidthN: 704, widthD: 1,
                                heightN: 480, heightD: 1,
                                hOffsetN: 4, hOffsetD: 1,
                                vOffsetN: 0, vOffsetD: 1)
        try vSetting.addPaspExt(ofHSpacing: 40,
                                vSpacing: 33)
      }

      // To capture using preferred CVPixelFormat
      var myCVPixelFormat :OSType = kCVPixelFormatType_32BGRA
      vSetting.cvPixelFormatType = myCVPixelFormat
      try vSetting.buildVideoFormatDescription()

      // To support HDMI surround audio; audioSetting channelCount should be 8
      var hdmiAudioChannels = 6 // HDMI surround 5.1ch
      var reverseCh3Ch4 = true // For layout of (ch3, ch4) == (LFE, C)
      if let aSetting = aSetting, videoConnection == .HDMI, audioConnection == .embedded,
        aSetting.channelCount == 8, aSetting.channelCount >= hdmiAudioChannels, hdmiAudioChannels > 0 {
        // rebuild formatDescription to support HDMI Audio Channel order
        try aSetting.buildAudioFormatDescription(forHDMIAudioChannels: hdmiAudioChannels,
                                                 swap3chAnd4ch: reverseCh3Ch4)
      }

      if let vSetting = vSetting, let aSetting = aSetting {
        device.inputDelegate = self
        try device.enableVideoInput(with: vSetting, on: videoConnection)
        try device.enableAudioInput(with: aSetting, on: audioConnection)
        try device.startStreams()
        running = true
      }
    } catch {
      print("ERROR!!")
      :
    }

###### 3. Handle CMSampleBuffer (Video/Audio)
    public func processCapturedVideoSample(_ sampleBuffer: CMSampleBuffer,
                                           of sender:DLABDevice) {
      print("video")
    }
    public func processCapturedAudioSample(_ sampleBuffer: CMSampleBuffer,
                                           of sender:DLABDevice) {
      print("audio")
    }
    public func processCapturedVideoSample(_ sampleBuffer: CMSampleBuffer,
                                           timecodeSetting setting: DLABTimecodeSetting,
                                           of sender:DLABDevice) {
      print("video/timecode")
    }

###### 4. Stop input stream
    running = false
    if let device = device {
      try device.stopStreams()
      try device.disableVideoInput()
      try device.disableAudioInput()
      device.inputDelegate = nil
      try device.setInputScreenPreviewTo(nil)
    } catch {
      print("ERROR!!")
    }
    device = nil

#### Developer Notice

###### 1. AppEntitlements for Sandboxing
- See: Blackmagic DeckLink SDK pdf Section 2.2.
- Ref: "Entitlement Key Reference/App Sandbox Temporary Exception Entitlements" from Apple Developer Documentation Archive

###### 2. AppEntitlements for Hardened Runtime
- Set com.apple.security.cs.disable-library-validation to YES.
- Ref: "Documentation/Bundle Resources/Entitlements/Hardened Runtime/Disable Library Validation Entitlement" from Apple Developer Documentation.

#### Development environment
- macOS 26.4.1 Tahoe
- Xcode 26.4.1
- Swift 6.3.1

#### License
- The MIT License

Copyright © 2017-2026年 MyCometG3. All rights reserved.
