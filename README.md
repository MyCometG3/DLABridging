## DLABridging.framework

Simple Objective-C++ wrapper for Blackmagic DeckLink API (C++ APIs).

- __Requirement__: macOS 14.x, 13.x, 12.x, 11.x, 10.15, 10.14.
- __Capture Device__: Blackmagic DeckLink devices/UltraStudio devices.
- __Restriction__: Compressed/Synchronized captures are not supported.
- __Dependency__: DeckLinkAPI.framework from Blackmagic_Desktop_Video_Macintosh (11.4-11.7, 12.0-12.9, 14.0)
- __Architecture__: Universal binary (x86_64 + arm64)

NOTE: This framework is under development.

#### About unsupported feature(s):

    : Following interfaces are not supported. (Section # are from SDK 12.9 pdf)
    : 2.5.8 IDeckLinkVideoFrame3DExtensions
    : 2.5.18 IDeckLinkMemoryAllocator
    : 2.5.26 IDeckLinkGLScreenPreviewHelper
    : 2.5.27 IDeckLinkCocoaScreenPreviewCallback
    : 2.5.28 IDeckLinkDX9ScreenPreviewHelper
    : 2.5.35 IDeckLinkEncoderInput
    : 2.5.36 IDeckLinkEncoderInputCallback
    : 2.5.37 IDeckLinkEncoderPacket
    : 2.5.38 IDeckLinkEncoderVideoPacket
    : 2.5.39 IDeckLinkEncoderAudioPacket
    : 2.5.40 IDeckLinkH265NALPacket
    : 2.5.41 IDeckLinkEncoderConfiguration
    : 2.5.44 IDeckLinkVideoConversion
    : 2.5.50 IDeskLinkMetalScreenPreviewHelper
    : 2.5.51 IDeckLinkWPFDX9ScreenPreviewHelper
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

      // To capture HDMI
      var videoConnection :DLABVideoConnection = .HDMI
      var audioConnection :DLABAudioConnection = .embedded

      // To capture SVideo+RCA
      var videoConnection :DLABVideoConnection = .sVideo
      var audioConnection :DLABAudioConnection = .analogRCA

      // To prepare SD Video setting
      var vSetting:DLABVideoSetting? = nil
      try vSetting = device.createInputVideoSetting(of: .modeNTSC,
                                                    pixelFormat: .format8BitYUV,
                                                    inputFlag: [])

      // To prepare stereo Audio setting
      var aSetting:DLABAudioSetting? = nil
      try aSetting = device.createInputAudioSetting(of: .type16bitInteger,
                                                    channelCount: 2,
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
        audioChannels == 8, audioChannels >= hdmiAudioChannels, hdmiAudioChannels > 0 {
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
- macOS 14.5 Sonoma
- Xcode 15.4
- Swift 5.10

#### License
- The MIT License

Copyright © 2017-2024年 MyCometG3. All rights reserved.
