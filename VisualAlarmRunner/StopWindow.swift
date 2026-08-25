/**
 * File: StopWindow.swift
 * Created: 2026-08-24
 */

import AppKit
import Foundation

/// Center-screen always-on-top window with a single Stop button.
@MainActor
final class StopWindow: NSObject, NSWindowDelegate {
    let window: NSWindow

    init(alarmLabel: String) {
        let size = NSSize(width: 320, height: 140)
        var contentRect = NSRect(origin: .zero, size: size)
        if let screen = NSScreen.main {
            contentRect.origin = NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            )
        }
        // A plain NSWindow, NOT an NSPanel: panels default to
        // hidesOnDeactivate = true and never become key while an accessory
        // app is inactive, which left the stop UI invisible.
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = false
        window.delegate = self

        let label = NSTextField(labelWithString: "⏰ \(alarmLabel)")
        label.font = .boldSystemFont(ofSize: 20)
        label.alignment = .center

        let button = NSButton(
            title: "Stop",
            target: self,
            action: #selector(stopClicked)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.controlSize = .large
        button.font = .boldSystemFont(ofSize: 16)

        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor),
        ])
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // Belt and braces for an accessory app that may not be active.
        window.orderFrontRegardless()
    }

    @objc private func stopClicked() {
        NSApp.terminate(nil)
    }
}
