// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import AppKit
import ApplicationServices
import SwiftUI

/// Turns the mouse Forward button into a left double-click through a macOS event tap (needs Accessibility).
/// Only one MouseTune process installs the tap at a time; a file lock decides which one.
final class ForwardDoubleClickService: @unchecked Sendable {
    static let shared = ForwardDoubleClickService()
    static let enabledDefaultsKey = "mousetune.forwardButtonDoubleClick"
    /// macOS button numbers: 0 left, 1 right, 2 middle, 3 back, 4 forward.
    static let forwardButtonNumber: Int64 = 4

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledDefaultsKey) as? Bool ?? true }
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    private let stateLock = NSLock()
    private var lockFileDescriptor: Int32 = -1
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var didPromptForAccessibility = false

    /// Call once on the main thread at launch.
    func start() {
        attemptInstall()
        let timer = Timer(timeInterval: 5, repeats: true) { _ in ForwardDoubleClickService.shared.attemptInstall() }
        RunLoop.main.add(timer, forMode: .common)
        stateLock.lock()
        retryTimer = timer
        stateLock.unlock()
    }

    func attemptInstall() {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard acquireProcessLock() else { return }
        guard AXIsProcessTrusted() else {
            if !didPromptForAccessibility {
                didPromptForAccessibility = true
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
            return
        }
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: forwardDoubleClickTapCallback, userInfo: nil) else {
            AppLog.warning("ForwardDoubleClick", "event tap could not be created")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        runLoopSource = source
        AppLog.info("ForwardDoubleClick", "event tap installed pid=\(getpid())")
    }

    func reenableTap() {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    static func postDoubleClick(at location: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        for clickState in 1...2 {
            guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left), let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left) else { return }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func acquireProcessLock() -> Bool {
        if lockFileDescriptor >= 0 { return true }
        let directory = BatteryHistory.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("forward-double-click.lock").path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { return false }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }
        lockFileDescriptor = descriptor
        return true
    }
}

/// Event tap callback: swallows Forward presses and replaces them with a left double-click.
private func forwardDoubleClickTapCallback(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo _: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        ForwardDoubleClickService.shared.reenableTap()
        return Unmanaged.passUnretained(event)
    }
    guard type == .otherMouseDown || type == .otherMouseUp, event.getIntegerValueField(.mouseEventButtonNumber) == ForwardDoubleClickService.forwardButtonNumber, ForwardDoubleClickService.isEnabled else { return Unmanaged.passUnretained(event) }
    if type == .otherMouseDown { ForwardDoubleClickService.postDoubleClick(at: event.location) }
    return nil
}

/// Settings row under the button table: toggle plus Accessibility status.
struct ForwardDoubleClickToggleRow: View {
    @AppStorage(ForwardDoubleClickService.enabledDefaultsKey) private var isEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isEnabled) { Text("Forward button = double-click").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }.toggleStyle(.switch)
            TimelineView(.periodic(from: .now, by: 2)) { _ in
                if ForwardDoubleClickService.isAccessibilityTrusted {
                    Text("Pressing the Forward button sends a left double-click. Works while the app is running.").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                } else {
                    HStack(spacing: 8) {
                        Text("Accessibility permission is required for this to work.").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(red: 1, green: 0.8, blue: 0.4))
                        Button("Open Settings") { if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) } }.controlSize(.small)
                    }
                }
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(MouseTuneTheme.rowFill).overlay(RoundedRectangle(cornerRadius: 10).stroke(MouseTuneTheme.rowStroke, lineWidth: 1))).accessibilityIdentifier("forward-double-click-row")
    }
}
