/**
 * File: VASwiftUICompatTests.swift
 * Created: 2026-10-05
 *
 * Covers the floor-compatibility shims from VASwiftUI.swift — the
 * macOS 10.15 `@StateObject` replacement most notably runs on every
 * macOS version, so its behavior is verified here.
 */

import Combine
import SwiftUI
import Testing

@testable import VisualAlarm

@MainActor
struct VASwiftUICompatTests {

    private final class Counter: ObservableObject {
        @Published var count = 0
    }

    @Test func stateObjectShimReturnsSameInstanceAcrossReads() {
        let wrapper = VAStateObject(wrappedValue: Counter())
        #expect(wrapper.wrappedValue === wrapper.wrappedValue)
    }

    @Test func stateObjectShimProjectionWritesThroughToTheObject() {
        let wrapper = VAStateObject(wrappedValue: Counter())
        wrapper.projectedValue.count.wrappedValue = 5
        #expect(wrapper.wrappedValue.count == 5)
    }
}
