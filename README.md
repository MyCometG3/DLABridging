## DLABridging.framework

Simple Objective-C++ wrapper for Blackmagic DeckLink API (C++ APIs).

- __Requirement__: MacOS X 10.11 or later.
- __Capture Device__: Blackmagic Intensity Shuttle, or other DeckLink devices.
- __Restriction__: Only 8 or 10 bit yuv, or 8 bit rgb are supported.
- __Dependency__: DeckLinkAPI.framework from Blackmagic_Desktop_Video_Macintosh_11.2 or later.

NOTE: This framework is under development.
NOTE: Currently following features are not supported.
  : IDeckLinkVideoFrame3DExtensions
  : IDeckLinkAPIInformation
  : IDeckLinkMemoryAllocator
  : IDeckLinkScreenPreviewCallback, IDeckLinkGLScreenPreviewHelper
  : IDeckLinkDeckControl, IDeckLinkDeckControlStatusCallback
  : Any encoder related class - IBMDStreaming*, IDeckLinkEncoder*, etc.
  : IDeckLinkVideoFrameMetadataExtensions
  : IDeckLinkVideoConversion
  : High-End features - IDeckLinkProfileIterator, -Callback, -Manager

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

      if let vSetting = vSetting, let aSetting = aSetting {
        device.inputDelegate = self
        try device.enableVideoInput(with: vSetting)
        try device.enableAudioInput(with: aSetting)
        try device.startStreams()
        running = true
      }
    } catch {
      print("ERROR!!")


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
- MacOS X 10.14.5 Mojave
- Xcode 10.2.1
- Objective-C++, Swift 5.0.1

#### License
    - The MIT License

Copyright © 2017-2019年 MyCometG3. All rights reserved.
