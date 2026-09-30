//
//  SectionLayoutEditing27.swift
//  Glacier
//

extension SectionLayout27 {
    /// The saved layout after moving an application to a section. Applications missing
    /// from the layout are visible, so moving one to Visible removes its entry.
    static func settingSection(_ section: MacOS27Section, for bundleID: String, in saved: [String: MacOS27Section]) -> [String: MacOS27Section] {
        var updated = saved
        updated[bundleID] = section == .visible ? nil : section
        return updated
    }

    /// The applications pinned to Visible after moving an application to a section.
    ///
    /// Having no entry in the saved layout also means Visible, so an application the user moved
    /// there on purpose is remembered here, and is never hidden to fit beside the notch.
    static func pinnedVisible(settingSection section: MacOS27Section, for bundleID: String, in pinned: Set<String>) -> Set<String> {
        var updated = pinned
        if section == .visible {
            updated.insert(bundleID)
        } else {
            updated.remove(bundleID)
        }
        return updated
    }
}
