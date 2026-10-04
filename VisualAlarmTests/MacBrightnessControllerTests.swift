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

    @Test func concurrentAccessDoesNotCrash() async {
        let controller = MacBrightnessController()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    controller.storeCurrentLevels()
                    _ = controller.setAllDisplays(to: 1.0)
                    _ = controller.setAllDisplays(to: 0.0)
                    controller.restoreStoredLevels()
                    _ = controller.displayCount
                }
            }
        }
    }
}
#endif
