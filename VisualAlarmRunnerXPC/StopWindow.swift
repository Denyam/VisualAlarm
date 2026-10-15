/**
 * File: StopWindow.swift
 * Created: 2026-10-14
 *
 * Center-screen always-on-top window with a single Stop button.
 * Adapted for XPC service — calls back instead of terminating.
 */

import AppKit
import Foundation

@MainActor
final class StopWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private var onStop: (() -> Void)?

    init(alarmLabel: String, onStop: @escaping () -> Void) {
        self.onStop = onStop
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
        if #available(macOS 11.0, *) {
            button.controlSize = .large
            button.font = .boldSystemFont(ofSize: 16)
        } else {
            // `.large` control size needs macOS 11; grow the font instead.
            button.font = .boldSystemFont(ofSize: 20)
        }

        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        guard let contentView = window.contentView else { return }
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // Belt and braces for an accessory app that may not be active.
        window.orderFrontRegardless()
    }

    func updateLabel(_ label: String) {
        if let stack = window.contentView?.subviews.first as? NSStackView,
           let textField = stack.views.first as? NSTextField {
            textField.stringValue = "⏰ \(label)"
        }
    }

    func close() {
        window.close()
    }

    @objc private func stopClicked() {
        onStop?()
    }
}