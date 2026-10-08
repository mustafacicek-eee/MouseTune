// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import XCTest
@testable import OpenSnek

/// Exercises battery history sampling and remaining-days forecasting.
final class BatteryHistoryTests: XCTestCase {
    private let day: TimeInterval = 86400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstReadingIsStored() {
        let updated = BatteryHistory.appending(percent: 80, at: start, to: [])
        XCTAssertEqual(updated?.count, 1)
        XCTAssertEqual(updated?.first?.pct, 80)
    }

    func testSmallChangeWithinAnHourIsSkipped() {
        let samples = [BatteryHistorySample(t: start.timeIntervalSince1970, pct: 80)]
        XCTAssertNil(BatteryHistory.appending(percent: 79, at: start.addingTimeInterval(600), to: samples))
    }

    func testReadingAfterAnHourIsStored() {
        let samples = [BatteryHistorySample(t: start.timeIntervalSince1970, pct: 80)]
        XCTAssertEqual(BatteryHistory.appending(percent: 80, at: start.addingTimeInterval(3601), to: samples)?.count, 2)
    }

    func testBatterySwapStartsNewSegment() {
        let samples = [BatteryHistorySample(t: start.timeIntervalSince1970, pct: 20)]
        let updated = BatteryHistory.appending(percent: 98, at: start.addingTimeInterval(60), to: samples)
        XCTAssertEqual(updated?.last?.reset, true)
    }

    func testNoDataAndCollecting() {
        XCTAssertEqual(BatteryHistory.forecast(samples: [], currentPercent: 50, now: start), .noData)
        let samples = [
            BatteryHistorySample(t: start.timeIntervalSince1970, pct: 50),
            BatteryHistorySample(t: start.addingTimeInterval(day).timeIntervalSince1970, pct: 48)
        ]
        guard case .collecting(let span) = BatteryHistory.forecast(samples: samples, currentPercent: 48, now: start.addingTimeInterval(day)) else {
            return XCTFail("expected collecting")
        }
        XCTAssertEqual(span, 1, accuracy: 0.001)
    }

    func testLinearDrainEstimatesDaysLeft() {
        // 2% per day for 10 days: 60 -> 40, so 40% left means ~20 days.
        let samples = (0...10).map { BatteryHistorySample(t: start.addingTimeInterval(Double($0) * day).timeIntervalSince1970, pct: 60 - 2 * $0) }
        let now = start.addingTimeInterval(10 * day)
        guard case .estimate(let daysLeft, let dropPerDay, _, let count) = BatteryHistory.forecast(samples: samples, currentPercent: 40, now: now) else {
            return XCTFail("expected estimate")
        }
        XCTAssertEqual(dropPerDay, 2, accuracy: 0.001)
        XCTAssertEqual(daysLeft, 20, accuracy: 0.001)
        XCTAssertEqual(count, 11)
    }

    func testFlatBatteryWaitsForDrop() {
        let samples = (0...5).map { BatteryHistorySample(t: start.addingTimeInterval(Double($0) * day).timeIntervalSince1970, pct: 70) }
        XCTAssertEqual(BatteryHistory.forecast(samples: samples, currentPercent: 70, now: start.addingTimeInterval(5 * day)), .waitingForDrop(spanDays: 5))
    }

    func testForecastIgnoresReadingsBeforeBatterySwap() {
        var samples = (0...5).map { BatteryHistorySample(t: start.addingTimeInterval(Double($0) * day).timeIntervalSince1970, pct: 30 - 5 * $0) }
        samples.append(BatteryHistorySample(t: start.addingTimeInterval(6 * day).timeIntervalSince1970, pct: 100, reset: true))
        samples.append(BatteryHistorySample(t: start.addingTimeInterval(7 * day).timeIntervalSince1970, pct: 99))
        XCTAssertEqual(BatteryHistory.forecast(samples: samples, currentPercent: 99, now: start.addingTimeInterval(7 * day)), .collecting(spanDays: 1))
    }

    func testShortTextFormatting() {
        XCTAssertEqual(BatteryForecast.estimate(daysLeft: 23.4, dropPerDay: 1.3, spanDays: 7, sampleCount: 40).shortText, "≈ 23 days left")
        XCTAssertEqual(BatteryForecast.estimate(daysLeft: 0.4, dropPerDay: 5, spanDays: 7, sampleCount: 40).shortText, "≈ less than 1 day left")
    }
}
