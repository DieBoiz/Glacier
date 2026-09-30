//
//  Hotkey.swift
//  Ice
//

import Combine

/// A combination of a key and modifiers that can be used to
/// trigger actions on system-wide key-up or key-down events.
final class Hotkey: ObservableObject {
    private weak var appState: AppState?

    private var listener: Listener?

    let action: HotkeyAction

    @Published var keyCombination: KeyCombination? {
        didSet {
            updateListener()
        }
    }

    /// A Boolean value that indicates whether the hotkey is allowed to be registered.
    private(set) var isEnabled = true

    init(keyCombination: KeyCombination?, action: HotkeyAction) {
        self.keyCombination = keyCombination
        self.action = action
    }

    func assignAppState(_ appState: AppState) {
        self.appState = appState
        updateListener()
    }

    func enable() {
        isEnabled = true
        updateListener()
    }

    func disable() {
        isEnabled = false
        updateListener()
    }

    private func updateListener() {
        listener?.invalidate()
        listener = nil
        if isEnabled {
            listener = Listener(hotkey: self, eventKind: .keyDown, appState: appState)
        }
    }
}

extension Hotkey {
    /// An object that manges the lifetime of a hotkey observation.
    private final class Listener {
        private let registry: HotkeyRegistry

        private var id: UInt32?

        init?(hotkey: Hotkey, eventKind: HotkeyRegistry.EventKind, appState: AppState?) {
            guard
                let appState,
                hotkey.keyCombination != nil
            else {
                return nil
            }
            let registry = appState.hotkeyRegistry
            let id = registry.register(
                hotkey: hotkey,
                eventKind: eventKind
            ) { [weak hotkey, weak appState] in
                guard
                    let hotkey,
                    let appState
                else {
                    return
                }
                Task {
                    await hotkey.action.perform(appState: appState)
                }
            }
            guard let id else {
                return nil
            }
            self.registry = registry
            self.id = id
        }

        deinit {
            invalidate()
        }

        func invalidate() {
            if let id {
                registry.unregister(id)
            }
            id = nil
        }
    }
}

// MARK: Hotkey: Codable
extension Hotkey: Codable {
    private enum CodingKeys: CodingKey {
        case keyCombination
        case action
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            keyCombination: container.decode(KeyCombination?.self, forKey: .keyCombination),
            action: container.decode(HotkeyAction.self, forKey: .action)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCombination, forKey: .keyCombination)
        try container.encode(action, forKey: .action)
    }
}

// MARK: Hotkey: Equatable
extension Hotkey: Equatable {
    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        lhs.keyCombination == rhs.keyCombination &&
        lhs.action == rhs.action
    }
}

// MARK: Hotkey: Hashable
extension Hotkey: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCombination)
        hasher.combine(action)
    }
}

// MARK: - Logger
private extension Logger {
    static let hotkey = Logger(category: "Hotkey")
}
