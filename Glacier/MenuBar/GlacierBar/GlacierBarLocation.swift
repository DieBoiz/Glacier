//
//  GlacierBarLocation.swift
//  Glacier
//

import SwiftUI

/// Locations where the Glacier Bar can appear.
enum GlacierBarLocation: Int, CaseIterable, Identifiable {
    /// The Glacier Bar will appear in different locations based on context.
    case dynamic = 0

    /// The Glacier Bar will appear centered below the mouse pointer.
    case mousePointer = 1

    /// The Glacier Bar will appear centered below the Glacier icon.
    case glacierIcon = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .dynamic: "Dynamic"
        case .mousePointer: "Mouse pointer"
        case .glacierIcon: "Glacier icon"
        }
    }
}
