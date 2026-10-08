// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import Foundation

/// Translates an English UI string for display.
///
/// Stored values, logs and comparisons keep using the English text; only what is shown on screen goes through this.
/// Lookup order: exact key in the app's `Localizable.strings`, then the runtime message patterns below, then the
/// English text unchanged.
public func L(_ english: String) -> String {
    let translated = Bundle.main.localizedString(forKey: english, value: english, table: nil)
    if translated != english { return translated }
    return LocalizedMessagePatterns.translate(english) ?? english
}

/// Formats a translated template. Placeholders are `%@` (taken in order) or `%1$@`, `%2$@` ... (taken by position),
/// so a translation can reorder them. Callers pass strings.
public func L(_ englishTemplate: String, _ arguments: String...) -> String {
    let template = L(englishTemplate)
    guard let regex = try? NSRegularExpression(pattern: #"%(\d+)\$@|%@"#) else { return template }
    var result = ""
    var cursor = template.startIndex
    var nextSequential = 0
    for match in regex.matches(in: template, range: NSRange(template.startIndex..., in: template)) {
        guard let whole = Range(match.range, in: template) else { continue }
        result += template[cursor..<whole.lowerBound]
        var index = nextSequential
        if let positional = Range(match.range(at: 1), in: template), let number = Int(template[positional]) { index = number - 1 } else { nextSequential += 1 }
        result += arguments.indices.contains(index) ? arguments[index] : ""
        cursor = whole.upperBound
    }
    return result + template[cursor...]
}

/// Translations for messages that are assembled at runtime (they contain values such as device names or counts).
enum LocalizedMessagePatterns {
    /// (regular expression matched against the whole English message, Turkish template with $1, $2 ... groups)
    private static let turkish: [(String, String)] = [
        (#"^Device read is failing repeatedly \((\d+)x\): (.*)$"#, "Cihaz okuması art arda başarısız oluyor ($1 kez): $2"), (#"^USB telemetry is incomplete \(missing (.*)\)\.?(.*)$"#, "USB telemetrisi eksik (eksik: $1).$2"),
        (#"^Permissions reset for (.*)\. Re-enable Input Monitoring, then relaunch MouseTune\.$"#, "$1 için izinler sıfırlandı. Giriş İzleme'yi yeniden açın ve MouseTune'u yeniden başlatın."), (#"^Permission reset failed: (.*)$"#, "İzin sıfırlama başarısız: $1"),
        (#"^Local storage reset failed: (.*)$"#, "Yerel depolama sıfırlanamadı: $1"), (#"^Background service unavailable: (.*)$"#, "Arka plan hizmeti kullanılamıyor: $1"), (#"^Service host failed: (.*)$"#, "Hizmet başlatılamadı: $1"),
        (#"^Launch at startup failed: (.*)$"#, "Açılışta başlatma ayarlanamadı: $1"), (#"^Failed to create profile from mouse: (.*)$"#, "Fareden profil oluşturulamadı: $1"), (#"^Failed to load profile from mouse: (.*)$"#, "Fareden profil yüklenemedi: $1"),
        (#"^Failed to replace profile: (.*)$"#, "Profil değiştirilemedi: $1"), (#"^Failed to refresh onboard profiles: (.*)$"#, "Cihazdaki profiller yenilenemedi: $1"), (#"^Failed to load onboard profile: (.*)$"#, "Cihazdaki profil yüklenemedi: $1"),
        (#"^Failed to activate onboard profile: (.*)$"#, "Cihazdaki profil etkinleştirilemedi: $1"), (#"^Failed to create onboard profile: (.*)$"#, "Cihazda profil oluşturulamadı: $1"), (#"^Failed to rename onboard profile: (.*)$"#, "Cihazdaki profil yeniden adlandırılamadı: $1"),
        (#"^Failed to delete onboard profile: (.*)$"#, "Cihazdaki profil silinemedi: $1"), (#"^Failed to update onboard profile: (.*)$"#, "Cihazdaki profil güncellenemedi: $1"), (#"^Could not read button profile (\d+) from the mouse\.$"#, "Fareden $1 numaralı tuş profili okunamadı."),
        (#"^(.*) is not supported for this device\.?$"#, "$1 bu cihazda desteklenmiyor."), (#"^Profile (\d+)$"#, "Profil $1"), (#"^Stored Slot (\d+)$"#, "Kayıtlı Yuva $1"), (#"^Modified from (.*)$"#, "$1 üzerinden değiştirildi"),
        (#"^Profile (\d+) is outside the supported profile range\.$"#, "Profil $1 desteklenen profil aralığının dışında."), (#"^Keypad (.*)$"#, "Tuş takımı $1"), (#"^Stage (\d+)$"#, "Kademe $1"), (#"^Side Button (\d+)$"#, "Yan Tuş $1"), (#"^Panel Button (\d+)$"#, "Panel Tuşu $1")
    ]

    static func translate(_ english: String) -> String? {
        guard Bundle.main.preferredLocalizations.first?.hasPrefix("tr") == true else { return nil }
        let range = NSRange(english.startIndex..., in: english)
        for (pattern, template) in turkish {
            guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: english, range: range) else { continue }
            return regex.replacementString(for: match, in: english, offset: 0, template: template)
        }
        return nil
    }
}
