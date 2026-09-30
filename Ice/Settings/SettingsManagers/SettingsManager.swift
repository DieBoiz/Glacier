//
//  SettingsManager.swift
//  Ice
//

import Combine
import Foundation

@MainActor
final class SettingsManager: ObservableObject {
    /// The manager for general settings.
    let generalSettingsManager: GeneralSettingsManager

    /// The manager for advanced settings.
    let advancedSettingsManager: AdvancedSettingsManager

    /// The manager for hotkey settings.
    let hotkeySettingsManager: HotkeySettingsManager

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    init(appState: AppState) {
        self.generalSettingsManager = GeneralSettingsManager(appState: appState)
        self.advancedSettingsManager = AdvancedSettingsManager(appState: appState)
        self.hotkeySettingsManager = HotkeySettingsManager(appState: appState)
        self.appState = appState
    }

    func performSetup() {
        configureCancellables()
        generalSettingsManager.performSetup()
        advancedSettingsManager.performSetup()
        hotkeySettingsManager.performSetup()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        generalSettingsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)
        advancedSettingsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)
        hotkeySettingsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)

        cancellables = c
    }
}

// MARK: SettingsManager: BindingExposable
extension SettingsManager: BindingExposable { }

extension Publisher where Failure == Never {
    /// Stores each value emitted by the publisher in the defaults under
    /// the given key, delivering values on the main queue.
    func persist(forKey key: Defaults.Key) -> AnyCancellable {
        receive(on: DispatchQueue.main).sink { value in
            Defaults.set(value, forKey: key)
        }
    }
}
