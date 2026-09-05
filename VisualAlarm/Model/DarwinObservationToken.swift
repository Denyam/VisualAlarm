/**
 * File: DarwinObservationToken.swift
 * Created: 2026-08-24
 */

import Foundation

/// Removes its underlying observer when cancelled or deallocated.
final class DarwinObservationToken {
    let center: CFNotificationCenter
    let name: CFNotificationName
    let queue: DispatchQueue
    let block: () -> Void

    init(
        center: CFNotificationCenter,
        name: CFNotificationName,
        queue: DispatchQueue,
        block: @escaping () -> Void
    ) {
        self.center = center
        self.name = name
        self.queue = queue
        self.block = block
    }

    // Stored once during registration, reused for removal.
    // Created by theDarwinNotificationCenter when adding the observer.
    var rawObserverPointer: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
    }

    func cancel() {
        CFNotificationCenterRemoveObserver(
            center,
            rawObserverPointer,
            name,
            nil
        )
    }

    deinit {
        cancel()
    }

    func deliver() {
        queue.async(execute: block)
    }
}