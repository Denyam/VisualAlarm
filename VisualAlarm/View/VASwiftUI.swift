/**
 * File: VASwiftUI.swift
 * Created: 2026-10-05
 *
 * Compatibility shims so views compile and run at the deployment floors
 * (macOS 10.15 / iOS 15.5). Every `va…` helper uses the native API when the
 * runtime has it and a floor-safe fallback otherwise; iOS always takes the
 * native branch (its floor already covers the API).
 */

import Combine
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - navigationTitle (macOS 11+ / iOS 14+)

extension View {
    /// Native `navigationTitle`; on the macOS 10.15 path the title renders as
    /// an inline header strip pushed above the content (10.15 macOS has no
    /// `navigationBarTitle` — it is iOS-only).
    @ViewBuilder
    func vaNavigationTitle(_ title: String) -> some View {
        #if os(macOS)
        if #available(macOS 11.0, *) {
            navigationTitle(title)
        } else {
            VStack(spacing: 0) {
                Text(title)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.vaBar)
                self
            }
        }
        #else
        navigationTitle(title)
        #endif
    }
}

// MARK: - toolbar (macOS 11+ / iOS 14+)

/// Floor-safe stand-in for `ToolbarItemPlacement` (macOS 11+ / iOS 14+).
enum VAToolbarPlacement {
    case automatic
    case primaryAction
    case cancellationAction
    case confirmationAction
}

extension View {
    /// Native `.toolbar` item; on the macOS 10.15 path the same content is
    /// overlaid at the matching corner so actions stay reachable.
    @ViewBuilder
    func vaToolbarItem<Content: View>(
        placement: VAToolbarPlacement,
        fallbackAlignment: Alignment = .topTrailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        #if os(macOS)
        if #available(macOS 11.0, *) {
            vaNativeToolbarItem(placement: placement, content: content)
        } else {
            overlay(content().padding(8), alignment: fallbackAlignment)
        }
        #else
        vaNativeToolbarItem(placement: placement, content: content)
        #endif
    }
}

@available(macOS 11.0, *)
private extension View {
    func vaNativeToolbarItem<Content: View>(
        placement: VAToolbarPlacement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        toolbar {
            ToolbarItem(placement: placement.native) {
                content()
            }
        }
    }
}

private extension VAToolbarPlacement {
    @available(macOS 11.0, *)
    var native: ToolbarItemPlacement {
        switch self {
        case .automatic: return .automatic
        case .primaryAction: return .primaryAction
        case .cancellationAction: return .cancellationAction
        case .confirmationAction: return .confirmationAction
        }
    }
}

// MARK: - safeAreaInset (macOS 12+ / iOS 15+)

extension View {
    /// Native `safeAreaInset`; on the macOS 10.15–11 path the content is
    /// stacked inline above the view (top edge) instead. macOS spells the
    /// edge parameter `VerticalEdge`, iOS `Edge`.
    @ViewBuilder
    func vaSafeAreaInset<Content: View>(
        edge: Edge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            switch edge {
            case .top:
                safeAreaInset(
                    edge: .top,
                    alignment: alignment,
                    spacing: spacing,
                    content: content
                )
            case .bottom:
                safeAreaInset(
                    edge: .bottom,
                    alignment: alignment,
                    spacing: spacing,
                    content: content
                )
            default:
                // macOS only insets against horizontal edges' neighbors.
                VStack(spacing: 0) {
                    self
                    content()
                }
            }
        } else if edge == .top {
            VStack(spacing: 0) {
                content()
                self
            }
        } else {
            VStack(spacing: 0) {
                self
                content()
            }
        }
        #else
        switch edge {
        case .top:
            safeAreaInset(
                edge: .top,
                alignment: alignment,
                spacing: spacing,
                content: content
            )
        case .bottom:
            safeAreaInset(
                edge: .bottom,
                alignment: alignment,
                spacing: spacing,
                content: content
            )
        default:
            VStack(spacing: 0) {
                self
                content()
            }
        }
        #endif
    }
}

// MARK: - button style / tint (macOS 12+ / iOS 15+)

extension View {
    /// Native `.bordered` style; the macOS 10.15–11 fallback keeps the
    /// platform's default button look.
    @ViewBuilder
    func vaBorderedButtonStyle() -> some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            buttonStyle(.bordered)
        } else {
            self
        }
        #else
        buttonStyle(.bordered)
        #endif
    }

    /// Native `.tint(_:)`; the macOS 10.15–11 fallback colors the label via
    /// `foregroundColor`, which suits small text buttons like weekday chips.
    @ViewBuilder
    func vaTint(_ color: Color?) -> some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            tint(color)
        } else {
            foregroundColor(color)
        }
        #else
        tint(color)
        #endif
    }
}

// MARK: - images (SF Symbols in SwiftUI are macOS 11+ / iOS 13+)

/// `Image(systemName:)` with a text fallback for the macOS 10.15 path,
/// where SwiftUI has no SF Symbol support.
struct VASymbolImage: View {
    let systemName: String
    var fallback: String

    var body: some View {
        #if os(macOS)
        if #available(macOS 11.0, *) {
            Image(systemName: systemName)
        } else {
            Text(fallback)
        }
        #else
        Image(systemName: systemName)
        #endif
    }
}

// MARK: - background bar color (`.bar` ShapeStyle is macOS 12+ / iOS 15+)

extension Color {
    /// Platform stand-in for the `.bar` ShapeStyle.
    static let vaBar: Color = {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }()
}

// MARK: - StateObject (macOS 11+ / iOS 14+)

/// `@StateObject` replacement that also runs on macOS 10.15: keeps one
/// object alive across view-struct re-initializations (`@State` ownership)
/// and re-renders the view when the object publishes changes (nested
/// `@ObservedObject` relay).
@propertyWrapper
struct VAStateObject<ObjectType: ObservableObject>: DynamicProperty {
    /// Owns the object once; later inits of the wrapper discard their value,
    /// mirroring `@StateObject`'s autoclosure semantics.
    private final class Owner: ObservableObject {
        let value: ObjectType
        private var changeRelay: AnyCancellable?

        init(_ value: ObjectType) {
            self.value = value
            changeRelay = value.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }

    @State private var owner: Owner
    @ObservedObject private var observation: Owner

    @MainActor
    init(wrappedValue: @autoclosure () -> ObjectType) {
        let owner = Owner(wrappedValue())
        _owner = State(initialValue: owner)
        _observation = ObservedObject(wrappedValue: owner)
    }

    var wrappedValue: ObjectType { owner.value }

    var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject(wrappedValue: owner.value).projectedValue
    }
}

// MARK: - ContentUnavailableView (macOS 14+ / iOS 17+)

/// Floor-safe stand-in for `ContentUnavailableView`.
struct VAContentUnavailableView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            VASymbolImage(systemName: systemImage, fallback: "⏰")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
