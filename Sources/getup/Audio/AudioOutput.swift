import CoreAudio
import Foundation

/// 'hdpn' fourCC = headphone-jack data source on built-in audio.
private let kDataSourceHeadphone: UInt32 = 0x6864706E

func defaultOutputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &addr, 0, nil, &size, &deviceID
    )
    return status == noErr ? deviceID : nil
}

func transportType(of device: AudioDeviceID) -> UInt32? {
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value)
    return status == noErr ? value : nil
}

func outputDataSource(of device: AudioDeviceID) -> UInt32? {
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDataSource,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value)
    return status == noErr ? value : nil
}

/// Closed-fail headphone classifier. Unknown / HDMI / DisplayPort / AirPlay → false.
/// Built-in transport is only "headphones" when the data source reports `'hdpn'`.
/// Bluetooth / USB / FireWire / Thunderbolt are treated as headphones unconditionally.
func isHeadphoneOutput() -> Bool {
    guard let dev = defaultOutputDeviceID(),
          let transport = transportType(of: dev) else {
        return false
    }
    switch transport {
    case kAudioDeviceTransportTypeBluetooth,
         kAudioDeviceTransportTypeBluetoothLE:
        return true
    case kAudioDeviceTransportTypeUSB,
         kAudioDeviceTransportTypeFireWire,
         kAudioDeviceTransportTypeThunderbolt:
        return true
    case kAudioDeviceTransportTypeBuiltIn:
        return outputDataSource(of: dev) == kDataSourceHeadphone
    default:
        return false
    }
}
