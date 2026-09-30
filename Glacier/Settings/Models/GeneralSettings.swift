//
//  GeneralSettings.swift
//  Glacier
//

import Combine
import OSLog
import SwiftUI

// MARK: - GeneralSettings

/// Model for the app's General settings.
@MainActor
final class GeneralSettings: ObservableObject {
    /// A Boolean value that indicates whether the Glacier icon
    /// should be shown.
    @Published var showGlacierIcon = true

    /// An icon to show in the menu bar, with a different image
    /// for when items are visible or hidden.
    @Published var glacierIcon: ControlItemImageSet = .defaultGlacierIcon

    /// The last user-selected custom Glacier icon.
    @Published var lastCustomGlacierIcon: ControlItemImageSet?

    /// A Boolean value that indicates whether custom Glacier icons
    /// should be rendered as template images.
    @Published var customGlacierIconIsTemplate = false

    /// A Boolean value that indicates whether to show hidden items
    /// in a separate bar below the menu bar.
    @Published var useGlacierBar = false

    /// The location where the Glacier Bar appears.
    @Published var glacierBarLocation: GlacierBarLocation = .dynamic

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer clicks in an empty
    /// area of the menu bar.
    @Published var showOnClick = true

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer hovers over an
    /// empty area of the menu bar.
    @Published var showOnHover = false

    /// A Boolean value that indicates whether the hidden section
    /// should be shown or hidden when the user scrolls in the
    /// menu bar.
    @Published var showOnScroll = true

    /// The offset to apply to the menu bar item spacing and padding.
    @Published var itemSpacingOffset: Double = 0

    /// A Boolean value that indicates whether the hidden section
    /// should automatically rehide.
    @Published var autoRehide = true

    /// A strategy that determines how the auto-rehide feature works.
    @Published var rehideStrategy: RehideStrategy = .smart

    /// A time interval for the auto-rehide feature when its rule
    /// is ``RehideStrategy/timed``.
    @Published var rehideInterval: TimeInterval = 15

    /// Encoder for properties.
    private let encoder = JSONEncoder()

    /// Decoder for properties.
    private let decoder = JSONDecoder()

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// Performs the initial setup of the model.
    func performSetup(with appState: AppState) {
        self.appState = appState
        loadInitialState()
        configureCancellables()
    }

    /// Loads the model's initial state.
    private func loadInitialState() {
        Defaults.ifPresent(key: .showGlacierIcon, assign: &showGlacierIcon)
        Defaults.ifPresent(key: .customGlacierIconIsTemplate, assign: &customGlacierIconIsTemplate)
        Defaults.ifPresent(key: .useGlacierBar, assign: &useGlacierBar)
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showOnScroll, assign: &showOnScroll)
        Defaults.ifPresent(key: .itemSpacingOffset, assign: &itemSpacingOffset)
        Defaults.ifPresent(key: .autoRehide, assign: &autoRehide)
        Defaults.ifPresent(key: .rehideInterval, assign: &rehideInterval)

        Defaults.ifPresent(key: .glacierBarLocation) { rawValue in
            if let location = GlacierBarLocation(rawValue: rawValue) {
                glacierBarLocation = location
            }
        }
        Defaults.ifPresent(key: .rehideStrategy) { rawValue in
            if let strategy = RehideStrategy(rawValue: rawValue) {
                rehideStrategy = strategy
            }
        }

        if let data = Defaults.data(forKey: .glacierIcon) {
            do {
                glacierIcon = try decoder.decode(ControlItemImageSet.self, from: data)
            } catch {
                Logger.serialization.error("Error decoding Glacier icon: \(error, privacy: .public)")
            }
            if case .custom = glacierIcon.name {
                lastCustomGlacierIcon = glacierIcon
            }
        }
    }

    /// Configures the internal observers for the model.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showGlacierIcon
            .receive(on: DispatchQueue.main)
            .sink { showGlacierIcon in
                Defaults.set(showGlacierIcon, forKey: .showGlacierIcon)
            }
            .store(in: &c)

        $glacierIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] glacierIcon in
                guard let self else {
                    return
                }
                if case .custom = glacierIcon.name {
                    lastCustomGlacierIcon = glacierIcon
                }
                do {
                    let data = try encoder.encode(glacierIcon)
                    Defaults.set(data, forKey: .glacierIcon)
                } catch {
                    Logger.serialization.error("Error encoding Glacier icon: \(error, privacy: .public)")
                }
            }
            .store(in: &c)

        $customGlacierIconIsTemplate
            .receive(on: DispatchQueue.main)
            .sink { isTemplate in
                Defaults.set(isTemplate, forKey: .customGlacierIconIsTemplate)
            }
            .store(in: &c)

        $useGlacierBar
            .receive(on: DispatchQueue.main)
            .sink { useGlacierBar in
                Defaults.set(useGlacierBar, forKey: .useGlacierBar)
            }
            .store(in: &c)

        $glacierBarLocation
            .receive(on: DispatchQueue.main)
            .sink { location in
                Defaults.set(location.rawValue, forKey: .glacierBarLocation)
            }
            .store(in: &c)

        $showOnClick
            .receive(on: DispatchQueue.main)
            .sink { showOnClick in
                Defaults.set(showOnClick, forKey: .showOnClick)
            }
            .store(in: &c)

        $showOnHover
            .receive(on: DispatchQueue.main)
            .sink { showOnHover in
                Defaults.set(showOnHover, forKey: .showOnHover)
            }
            .store(in: &c)

        $showOnScroll
            .receive(on: DispatchQueue.main)
            .sink { showOnScroll in
                Defaults.set(showOnScroll, forKey: .showOnScroll)
            }
            .store(in: &c)

        $itemSpacingOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] offset in
                Defaults.set(offset, forKey: .itemSpacingOffset)
                appState?.spacingManager.offset = Int(offset)
            }
            .store(in: &c)

        $autoRehide
            .receive(on: DispatchQueue.main)
            .sink { autoRehide in
                Defaults.set(autoRehide, forKey: .autoRehide)
            }
            .store(in: &c)

        $rehideStrategy
            .receive(on: DispatchQueue.main)
            .sink { strategy in
                Defaults.set(strategy.rawValue, forKey: .rehideStrategy)
            }
            .store(in: &c)

        // Slider values change continuously while dragging.
        $rehideInterval
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .rehideInterval)
            }
            .store(in: &c)

        // Save the latest slider value in case the app terminates before
        // the debounce interval elapses.
        NotificationCenter.default
            .publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                Defaults.set(rehideInterval, forKey: .rehideInterval)
            }
            .store(in: &c)

        cancellables = c
    }
}

// MARK: - RehideStrategy

/// A type that determines how the auto-rehide feature works.
enum RehideStrategy: Int, CaseIterable, Identifiable {
    /// Menu bar items are rehidden using a smart algorithm.
    case smart = 0
    /// Menu bar items are rehidden after a given time interval.
    case timed = 1
    /// Menu bar items are rehidden when the focused app changes.
    case focusedApp = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .smart: "Smart"
        case .timed: "Timed"
        case .focusedApp: "Focused app"
        }
    }
}
