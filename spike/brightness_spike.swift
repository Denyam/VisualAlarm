/**
 * File: brightness_spike.swift
 * Created: 2026-08-22
 */

import Foundation
import IOKit

// Spike: verify IODisplaySetFloatParameter(kIODisplayBrightnessKey) works
// while the process runs inside the App Sandbox.
//
// Build & run:
//   swiftc -O spike/brightness_spike.swift -import-objc-header spike/spike.h \
//       -o /tmp/va_brightness_spike
//   /tmp/va_brightness_spike                       # unsandboxed baseline
//   codesign --force --sign - --entitlements spike/sandbox.entitlements \
//       /tmp/va_brightness_spike
//   /tmp/va_brightness_spike                       # sandboxed — THE test
//
// Exit status: 0 = SPIKE PASS (all sets succeeded), 1 = FAIL.
// The screen visibly dips to black, jumps to max, then restores.

private let brightnessKey = "brightness" as CFString // == kIODisplayBrightnessKey

/// Behavioral sandbox probe: App Sandbox forbids arbitrary writes into $HOME,
/// an unsandboxed process succeeds.
func sandboxIsActive() -> Bool {
    let probe = URL(fileURLWithPath: NSString("~/.va_spike_probe").expandingTildeInPath)
    do {
        try Data("probe".utf8).write(to: probe)
        try? FileManager.default.removeItem(at: probe)
        return false
    } catch {
        return true
    }
}

func displayServices() -> [io_service_t] {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("IODisplayConnect"),
        &iterator
    ) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iterator) }

    var services: [io_service_t] = []
    while case let service = IOIteratorNext(iterator), service != 0 {
        services.append(service)
    }
    return services
}

let sandboxed = sandboxIsActive()
print("Sandbox probe: \(sandboxed ? "ACTIVE" : "INACTIVE")")

let services = displayServices()
print("IODisplayConnect services found: \(services.count)")
guard !services.isEmpty else {
    print("SPIKE FAIL: no displays enumerated")
    exit(1)
}

var failed = false
var originals: [(service: io_service_t, value: Float32)] = []

for service in services {
    var value: Float32 = -1
    let rc = IODisplayGetFloatParameter(service, 0, brightnessKey, &value)
    print("service #\(service): GET rc=\(rc) brightness=\(value)")
    if rc == KERN_SUCCESS {
        originals.append((service, value))
    } else {
        failed = true
    }
}

usleep(500_000)
for (service, _) in originals {
    let minRC = IODisplaySetFloatParameter(service, 0, brightnessKey, 0.0)
    usleep(700_000)
    var lowValue: Float32 = -1
    _ = IODisplayGetFloatParameter(service, 0, brightnessKey, &lowValue)

    let maxRC = IODisplaySetFloatParameter(service, 0, brightnessKey, 1.0)
    usleep(700_000)
    var highValue: Float32 = -1
    _ = IODisplayGetFloatParameter(service, 0, brightnessKey, &highValue)

    print(
        "service #\(service): SET(min) rc=\(minRC) observed=\(lowValue) | "
            + "SET(max) rc=\(maxRC) observed=\(highValue)"
    )
    if minRC != KERN_SUCCESS || maxRC != KERN_SUCCESS { failed = true }
}

for (service, original) in originals {
    let rc = IODisplaySetFloatParameter(service, 0, brightnessKey, original)
    print("service #\(service): RESTORE rc=\(rc) to=\(original)")
    if rc != KERN_SUCCESS { failed = true }
}

services.forEach { IOObjectRelease($0) }

if failed {
    print("SPIKE FAIL")
    exit(1)
}
print("SPIKE PASS")
exit(0)
