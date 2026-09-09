import CoreAudio
import Foundation

enum SystemOutputVolume {
    static func read() -> Double {
        guard let device = defaultOutputDevice() else { return 0 }
        if let master = scalar(device: device, channel: 0) { return master }
        if let left = scalar(device: device, channel: 1) { return left }
        return 0
    }

    static func write(_ value: Double) {
        guard let device = defaultOutputDevice() else { return }
        let volume = Float32(min(1, max(0, value)))
        setScalar(device: device, channel: 0, volume)
        setScalar(device: device, channel: 1, volume)
        setScalar(device: device, channel: 2, volume)
    }

    static func deviceName() -> String? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &cfName) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return cfName?.takeRetainedValue() as String?
    }

    private static func scalar(device: AudioDeviceID, channel: UInt32) -> Double? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        return status == noErr ? min(1, max(0, Double(volume))) : nil
    }

    private static func setScalar(device: AudioDeviceID, channel: UInt32, _ volume: Float32) {
        var value = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        let size = UInt32(MemoryLayout<Float32>.size)
        _ = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        return status == noErr ? device : nil
    }
}
