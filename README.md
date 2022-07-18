## DLABridging.framework

Simple Objective-C++ wrapper for Blackmagic DeckLink API (C++ APIs).

- __Requirement__: macOS 12.x, 11.x, 10.15, 10.14.
- __Capture Device__: Blackmagic DeckLink devices.
- __Restriction__: Compressed/Synchronized captures are not supported.
- __Dependency__: DeckLinkAPI.framework from Blackmagic_Desktop_Video_Macintosh (11.4-11.7, 12.0-12.4)
- __Architecture__: Universal binary (x86_64 + arm64)

NOTE: This framework is under development.

#### About unsupported feature(s):

    : Following interfaces are not supported. (Section # are from SDK 12.3 pdf)
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
    do {
      try device.setInputScreenPreviewTo(parentView)

      var vSetting:DLABVideoSetting? = nil
      try vSetting = device.createInputVideoSetting(of: .modeNTSC,
                                                    pixelFormat: .format8BitYUV,
                                                    inputFlag: [])
      var aSetting:DLABAudioSetting? = nil
      try aSetting = device.createInputAudioSetting(of: .type16bitInteger,
                                                    channelCount: 2,
                                                    sampleRate: .rate48kHz)
      if let vSetting = vSetting {
        try vSetting.addClapExt(ofWidthN: 704, widthD: 1,
                                heightN: 480, heightD: 1,
                                hOffsetN: 4, hOffsetD: 1,
                                vOffsetN: 0, vOffsetD: 1)
        try vSetting.addPaspExt(ofHSpacing: 40,
                                vSpacing: 33)
      }

      // rebuild formatDescription with new CVPixelFormat
      // vSetting.cvPixelFormatType = cvPixelFormat
      // try vSetting.buildVideoFormatDescription()

      if let vSetting = vSetting, let aSetting = aSetting {
        device.inputDelegate = self
        try device.enableVideoInput(with: vSetting, on: .HDMI)
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
    do {
      try device.stopStreams()
      try device.disableVideoInput()
      try device.disableAudioInput()
      device.inputDelegate = nil
      try device.setInputScreenPreviewTo(nil)
    } catch {
      print("ERROR!!")
    }
    device = nil

#### Development environment
- macOS 12.4 Monterey
- Xcode 13.4.1
- Swift 5.6.1

#### License
- The MIT License

Copyright © 2017-2022年 MyCometG3. All rights reserved.
