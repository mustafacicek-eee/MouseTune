// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import SwiftUI

/// Shows the estimated days of battery left under the battery percentage.
struct BatteryForecastLabel: View {
    let deviceID: String
    let currentPercent: Int
    var fontSize: CGFloat = 11

    var body: some View {
        TimelineView(.periodic(from: .now, by: 300)) { context in
            let forecast = BatteryHistory.forecast(samples: BatteryHistoryCache.shared.samples(for: deviceID), currentPercent: currentPercent, now: context.date)
            Text(forecast.shortText).font(.system(size: fontSize, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).help(forecast.detailText).accessibilityIdentifier("battery-forecast")
        }
    }
}
