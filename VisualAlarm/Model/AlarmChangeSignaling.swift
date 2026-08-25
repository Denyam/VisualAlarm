/**
 * File: AlarmChangeSignaling.swift
 * Created: 2026-08-24
 */

/// Change-signal seam; lets tests silence cross-process notifications.
protocol AlarmChangeSignaling {
    func post(_ notification: DarwinNotification)
}

extension DarwinNotificationCenter: AlarmChangeSignaling {}
