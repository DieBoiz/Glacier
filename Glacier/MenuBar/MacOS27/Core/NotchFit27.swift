//
//  NotchFit27.swift
//  Glacier
//

import CoreGraphics

/// Decides which applications to hide so the rest fit to the right of the notch.
///
/// On a notched display macOS 27 folds the items that do not fit beside the notch behind an
/// overflow button, where Glacier cannot reach them. Hiding whole applications before that
/// happens moves them to the Glacier Bar instead. The bar is filled from the right, the way
/// macOS lays it out, and only by position and width.
enum NotchFit27 {
    /// A menu bar item as the fit sees it.
    struct Entry: Equatable {
        var bundleID: String
        var width: CGFloat
        /// The item's left edge. Only the order matters.
        var position: CGFloat
        /// The user put the application in Visible on purpose, so it is never hidden.
        var isPinned: Bool = false
        /// The item cannot be hidden, like the clock or Control Center.
        var isFixed: Bool = false
    }

    /// The applications to hide so the remaining items fit in the available width.
    ///
    /// - Parameters:
    ///   - entries: Every item on the bar that takes room to the right of the notch.
    ///   - availableWidth: The room to the right of the notch, or `nil` if it is unknown.
    ///   - spacing: The distance between neighbouring items; negative when they overlap.
    ///   - previous: The applications hidden by the last fit.
    ///   - slack: How much room an application from `previous` needs to spare before it is
    ///     shown again, so an application right at the edge does not come and go.
    static func overflowing(
        entries: [Entry],
        availableWidth: CGFloat?,
        spacing: CGFloat,
        previous: Set<String>,
        slack: CGFloat
    ) -> Set<String> {
        guard let availableWidth, availableWidth > 0 else {
            return []
        }
        // n items need n - 1 gaps, so the budget gets one gap back.
        let budget = availableWidth + spacing
        let ordered = groups(entries).sorted { lhs, rhs in
            lhs.position == rhs.position ? lhs.bundleID < rhs.bundleID : lhs.position > rhs.position
        }
        // Pinned and fixed items get their room first, wherever they sit: filling strictly from
        // the right would let an application to their right push a pinned one into the overflow.
        var used = ordered
            .filter { $0.isFixed || $0.isPinned }
            .reduce(0) { $0 + cost(of: $1, spacing: spacing) }
        var result = Set<String>()
        for group in ordered where !group.isFixed && !group.isPinned {
            let cost = cost(of: group, spacing: spacing)
            let needed = previous.contains(group.bundleID) ? cost + slack : cost
            if used + needed <= budget {
                used += cost
            } else {
                result.insert(group.bundleID)
            }
        }
        return result
    }

    private static func cost(of group: Group, spacing: CGFloat) -> CGFloat {
        group.width + CGFloat(group.count) * spacing
    }

    private struct Group {
        var bundleID: String
        var width: CGFloat
        var count: Int
        var position: CGFloat
        var isPinned: Bool
        var isFixed: Bool
    }

    /// Joins the items of each application, which is hidden or shown as a whole.
    private static func groups(_ entries: [Entry]) -> [Group] {
        var groups = [String: Group]()
        for entry in entries {
            if var group = groups[entry.bundleID] {
                group.width += entry.width
                group.count += 1
                group.position = max(group.position, entry.position)
                group.isPinned = group.isPinned || entry.isPinned
                group.isFixed = group.isFixed || entry.isFixed
                groups[entry.bundleID] = group
            } else {
                groups[entry.bundleID] = Group(
                    bundleID: entry.bundleID,
                    width: entry.width,
                    count: 1,
                    position: entry.position,
                    isPinned: entry.isPinned,
                    isFixed: entry.isFixed
                )
            }
        }
        return Array(groups.values)
    }
}

extension NotchFit27 {
    /// The saved layout with the applications hidden to fit beside the notch added to Hidden.
    ///
    /// The user's own sections always win: an application the user placed anywhere, or pinned
    /// to Visible, keeps that section.
    static func layout(
        saved: [String: MacOS27Section],
        autoHidden: Set<String>,
        pinned: Set<String>
    ) -> [String: MacOS27Section] {
        var layout = saved
        for bundleID in autoHidden where saved[bundleID] == nil && !pinned.contains(bundleID) {
            layout[bundleID] = .hidden
        }
        return layout
    }
}

/// The widths of each application's items, taken while they were drawn.
///
/// A concealed application keeps reporting the frames it last had, and the items macOS folded
/// report frames stacked against the overflow button, so neither can be measured. Nor does
/// concealing an application make macOS lay the folded items out again. The fit therefore works
/// from the widths seen the last time each application was drawn.
///
/// Items that change width, like a timer or a network meter, are kept at the widest they were
/// within a window of time. Fitting them at their current width would hide and show whatever
/// sits next to them each time they grow and shrink.
struct NotchWidthCache27: Equatable {
    struct Measurement: Equatable {
        var widths: [CGFloat]
        /// The left edge of the application's rightmost item.
        var position: CGFloat

        var total: CGFloat {
            widths.reduce(0, +)
        }
    }

    private struct Record: Equatable {
        var peak: Measurement
        var peakAt: Double
    }

    private var records = [String: Record]()

    /// Width changes smaller than this are noise, not a reason to fit the bar again.
    static let tolerance: CGFloat = 2

    /// How long the widest measurement of an application stands.
    static let peakWindow: Double = 600

    /// Records the applications measured in one read of the bar.
    ///
    /// - Parameter now: The time of the read, in seconds.
    /// - Returns: Whether an application is new or its widths changed enough to fit again.
    mutating func record(_ measured: [String: Measurement], now: Double) -> Bool {
        var changed = false
        for (bundleID, measurement) in measured {
            guard var record = records[bundleID] else {
                records[bundleID] = Record(peak: measurement, peakAt: now)
                changed = true
                continue
            }
            let old = record.peak
            if
                measurement.widths.count != old.widths.count ||
                measurement.total >= old.total ||
                now - record.peakAt > Self.peakWindow
            {
                record.peak = measurement
                record.peakAt = now
            } else {
                record.peak.position = measurement.position
            }
            records[bundleID] = record
            if record.peak.widths.count != old.widths.count || abs(record.peak.total - old.total) >= Self.tolerance {
                changed = true
            }
        }
        return changed
    }

    /// The widest recent measurement of an application, at its latest position.
    func measurement(for bundleID: String) -> Measurement? {
        records[bundleID]?.peak
    }
}
