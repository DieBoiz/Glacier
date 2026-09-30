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

    /// The app's bundle identifier.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.jordanbaird.Ice"

    /// The app's display name.
    static let displayName = Bundle.main.displayName ?? "Ice"
}
