// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import Foundation
import OpenSnekCore

/// One stored battery reading. `reset` marks the first reading after a battery swap.
struct BatteryHistorySample: Codable, Equatable, Sendable {
    let t: Double
    let pct: Int
    var reset: Bool?
}

/// On-disk battery history, keyed by device id.
struct BatteryHistoryFile: Codable, Equatable, Sendable {
    var version = 1
    var devices: [String: [BatteryHistorySample]] = [:]
}

/// Result of the remaining-days estimate.
enum BatteryForecast: Equatable, Sendable {
    case noData
    case collecting(spanDays: Double)
    case waitingForDrop(spanDays: Double)
    case estimate(daysLeft: Double, dropPerDay: Double, spanDays: Double, sampleCount: Int)

    var shortText: String {
        switch self {
        case .noData: return L("Recording battery history")
        case .collecting(let span): return L("Collecting data for forecast · %@/%@ days", Self.oneDecimal(span), Self.oneDecimal(BatteryHistory.minimumSpanDays))
        case .waitingForDrop: return L("Waiting for a battery drop to forecast")
        case .estimate(let daysLeft, _, _, _):
            if daysLeft < 1 { return L("≈ less than 1 day left") }
            if daysLeft > 365 { return L("≈ more than 1 year left") }
            return L("≈ %@ days left", "\(Int(daysLeft.rounded()))")
        }
    }

    var detailText: String {
        switch self {
        case .noData: return L("Battery level is recorded hourly while the app is running.")
        case .collecting(let span): return L("A reliable forecast needs at least %@ days of data. Currently %@ days.", "\(Int(BatteryHistory.minimumSpanDays))", Self.oneDecimal(span))
        case .waitingForDrop(let span): return L("%@ days of data so far, but the battery has not dropped by at least %@% yet.", Self.oneDecimal(span), "\(BatteryHistory.minimumDrop)")
        case .estimate(_, let dropPerDay, let span, let count): return L("%@ readings over the last %@ days; about %@% drop per day. Time until 0% at the same usage; approximate, because the AA battery discharge curve is not linear.", "\(count)", Self.oneDecimal(span), Self.oneDecimal(dropPerDay))
        }
    }

    private static func oneDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

/// Battery history storage and forecasting.
enum BatteryHistory {
    static let minimumSpanDays = 3.0
    static let minimumDrop = 3
    static let windowDays = 30.0
    static let resampleInterval: TimeInterval = 3600
    static let significantChange = 2
    static let replacementJump = 15
    static let retentionDays = 180.0
    static let maxSamplesPerDevice = 5000

    private static var applicationSupportBase: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true) }

    static var fileURL: URL { applicationSupportBase.appendingPathComponent("MouseTune", isDirectory: true).appendingPathComponent("battery-history.json") }

    /// Location used by earlier local builds; read once so existing history is kept after the rename. The old file is left in place.
    static var legacyFileURL: URL { applicationSupportBase.appendingPathComponent("Razer", isDirectory: true).appendingPathComponent("battery-history.json") }

    static func load(from url: URL = fileURL) -> BatteryHistoryFile {
        var source = url
        if url == fileURL, !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: legacyFileURL.path) { source = legacyFileURL }
        guard let data = try? Data(contentsOf: source), let file = try? JSONDecoder().decode(BatteryHistoryFile.self, from: data) else { return BatteryHistoryFile() }
        return file
    }

    static func save(_ file: BatteryHistoryFile, to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: .atomic)
    }

    /// Returns the updated samples, or nil when this reading does not need to be stored.
    static func appending(percent: Int, at date: Date, to samples: [BatteryHistorySample]) -> [BatteryHistorySample]? {
        let pct = max(0, min(100, percent))
        let now = date.timeIntervalSince1970
        var updated = samples
        if let last = samples.last {
            let isReplacement = pct >= last.pct + replacementJump
            let isSignificant = abs(pct - last.pct) >= significantChange
            let isDue = now - last.t >= resampleInterval
            guard isReplacement || isSignificant || isDue else { return nil }
            updated.append(BatteryHistorySample(t: now, pct: pct, reset: isReplacement ? true : nil))
        } else {
            updated.append(BatteryHistorySample(t: now, pct: pct, reset: nil))
        }
        let cutoff = now - retentionDays * 86400
        updated.removeAll { $0.t < cutoff }
        if updated.count > maxSamplesPerDevice { updated.removeFirst(updated.count - maxSamplesPerDevice) }
        return updated
    }

    /// Least-squares estimate of days until 0% using the current battery (since the last swap) and the last `windowDays`.
    static func forecast(samples: [BatteryHistorySample], currentPercent: Int?, now: Date) -> BatteryForecast {
        guard !samples.isEmpty else { return .noData }
        let segmentStart = samples.lastIndex { $0.reset == true } ?? 0
        let windowStart = now.timeIntervalSince1970 - windowDays * 86400
        let points = samples[segmentStart...].filter { $0.t >= windowStart }
        guard let first = points.first, let last = points.last, points.count >= 2 else { return .collecting(spanDays: 0) }

        let spanDays = (last.t - first.t) / 86400
        guard spanDays >= minimumSpanDays else { return .collecting(spanDays: spanDays) }

        let xs = points.map { ($0.t - first.t) / 86400 }
        let ys = points.map { Double($0.pct) }
        let count = Double(points.count)
        let meanX = xs.reduce(0, +) / count
        let meanY = ys.reduce(0, +) / count
        var sxx = 0.0
        var sxy = 0.0
        for (x, y) in zip(xs, ys) {
            sxx += (x - meanX) * (x - meanX)
            sxy += (x - meanX) * (y - meanY)
        }
        guard sxx > 0 else { return .collecting(spanDays: spanDays) }
        let slope = sxy / sxx
        let observedDrop = (ys.max() ?? 0) - (ys.min() ?? 0)
        guard slope < 0, observedDrop >= Double(minimumDrop) else { return .waitingForDrop(spanDays: spanDays) }

        let current = Double(max(0, min(100, currentPercent ?? last.pct)))
        return .estimate(daysLeft: current / -slope, dropPerDay: -slope, spanDays: spanDays, sampleCount: points.count)
    }
}

/// Serializes history writes within the process that talks to the device.
actor BatteryHistoryRecorder {
    static let shared = BatteryHistoryRecorder()

    private var lastStoredByDeviceID: [String: BatteryHistorySample] = [:]

    func record(deviceID: String, percent: Int?, charging: Bool?, at date: Date = Date()) {
        guard let percent, charging != true, !deviceID.isEmpty else { return }
        if let last = lastStoredByDeviceID[deviceID], BatteryHistory.appending(percent: percent, at: date, to: [last]) == nil { return }
        var file = BatteryHistory.load()
        defer { lastStoredByDeviceID[deviceID] = file.devices[deviceID]?.last }
        guard let updated = BatteryHistory.appending(percent: percent, at: date, to: file.devices[deviceID] ?? []) else { return }
        file.devices[deviceID] = updated
        try? BatteryHistory.save(file)
    }
}

/// Small cache so views do not re-read the history file on every render.
final class BatteryHistoryCache: @unchecked Sendable {
    static let shared = BatteryHistoryCache()

    private let lock = NSLock()
    private var cachedFile = BatteryHistoryFile()
    private var cachedModified: Date?

    func samples(for deviceID: String) -> [BatteryHistorySample] {
        lock.lock()
        defer { lock.unlock() }
        let url = BatteryHistory.fileURL
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        if modified != cachedModified {
            cachedFile = BatteryHistory.load(from: url)
            cachedModified = modified
        }
        return cachedFile.devices[deviceID] ?? []
    }
}
