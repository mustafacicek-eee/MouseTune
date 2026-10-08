// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import Foundation

/// The language MouseTune shows its interface in. Stored as the app's own `AppleLanguages` override, which macOS reads
/// at launch, so a change takes effect after the app (and its menu bar service) is reopened.
enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case turkish
    case english

    private static let appleLanguagesKey = "AppleLanguages"

    var id: String { rawValue }

    /// Language names are shown in their own language so they stay recognizable whatever the current language is.
    var title: String {
        switch self {
        case .system: return "System"
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    /// Reads only this app's own setting, not the system-wide language list.
    /// The setting the running process started with; the interface language cannot change until a relaunch.
    static let atLaunch: AppLanguagePreference = current

    static var current: AppLanguagePreference {
        guard let bundleID = Bundle.main.bundleIdentifier, let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[appleLanguagesKey] as? [String], let first = languages.first else { return .system }
        if first.hasPrefix("tr") { return .turkish }
        if first.hasPrefix("en") { return .english }
        return .system
    }

    func apply(defaults: UserDefaults = .standard) {
        switch self {
        case .system: defaults.removeObject(forKey: Self.appleLanguagesKey)
        case .turkish: defaults.set(["tr"], forKey: Self.appleLanguagesKey)
        case .english: defaults.set(["en"], forKey: Self.appleLanguagesKey)
        }
    }
}
