//
//  Constants.swift
//  Ice
//

import Foundation

enum Constants {
    /// The version string in the app's bundle.
    static let versionString = Bundle.main.versionString ?? "0"

    /// The build string in the app's bundle.
    static let buildString = Bundle.main.buildString ?? "0"

    /// The user-readable copyright string in the app's bundle.
    static let copyrightString = Bundle.main.copyrightString ?? ""

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.jordanbaird.Ice"

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"

    /// The title for the settings window.
    static let settingsWindowTitle = "Ice"

    /// The title for the permissions window.
    static let permissionsWindowTitle = "Permissions"
}
