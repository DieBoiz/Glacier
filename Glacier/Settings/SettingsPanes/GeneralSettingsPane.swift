//
//  GeneralSettingsPane.swift
//  Glacier
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var settings: GeneralSettings
    @State private var isImportingCustomGlacierIcon = false
    @State private var isPresentingError = false
    @State private var presentedError: LocalizedErrorWrapper?
    @State private var isApplyingItemSpacingOffset = false
    @State private var tempItemSpacingOffset: CGFloat = 0

    private var itemSpacingOffsetKey: LocalizedStringKey {
        switch tempItemSpacingOffset {
        case -16: "none"
        case 0: "default"
        case 16: "max"
        default: LocalizedStringKey(tempItemSpacingOffset.formatted())
        }
    }

    private var rehideIntervalKey: LocalizedStringKey {
        let formatted = settings.rehideInterval.formatted()
        if settings.rehideInterval == 1 {
            return LocalizedStringKey(formatted + " second")
        } else {
            return LocalizedStringKey(formatted + " seconds")
        }
    }

    var body: some View {
        GlacierForm {
            GlacierSection {
                appOptions
            }
            GlacierSection {
                glacierIconOptions
            }
            GlacierSection {
                glacierBarOptions
            }
            GlacierSection {
                showOptions
            }
            GlacierSection {
                rehideOptions
            }
            GlacierSection {
                spacingOptions
            }
        }
    }

    // MARK: App Options

    @ViewBuilder
    private var appOptions: some View {
        LaunchAtLogin.Toggle()
    }

    // MARK: Glacier Icon Options

    @ViewBuilder
    private var glacierIconOptions: some View {
        showGlacierIcon
        if settings.showGlacierIcon {
            glacierIconPicker
        }
    }

    @ViewBuilder
    private var showGlacierIcon: some View {
        Toggle("Show Glacier icon", isOn: $settings.showGlacierIcon)
            .annotation("Click to show hidden menu bar items. Right-click to access Glacier's settings.")
    }

    @ViewBuilder
    private var glacierIconPicker: some View {
        let labelKey = LocalizedStringKey("Glacier icon")

        GlacierMenu(labelKey) {
            Picker(labelKey, selection: $settings.glacierIcon) {
                ForEach(ControlItemImageSet.userSelectableGlacierIcons) { imageSet in
                    Button {
                        settings.glacierIcon = imageSet
                    } label: {
                        glacierIconMenuItem(for: imageSet)
                    }
                    .tag(imageSet)
                }
                if let lastCustomGlacierIcon = settings.lastCustomGlacierIcon {
                    Button {
                        settings.glacierIcon = lastCustomGlacierIcon
                    } label: {
                        glacierIconMenuItem(for: lastCustomGlacierIcon)
                    }
                    .tag(lastCustomGlacierIcon)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()

            Button("Choose image…") {
                isImportingCustomGlacierIcon = true
            }
        } title: {
            glacierIconMenuItem(for: settings.glacierIcon)
        }
        .annotation("Choose a custom icon to show in the menu bar.")
        .fileImporter(
            isPresented: $isImportingCustomGlacierIcon,
            allowedContentTypes: [.image]
        ) { result in
            do {
                let url = try result.get()
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    settings.glacierIcon = ControlItemImageSet(name: .custom, image: .data(data))
                }
            } catch {
                presentedError = LocalizedErrorWrapper(error)
                isPresentingError = true
            }
        }
        .alert(isPresented: $isPresentingError, error: presentedError) {
            Button("OK") {
                presentedError = nil
                isPresentingError = false
            }
        }

        if case .custom = settings.glacierIcon.name {
            Toggle("Custom icon uses dynamic appearance", isOn: $settings.customGlacierIconIsTemplate)
                .annotation {
                    Text(
                        """
                        Display the icon as a monochrome image that dynamically adjusts to match \
                        the menu bar's appearance. This setting removes all color from the icon, \
                        but ensures consistent rendering with both light and dark backgrounds.
                        """
                    )
                    .padding(.trailing, 50)
                }
        }
    }

    @ViewBuilder
    private func glacierIconMenuItem(for imageSet: ControlItemImageSet) -> some View {
        Label {
            Text(imageSet.name.rawValue)
        } icon: {
            if let nsImage = imageSet.hidden.nsImage(for: appState) {
                switch imageSet.name {
                case .custom:
                    Image(size: CGSize(width: 18, height: 18)) { context in
                        context.draw(Image(nsImage: nsImage), in: context.clipBoundingRect)
                    }
                default:
                    Image(nsImage: nsImage)
                }
            }
        }
    }

    // MARK: Glacier Bar Options

    @ViewBuilder
    private var glacierBarOptions: some View {
        useGlacierBar
        if #available(macOS 27.0, *) {
            autoFitNotch
        }
        if settings.useGlacierBar {
            glacierBarLocationPicker
        }
    }

    @ViewBuilder
    private var autoFitNotch: some View {
        Toggle("Fit menu bar items around the notch", isOn: $settings.autoFitNotch)
            .disabled(!settings.useGlacierBar)
            .annotation {
                if settings.useGlacierBar {
                    Text(
                        """
                        On a display with a notch, apps whose items would not fit beside it \
                        are moved to the Glacier Bar. Apps you move to Visible after turning this on \
                        stay there.
                        """
                    )
                } else {
                    Text("Requires the Glacier Bar.")
                }
            }
    }

    @ViewBuilder
    private var useGlacierBar: some View {
        Toggle("Use Glacier Bar", isOn: $settings.useGlacierBar)
            .annotation("Show hidden menu bar items in a separate bar below the menu bar.")
    }

    @ViewBuilder
    private var glacierBarLocationPicker: some View {
        GlacierPicker("Location", selection: $settings.glacierBarLocation) {
            ForEach(GlacierBarLocation.allCases) { location in
                Text(location.localized).tag(location)
            }
        }
        .annotation {
            switch settings.glacierBarLocation {
            case .dynamic:
                Text("The Glacier Bar's location changes based on context.")
            case .mousePointer:
                Text("The Glacier Bar is centered below the mouse pointer.")
            case .glacierIcon:
                Text("The Glacier Bar is centered below the Glacier icon.")
            }
        }
    }

    // MARK: Show Options

    @ViewBuilder
    private var showOptions: some View {
        Toggle("Show on click", isOn: $settings.showOnClick)
            .annotation("Click inside an empty area of the menu bar to show hidden menu bar items.")
        Toggle("Show on hover", isOn: $settings.showOnHover)
            .annotation("Hover over an empty area of the menu bar to show hidden menu bar items.")
        Toggle("Show on scroll", isOn: $settings.showOnScroll)
            .annotation("Scroll or swipe in the menu bar to show hidden menu bar items.")
    }

    // MARK: Rehide Options

    @ViewBuilder
    private var rehideOptions: some View {
        autoRehide
        if settings.autoRehide {
            rehideStrategyPicker
        }
    }

    @ViewBuilder
    private var autoRehide: some View {
        Toggle("Automatically rehide", isOn: $settings.autoRehide)
    }

    @ViewBuilder
    private var rehideStrategyPicker: some View {
        VStack {
            GlacierPicker("Strategy", selection: $settings.rehideStrategy) {
                ForEach(RehideStrategy.allCases) { strategy in
                    Text(strategy.localized).tag(strategy)
                }
            }
            .annotation {
                switch settings.rehideStrategy {
                case .smart:
                    Text("Menu bar items are rehidden using a smart algorithm.")
                case .timed:
                    Text("Menu bar items are rehidden after a fixed amount of time.")
                case .focusedApp:
                    Text("Menu bar items are rehidden when the focused app changes.")
                }
            }

            if case .timed = settings.rehideStrategy {
                GlacierSlider(
                    rehideIntervalKey,
                    value: $settings.rehideInterval,
                    in: 0...30,
                    step: 1
                )
            }
        }
    }

    // MARK: Spacing Options

    @ViewBuilder
    private var spacingOptions: some View {
        LabeledContent {
            GlacierSlider(
                itemSpacingOffsetKey,
                value: $tempItemSpacingOffset,
                in: -16...16,
                step: 2
            )
            .disabled(isApplyingItemSpacingOffset)
        } label: {
            LabeledContent {
                Button("Apply") {
                    applyTempItemSpacingOffset()
                }
                .help("Apply the current spacing")
                .disabled(isApplyingItemSpacingOffset || tempItemSpacingOffset == settings.itemSpacingOffset)

                if isApplyingItemSpacingOffset {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                        .frame(width: 15, height: 15)
                } else {
                    Button {
                        tempItemSpacingOffset = 0
                        applyTempItemSpacingOffset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to the default spacing")
                    .disabled(isApplyingItemSpacingOffset || settings.itemSpacingOffset == 0)
                }
            } label: {
                HStack {
                    Text("Menu bar item spacing")
                    BetaBadge()
                }
            }
        }
        .annotation(
            "Applying this setting will relaunch all apps with menu bar items. Some apps may need to be manually relaunched.",
            spacing: 2
        )
        .annotation(spacing: 10) {
            CalloutBox(
                "Note: You may need to log out and back in for this setting to apply properly.",
                systemImage: "exclamationmark.circle"
            )
        }
        .onAppear {
            tempItemSpacingOffset = settings.itemSpacingOffset
        }
    }

    private func applyTempItemSpacingOffset() {
        isApplyingItemSpacingOffset = true
        settings.itemSpacingOffset = tempItemSpacingOffset
        Task {
            do {
                try await appState.spacingManager.applyOffset()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
            isApplyingItemSpacingOffset = false
        }
    }
}
