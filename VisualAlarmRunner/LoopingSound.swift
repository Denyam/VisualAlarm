/**
 * File: LoopingSound.swift
 * Created: 2026-08-24
 */

import AppKit
import Foundation

/// Replays a system sound indefinitely until stopped.
final class LoopingSound: NSObject, NSSoundDelegate {
    private let sound: NSSound?
    private var shouldLoop = true

    /// Whether a system sound with the given name was found.
    var isAvailable: Bool { sound != nil }

    init(named name: String) {
        sound = NSSound(named: name)
        super.init()
        sound?.delegate = self
    }

    func play() {
        shouldLoop = true
        _ = sound?.play()
    }

    func stop() {
        shouldLoop = false
        sound?.stop()
    }

    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldLoop else { return }
            _ = sound.play()
        }
    }
}
