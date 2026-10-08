// Copyright 2026 mustafacicek-eee. Part of the MouseTune fork of OpenSnek.
// Licensed under the Apache License, Version 2.0; see the LICENSE file.

import OpenSnekCore
import SwiftUI

/// Settings button shown in the top-right corner of every main-window state (it replaces the old sidebar gear).
struct SettingsGearButton: View {
    var body: some View { SettingsLink { Image(systemName: "gearshape").font(.system(size: 17, weight: .semibold)).frame(width: 24, height: 22) }.buttonStyle(.bordered).controlSize(.regular).help(L("Settings")).accessibilityLabel(L("Settings")).accessibilityIdentifier("settings-gear-button") }
}

/// Device name in the header. With more than one supported device connected it opens a list to switch between them.
struct DeviceTitleSwitcher: View {
    let deviceStore: DeviceStore
    let selected: MouseDevice
    @State private var showsDeviceList = false

    var body: some View {
        if deviceStore.devices.count > 1 {
            Button {
                showsDeviceList.toggle()
            } label: {
                HStack(spacing: 10) {
                    title
                    Image(systemName: "chevron.down").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help(L("Switch device")).accessibilityIdentifier("device-switcher-button").popover(isPresented: $showsDeviceList, arrowEdge: .bottom) { deviceList }
        } else {
            title
        }
    }

    private var title: some View { Text(selected.product_name).font(.system(size: 32, weight: .bold)).foregroundStyle(.white).accessibilityIdentifier("selected-device-name").accessibilityLabel(selected.product_name) }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(deviceStore.devices) { device in
                Button {
                    deviceStore.selectDevice(device.id)
                    showsDeviceList = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(MouseTuneTheme.accent).opacity(device.id == deviceStore.selectedDeviceID ? 1 : 0)
                        Text(device.product_name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Spacer(minLength: 16)
                        Text(device.transport.shortLabel).font(.system(size: 11, weight: .bold)).foregroundStyle(MouseTuneTheme.accent)
                    }.padding(.horizontal, 10).padding(.vertical, 7).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("device-switcher-row-\(device.id)")
            }
        }.padding(6).frame(minWidth: 280)
    }
}
