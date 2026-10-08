// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import SwiftUI

/// MouseTune's colors in one place: a neutral dark base with a single sky-blue accent that matches the app icon.
enum MouseTuneTheme {
    static let accent = Color(hex: 0x38BDF8)
    static let accentSoft = Color(hex: 0x38BDF8).opacity(0.14)

    static let windowTop = Color(hex: 0x0F1319)
    static let windowBottom = Color(hex: 0x0A0D11)
    static let sidebar = Color(hex: 0x0B0E12)
    static let divider = Color.white.opacity(0.07)

    static let cardFill = Color.white.opacity(0.035)
    static let cardStroke = Color.white.opacity(0.075)
    static let cardRadius: CGFloat = 16

    static let rowFill = Color.white.opacity(0.03)
    static let rowStroke = Color.white.opacity(0.06)

    static var windowBackground: some View { LinearGradient(colors: [windowTop, windowBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea() }
}

/// MouseTune view helpers.
extension View {
    /// MouseTune fork: on macOS 26+ scroll views tint the strip under the transparent title bar; the flat design does not want that band.
    @ViewBuilder func mouseTuneHidesTopScrollEdge() -> some View { if #available(macOS 26.0, *) { scrollEdgeEffectHidden(true, for: .top) } else { self } }

    /// MouseTune fork: keeps the title bar strip transparent now that no sidebar sits under it.
    @ViewBuilder func mouseTuneHidesTitlebarBackground() -> some View { if #available(macOS 15.0, *) { toolbarBackgroundVisibility(.hidden, for: .windowToolbar) } else { self } }
}
