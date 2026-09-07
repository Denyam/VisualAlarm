/**
 * File: TestUtilities.swift
 * Created: 2026-09-07
 */

/**
 * File: TestUtilities.swift
 * Created: 2026-09-07
 */

#if os(iOS)
import Foundation

@testable import VisualAlarm

// MARK: - Fake Torch Controller

final class FakeTorchController: TorchControlling {
    private let lock = NSLock()
    private var _isOn = false
    private var _modeSupported = true

    var isOn: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isOn
    }

    var modeSupported: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _modeSupported
    }

    func setModeSupported(_ supported: Bool) {
        lock.lock()
        _modeSupported = supported
        lock.unlock()
    }

    func setTorch(on: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _modeSupported else { return false }
        _isOn = on
        return true
    }
}

// MARK: - Fake Brightness Controller

final class FakeBrightnessController: ScreenBrightnessControlling {
    private let lock = NSLock()
    private var _brightness: CGFloat = 0.5

    var brightness: CGFloat {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _brightness
        }
        set {
            lock.lock()
            _brightness = newValue
            lock.unlock()
        }
    }
}

// MARK: - Silent Haptics

final class SilentHaptics: HapticSignaling {
    func fire() {}
}
#endif