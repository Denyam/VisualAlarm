/**
 * File: MacBrightnessController.swift
 * Created: 2026-08-22
 */

#if os(macOS)
import Foundation
import IOKit

/// Controls built-in display brightness through public IOKit APIs.
/// `IODisplayGet/SetFloatParameter` are not exposed to Swift, so they are
/// resolved from the IOKit framework at runtime (see AGENTS.md gotchas).
final class MacBrightnessController: MacBrightnessControlling {
    private static let brightnessKey = "brightness" as CFString

    private typealias GetFloatFn = @convention(c) (
        io_service_t, UInt32, CFString, UnsafeMutablePointer<Float>
    ) -> Int32
    private typealias SetFloatFn = @convention(c) (
        io_service_t, UInt32, CFString, Float
    ) -> Int32

    private let getParam: GetFloatFn?
    private let setParam: SetFloatFn?
    private var services: [io_service_t] = []
    private var originals: [(service: io_service_t, value: Float)] = []

    init(
        symbolProvider: (String) -> UnsafeMutableRawPointer? =
            MacBrightnessController.loadSymbol
    ) {
        getParam = unsafeBitCast(
            symbolProvider("IODisplayGetFloatParameter"),
            to: GetFloatFn?.self
        )
        setParam = unsafeBitCast(
            symbolProvider("IODisplaySetFloatParameter"),
            to: SetFloatFn?.self
        )
    }

    static func loadSymbol(_ name: String) -> UnsafeMutableRawPointer? {
        guard
            let handle = dlopen(
                "/System/Library/Frameworks/IOKit.framework/IOKit",
                RTLD_NOW
            )
        else { return nil }
        return dlsym(handle, name)
    }

    func isSupported() -> Bool {
        getParam != nil && setParam != nil
    }

    /// Snapshots the current brightness of every connected display so that
    /// `restoreStoredLevels` can bring them back later.
    func storeCurrentLevels() {
        guard isSupported() else { return }
        releaseServices()

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        ) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            var value: Float = -1
            if getParam!(service, 0, Self.brightnessKey, &value) == KERN_SUCCESS {
                originals.append((service, value))
                services.append(service)
            } else {
                IOObjectRelease(service)
            }
        }
    }

    @discardableResult
    func setAllDisplays(to value: Float) -> Bool {
        guard isSupported(), !services.isEmpty else { return false }
        return services.allSatisfy { service in
            setParam!(service, 0, Self.brightnessKey, value) == KERN_SUCCESS
        }
    }

    func restoreStoredLevels() {
        for original in originals {
            _ = setParam?(original.service, 0, Self.brightnessKey, original.value)
        }
        releaseServices()
    }

    private func releaseServices() {
        services.forEach { IOObjectRelease($0) }
        services = []
        originals = []
    }
}
#endif
