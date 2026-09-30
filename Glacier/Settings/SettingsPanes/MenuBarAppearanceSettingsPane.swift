//
//  MenuBarAppearanceSettingsPane.swift
//  Glacier
//

import SwiftUI

struct MenuBarAppearanceSettingsPane: View {
    @ObservedObject var appearanceManager: MenuBarAppearanceManager

    var body: some View {
        MenuBarAppearanceEditor(appearanceManager: appearanceManager, location: .settings)
    }
}
