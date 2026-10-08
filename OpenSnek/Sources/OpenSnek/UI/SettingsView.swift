// Modified in the MouseTune fork (mustafacicek-eee, 2026): app name shown in the UI changed from OpenSnek to MouseTune; on-screen text goes through L() for the Turkish translation; compact single-page layout with a Restart Now button for language changes; MouseTune visual theme (neutral dark, sky-blue accent, SF Pro type).
import AppKit
import OpenSnekAppSupport
import OpenSnekCore
import SwiftUI

/// Renders the settings view UI.
struct SettingsView: View {
    let deviceStore: DeviceStore
    let runtimeStore: RuntimeStore
    @AppStorage(AppLog.levelDefaultsKey) private var logLevelRawValue = AppLog.currentLevel.rawValue
    @AppStorage(DeveloperRuntimeOptions.pollingEnabledDefaultsKey) private var developerPollingEnabled = true
    @AppStorage(DeveloperRuntimeOptions.passiveHIDUpdatesEnabledDefaultsKey) private var developerPassiveHIDUpdatesEnabled = true
    @AppStorage(DeveloperRuntimeOptions.rememberWindowSizeEnabledDefaultsKey) private var developerRememberWindowSizeEnabled = true
    @AppStorage(DeveloperRuntimeOptions.releaseUpdateDryRunEnabledDefaultsKey) private var developerReleaseUpdateDryRunEnabled = false
    @AppStorage(DeveloperRuntimeOptions.settingStorageEnabledDefaultsKey) private var developerSettingStorageEnabled = true
    @State private var showsDiagnosticsSheet = false
    @State private var showsLocalStorageResetConfirmation = false
    @State private var selectedLanguage = AppLanguagePreference.current

    private var selectedLevel: Binding<AppLogLevel> {
        Binding(
            get: { AppLogLevel(rawValue: logLevelRawValue) ?? AppLog.defaultLevel },
            set: {
                logLevelRawValue = $0.rawValue
                AppLog.updateLevel($0)
            })
    }

    var body: some View {
        // MouseTune fork: a compact single page instead of a grouped Form, so every setting fits without scrolling.
        settingsContent.padding(.horizontal, 22).padding(.vertical, 16).frame(width: 680).fixedSize(horizontal: false, vertical: true).task { await runtimeStore.refreshHIDAccessStatus(forceRefresh: false) }.sheet(isPresented: $showsDiagnosticsSheet) {
            IssueDiagnosticsSheet(payload: deviceStore.githubIssueDiagnosticsPayload())
        }.alert("Wipe MouseTune local storage?", isPresented: $showsLocalStorageResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) {
                Task {
                    let didReset = await runtimeStore.resetAllLocalStorage()
                    guard didReset else { return }
                    logLevelRawValue = AppLog.defaultLevel.rawValue
                    developerPollingEnabled = true
                    developerPassiveHIDUpdatesEnabled = true
                    developerRememberWindowSizeEnabled = true
                    developerReleaseUpdateDryRunEnabled = false
                    developerSettingStorageEnabled = true
                }
            }
        } message: {
            Text("This removes saved preferences, cached device settings, launch-at-login state, and local logs for MouseTune.")
        }.onAppear { AppLog.updateLevel(AppLogLevel(rawValue: logLevelRawValue) ?? AppLog.defaultLevel, resetLog: false) }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionsSection
            generalSection
            languageSection
            resetSection
            loggingSection
            if deviceStore.currentBuildChannel == .dev { developerSection }
            bugReportsSection
        }
    }

    private var permissionsSection: some View {
        SettingsGroup(title: "Permissions") {
            SettingsRow(title: "Input Monitoring") {
                Text(L(runtimeStore.hidAccessStatus.diagnosticsLabel)).font(.system(size: 12, weight: .bold)).foregroundStyle(permissionStatusColor)
                Button("Open Settings") { PermissionSupport.openInputMonitoringSettings() }
                Button("Reset Permissions") { Task { await runtimeStore.resetAllPermissions() } }.disabled(runtimeStore.isResettingPermissions)
                if runtimeStore.isResettingPermissions { ProgressView().controlSize(.small) }
            }
            if let message = runtimeStore.permissionStatusMessage { SettingsNote(text: message, isEmphasized: true) }
        }
    }

    private var generalSection: some View {
        SettingsGroup(title: "General") {
            SettingsRow(title: "Show menu bar icon") { Toggle("Show menu bar icon", isOn: Binding(get: { runtimeStore.backgroundServiceEnabled }, set: { newValue in Task { await runtimeStore.setBackgroundServiceEnabled(newValue) } })).labelsHidden().toggleStyle(.switch) }
            SettingsRow(title: "Start at login") { Toggle("Start at login", isOn: Binding(get: { runtimeStore.launchAtStartupEnabled }, set: { runtimeStore.setLaunchAtStartupEnabled($0) })).labelsHidden().toggleStyle(.switch).disabled(!runtimeStore.backgroundServiceEnabled) }
            if let message = runtimeStore.compactStatusMessage ?? runtimeStore.serviceStatusMessage { SettingsNote(text: message, isEmphasized: true) }
        }
    }

    private var languageSection: some View {
        SettingsGroup(title: "Language") {
            SettingsRow(title: "App language") {
                Picker(
                    "App language",
                    selection: Binding(
                        get: { selectedLanguage },
                        set: { newValue in
                            selectedLanguage = newValue
                            newValue.apply()
                        })
                ) { ForEach(AppLanguagePreference.allCases) { language in Text(language == .system ? L(language.title) : language.title).tag(language) } }.labelsHidden().pickerStyle(.menu).fixedSize().accessibilityIdentifier("settings-language-picker")
                if selectedLanguage != AppLanguagePreference.atLaunch { Button("Restart Now") { runtimeStore.relaunchForLanguageChange() }.buttonStyle(.borderedProminent).accessibilityIdentifier("settings-language-restart-button") }
            }
            if selectedLanguage != AppLanguagePreference.atLaunch { SettingsNote(text: "The new language is used after MouseTune restarts.") }
        }
    }

    private var resetSection: some View {
        SettingsGroup(title: "Reset App Data") {
            HStack(alignment: .center, spacing: 12) {
                SettingsNote(text: "Wipe MouseTune's saved preferences, cached device settings, background-service state, and local logs. Relaunch the app after resetting.")
                Spacer(minLength: 8)
                if runtimeStore.isResettingLocalStorage { ProgressView().controlSize(.small) }
                Button("Wipe Local Storage", role: .destructive) { showsLocalStorageResetConfirmation = true }.disabled(runtimeStore.isResettingLocalStorage)
            }
            if let message = runtimeStore.localStorageResetMessage { SettingsNote(text: message, isEmphasized: true) }
        }
    }

    private var loggingSection: some View {
        SettingsGroup(title: "Logging") {
            SettingsRow(title: "Log level") { Picker("Log level", selection: selectedLevel) { ForEach(AppLogLevel.allCases) { level in Text(L(level.label)).tag(level) } }.labelsHidden().pickerStyle(.menu).fixedSize() }
            SettingsNote(text: "Use Info or Debug before reproducing a bug. Changing the level starts a fresh log file.")
            SettingsRow(title: "Log file") { Text(AppLog.path).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled) }
            HStack(spacing: 10) {
                Button("Open Log File") { NSWorkspace.shared.open(URL(fileURLWithPath: AppLog.path)) }
                Button("Open Log Folder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: AppLog.path)]) }
                Button("Clear Log") { AppLog.clear() }
            }
        }
    }

    private var developerSection: some View {
        SettingsGroup(title: "Developer") {
            Toggle("Enable runtime polling", isOn: developerPollingBinding)
            Toggle("Enable passive HID DPI stream", isOn: developerPassiveHIDBinding)
            Toggle("Enable setting storage", isOn: $developerSettingStorageEnabled)
            Toggle("Remember window size", isOn: $developerRememberWindowSizeEnabled)
            Toggle("Preview latest release update", isOn: developerReleaseUpdateDryRunBinding)
            SettingsNote(text: "Turn off Enable setting storage to apply mouse changes without updating MouseTune's saved reconnect state. Re-enable it, then reconnect the mouse or relaunch MouseTune to verify the last stored state rehydrates.")
            SettingsNote(text: "Use the transport switches to isolate polling from passive HID DPI callbacks during debugging, temporarily disable window-frame restore while testing launch behavior, or preview the latest GitHub release update prompt.")
        }
    }

    private var developerPollingBinding: Binding<Bool> {
        Binding(
            get: { developerPollingEnabled },
            set: { newValue in
                developerPollingEnabled = newValue
                runtimeStore.developerTransportSettingsDidChange()
            })
    }

    private var developerPassiveHIDBinding: Binding<Bool> {
        Binding(
            get: { developerPassiveHIDUpdatesEnabled },
            set: { newValue in
                developerPassiveHIDUpdatesEnabled = newValue
                runtimeStore.developerTransportSettingsDidChange()
            })
    }

    private var developerReleaseUpdateDryRunBinding: Binding<Bool> {
        Binding(
            get: { developerReleaseUpdateDryRunEnabled },
            set: { newValue in
                developerReleaseUpdateDryRunEnabled = newValue
                runtimeStore.developerUpdateDryRunSettingsDidChange()
            })
    }

    private var bugReportsSection: some View {
        SettingsGroup(title: "Bug Reports") {
            SettingsNote(text: "Include the failing action, whether reconnecting changed it, and a log captured at Info or Debug.")
            HStack(spacing: 10) {
                Button("Preview Payload") { showsDiagnosticsSheet = true }
                Button("Copy Payload") { copyDiagnosticsPayload() }
                Button("Open Bug Report") { openBugReport() }
            }
        }
    }

    private var permissionStatusColor: Color {
        switch runtimeStore.hidAccessStatus.authorization {
        case .granted: return Color.green
        case .denied: return Color(hex: 0xD59A2B)
        case .unknown, .unavailable: return Color.secondary
        }
    }

    private func copyDiagnosticsPayload() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deviceStore.githubIssueDiagnosticsPayload(), forType: .string)
    }

    private func openBugReport() {
        guard let url = URL(string: "https://github.com/gh123man/OpenSnek/issues/new?template=bug_report.md") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// MouseTune fork: titled, rounded group used by the compact settings page.
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(title)).font(.system(size: 13, weight: .bold)).foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 8) { content() }.padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading).background(
                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1)))
        }
    }
}

/// MouseTune fork: one settings line with the label on the left and its controls on the right.
private struct SettingsRow<Controls: View>: View {
    let title: String
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(L(title)).font(.system(size: 13))
            Spacer(minLength: 12)
            controls()
        }.frame(minHeight: 22)
    }
}

/// MouseTune fork: secondary explanatory text inside a settings group.
private struct SettingsNote: View {
    let text: String
    var isEmphasized = false

    var body: some View { Text(L(text)).font(.system(size: 11.5, weight: isEmphasized ? .semibold : .regular)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}

/// Renders the issue diagnostics sheet UI.
private struct IssueDiagnosticsSheet: View {
    let payload: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub Issue Payload").font(.system(size: 21, weight: .bold))
                    Text("Paste this into a GitHub bug report.").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }

                Spacer()

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(payload, forType: .string)
                }.buttonStyle(.borderedProminent)

                Button("Done") { dismiss() }.buttonStyle(.bordered)
            }

            ScrollView { Text(payload).font(.system(size: 12, weight: .medium, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(12) }.background(
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1)))
        }.padding(18).frame(minWidth: 760, minHeight: 560, alignment: .topLeading)
    }
}
