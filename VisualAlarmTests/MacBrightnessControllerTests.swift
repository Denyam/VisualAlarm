/**
 * File: MacBrightnessControllerTests.swift
 * Created: 2026-08-22
 */

#if os(macOS)
import Testing

@testable import VisualAlarm

struct MacBrightnessControllerTests {

    @Test func resolvesRealIOKitBrightnessSymbols() {
        #expect(MacBrightnessController.loadSymbol("IODisplayGetFloatParameter") != nil)
        #expect(MacBrightnessController.loadSymbol("IODisplaySetFloatParameter") != nil)
    }

    @Test func unknownSymbolsResolveToNil() {
        #expect(MacBrightnessController.loadSymbol("DefinitelyNotARealSymbol_va") == nil)
    }
}
#endif
