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

    private lazy var observerPointer: UnsafeMutableRawPointer = {
        Unmanaged.passUnretained(self).toOpaque()
    }()

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

    var rawObserverPointer: UnsafeMutableRawPointer {
        observerPointer
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