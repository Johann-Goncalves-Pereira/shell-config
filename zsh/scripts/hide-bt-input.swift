#!/usr/bin/env swift
// hide-bt-input.swift
// Temporarily hide Bluetooth headset microphones for the current connection:
// deactivate BT input streams, mute input, and set a Mac-mic-only aggregate
// as the default system input so Chromium/Discord cannot probe BT transport.
//
// Usage:
//   hide-bt-input            # hide + ensure HQ Call Mic aggregate
//   hide-bt-input --status   # print BT input devices + running state
//   hide-bt-input --list     # list inputs
//
// After a Bluetooth disconnect/reconnect, CoreAudio rebuilds the device with
// input enabled again — this hide is intentionally temporary.

import CoreAudio
import Foundation

let aggregateUID = "com.shell-config.hq-call-mic"
let aggregateName = "HQ Call Mic"

struct AudioDeviceInfo {
  let id: AudioDeviceID
  let uid: String
  let name: String
  let transportType: UInt32
  let hasInput: Bool
  let hasOutput: Bool

  var isBluetooth: Bool {
    transportType == kAudioDeviceTransportTypeBluetooth
      || transportType == kAudioDeviceTransportTypeBluetoothLE
  }

  var isBTInputUID: Bool {
    // Classic Bluetooth headset inputs look like "AA-BB-CC-DD-EE-FF:input"
    let pattern = #"^[0-9A-Fa-f]{2}(-[0-9A-Fa-f]{2}){5}:input$"#
    return uid.range(of: pattern, options: .regularExpression) != nil
  }
}

func cfStringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
  var addr = AudioObjectPropertyAddress(
    mSelector: selector,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  var size = UInt32(MemoryLayout<CFString?>.size)
  var value: CFString?
  let status = withUnsafeMutablePointer(to: &value) { ptr in
    AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
  }
  guard status == noErr, let value else { return nil }
  return value as String
}

func u32Property(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
  var addr = AudioObjectPropertyAddress(
    mSelector: selector,
    mScope: scope,
    mElement: kAudioObjectPropertyElementMain
  )
  var size = UInt32(MemoryLayout<UInt32>.size)
  var value: UInt32 = 0
  let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value)
  return status == noErr ? value : nil
}

func hasChannels(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyStreamConfiguration,
    mScope: scope,
    mElement: kAudioObjectPropertyElementMain
  )
  var size: UInt32 = 0
  guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else {
    return false
  }
  let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
  defer { raw.deallocate() }
  guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return false }
  let abl = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
  let buffers = UnsafeMutableAudioBufferListPointer(abl)
  return buffers.contains { $0.mNumberChannels > 0 }
}

func getAllDevices() -> [AudioDeviceInfo] {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  var size: UInt32 = 0
  AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
  let count = Int(size) / MemoryLayout<AudioDeviceID>.size
  var ids = [AudioDeviceID](repeating: 0, count: count)
  AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)

  return ids.compactMap { id -> AudioDeviceInfo? in
    guard let name = cfStringProperty(id, kAudioDevicePropertyDeviceNameCFString),
          let uid = cfStringProperty(id, kAudioDevicePropertyDeviceUID)
    else { return nil }
    let transport = u32Property(id, kAudioDevicePropertyTransportType) ?? 0
    return AudioDeviceInfo(
      id: id,
      uid: uid,
      name: name,
      transportType: transport,
      hasInput: hasChannels(id, scope: kAudioObjectPropertyScopeInput),
      hasOutput: hasChannels(id, scope: kAudioObjectPropertyScopeOutput)
    )
  }
}

func isRunningSomewhere(_ id: AudioDeviceID) -> Bool {
  (u32Property(id, kAudioDevicePropertyDeviceIsRunningSomewhere) ?? 0) != 0
}

func setDefaultInput(_ id: AudioDeviceID) -> Bool {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  var deviceID = id
  return AudioObjectSetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &addr, 0, nil,
    UInt32(MemoryLayout<AudioDeviceID>.size),
    &deviceID
  ) == noErr
}

func inputStreams(for deviceID: AudioDeviceID) -> [AudioStreamID] {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyStreams,
    mScope: kAudioObjectPropertyScopeInput,
    mElement: kAudioObjectPropertyElementMain
  )
  var size: UInt32 = 0
  guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr, size > 0 else {
    return []
  }
  let count = Int(size) / MemoryLayout<AudioStreamID>.size
  var streams = [AudioStreamID](repeating: 0, count: count)
  guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &streams) == noErr else {
    return []
  }
  return streams
}

func setStreamActive(_ streamID: AudioStreamID, active: Bool) -> Bool {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioStreamPropertyIsActive,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  var value: UInt32 = active ? 1 : 0
  return AudioObjectSetPropertyData(
    streamID, &addr, 0, nil,
    UInt32(MemoryLayout<UInt32>.size),
    &value
  ) == noErr
}

func muteInput(_ deviceID: AudioDeviceID) {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyMute,
    mScope: kAudioObjectPropertyScopeInput,
    mElement: kAudioObjectPropertyElementMain
  )
  var muted: UInt32 = 1
  _ = AudioObjectSetPropertyData(
    deviceID, &addr, 0, nil,
    UInt32(MemoryLayout<UInt32>.size),
    &muted
  )
}

func disableAsDefaultInput(_ deviceID: AudioDeviceID) {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
    mScope: kAudioObjectPropertyScopeInput,
    mElement: kAudioObjectPropertyElementMain
  )
  var settable: DarwinBoolean = false
  guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else {
    return
  }
  var zero: UInt32 = 0
  _ = AudioObjectSetPropertyData(
    deviceID, &addr, 0, nil,
    UInt32(MemoryLayout<UInt32>.size),
    &zero
  )
}

func findExistingAggregate() -> AudioDeviceID? {
  getAllDevices().first { $0.uid == aggregateUID }?.id
}

func removeAggregate() {
  guard let id = findExistingAggregate() else { return }
  _ = AudioHardwareDestroyAggregateDevice(id)
  usleep(300_000)
}

func ensureHQCallMicAggregate(builtInUID: String) -> AudioDeviceID? {
  if let existing = findExistingAggregate() {
    return existing
  }

  let subDevices: [[String: Any]] = [
    [kAudioSubDeviceUIDKey as String: builtInUID]
  ]
  let desc: [String: Any] = [
    kAudioAggregateDeviceUIDKey as String: aggregateUID,
    kAudioAggregateDeviceNameKey as String: aggregateName,
    kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
    kAudioAggregateDeviceMasterSubDeviceKey as String: builtInUID,
    kAudioAggregateDeviceIsPrivateKey as String: false,
    kAudioAggregateDeviceIsStackedKey as String: false
  ]

  var deviceID: AudioDeviceID = 0
  let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &deviceID)
  if status == noErr {
    return deviceID
  }
  fputs("ERROR: failed to create aggregate \(aggregateName) (status \(status))\n", stderr)
  return nil
}

func hideBluetoothInputs() -> Int {
  let devices = getAllDevices()
  let btInputs = devices.filter {
    $0.hasInput && ($0.isBluetooth || $0.isBTInputUID)
      && $0.uid != aggregateUID
      && $0.transportType != kAudioDeviceTransportTypeAggregate
  }

  var hidden = 0
  for d in btInputs {
    let running = isRunningSomewhere(d.id)
    print("BT input: \(d.name) uid=\(d.uid) running=\(running)")

    var streamOK = false
    for stream in inputStreams(for: d.id) {
      if setStreamActive(stream, active: false) {
        streamOK = true
      }
    }
    muteInput(d.id)
    disableAsDefaultInput(d.id)
    if streamOK || running {
      hidden += 1
      print("  → input streams deactivated / muted")
    } else {
      print("  → muted (stream deactivate unsupported on this device)")
      hidden += 1
    }
  }

  if btInputs.isEmpty {
    print("No Bluetooth input devices found.")
  }
  return hidden
}

func builtInMic() -> AudioDeviceInfo? {
  let devices = getAllDevices().filter {
    $0.hasInput
      && $0.transportType == kAudioDeviceTransportTypeBuiltIn
      && !$0.hasOutput
  }
  if let exact = devices.first(where: { $0.uid == "BuiltInMicrophoneDevice" }) {
    return exact
  }
  return devices.first
}

// MARK: - Main

let args = CommandLine.arguments

if args.contains("--list") {
  for d in getAllDevices().filter(\.hasInput) {
    let tag = d.isBluetooth || d.isBTInputUID ? " [BT]" : ""
    let run = isRunningSomewhere(d.id) ? " running" : ""
    print("\(d.name)\tuid=\(d.uid)\(tag)\(run)")
  }
  exit(0)
}

if args.contains("--status") {
  let bt = getAllDevices().filter { $0.hasInput && ($0.isBluetooth || $0.isBTInputUID) }
  if bt.isEmpty {
    print("No Bluetooth inputs present.")
  } else {
    for d in bt {
      print("\(d.name)\trunning=\(isRunningSomewhere(d.id))\tuid=\(d.uid)")
    }
  }
  if let agg = getAllDevices().first(where: { $0.uid == aggregateUID }) {
    print("Aggregate: \(agg.name) present")
  } else {
    print("Aggregate: \(aggregateName) missing")
  }
  exit(0)
}

guard let mic = builtInMic() else {
  fputs("ERROR: Built-in microphone not found.\n", stderr)
  exit(1)
}

print("Built-in mic: \(mic.name) (\(mic.uid))")
_ = hideBluetoothInputs()

guard let aggID = ensureHQCallMicAggregate(builtInUID: mic.uid) else {
  // Fall back to built-in mic as default input.
  if setDefaultInput(mic.id) {
    print("Set default input → \(mic.name)")
    exit(0)
  }
  exit(1)
}

if setDefaultInput(aggID) {
  print("Set default input → \(aggregateName)")
} else if setDefaultInput(mic.id) {
  print("WARNING: aggregate default failed; set \(mic.name) instead")
} else {
  fputs("ERROR: could not set default input\n", stderr)
  exit(1)
}

print("Done. Bluetooth mic hidden for this connection; reconnect restores it.")
