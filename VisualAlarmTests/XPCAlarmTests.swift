/**
 * File: XPCAlarmTests.swift
 * Created: 2026-10-13
 */

#if os(macOS)
import Foundation
import Testing

@testable import VisualAlarm

struct XPCAlarmTests {

    @Test func roundTripsThroughEncodedPayload() throws {
        let original = Alarm(
            label: "Morning run",
            hour: 6,
            minute: 30,
            isEnabled: true,
            weekdays: [2, 4, 6]
        )

        let restored = try #require(
            try XPCAlarm.decode(XPCAlarm(original).encoded()).alarm
        )

        #expect(restored == original)
    }

    @Test func encodesWeekdaysInStableOrder() {
        let original = Alarm(
            label: "Weekly",
            hour: 8,
            minute: 0,
            weekdays: [6, 2, 4]
        )

        // The wire form sorts weekdays so equal alarms encode identically.
        #expect(XPCAlarm(original).weekdays == [2, 4, 6])
    }

    @Test func rejectsMalformedIdentifier() {
        let wire = XPCAlarm(
            id: "not-a-uuid",
            hour: 7,
            minute: 0,
            label: "Broken",
            isEnabled: true,
            weekdays: []
        )

        #expect(wire.alarm == nil)
    }
}
#endif