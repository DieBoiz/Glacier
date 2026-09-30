//
//  NotchFitPlanning27.swift
//  Glacier
//

import CoreGraphics

extension NotchFit27 {
    /// A menu bar item as read through Accessibility, reduced to what the fit needs.
    struct BarItem: Equatable {
        /// The application that can hide the item, or `nil` if it cannot be hidden.
        var bundleID: String?
        /// Tells apart the items that cannot be hidden.
        var key: String
        var frame: CGRect
        var isOnScreen: Bool
        var isConcealed: Bool = false
        /// One of Glacier's own items.
        var isOwn: Bool = false
        /// One of the system items MenuBarAgent draws, like the clock.
        var isSystem: Bool = false

        var isDrawn: Bool {
            isOnScreen && !isConcealed && frame.width > 4
        }
    }

    /// One read of the notched bar.
    struct Bar {
        var items: [BarItem]
        var displayBounds: CGRect
        var notch: ClosedRange<CGFloat>?

        /// The items that take room on this bar. A concealed application can keep frames from
        /// another display (see `ItemDrawing27`), so its items count wherever they are.
        var itemsOnBar: [BarItem] {
            items.filter { $0.isConcealed || displayBounds.intersects($0.frame) }
        }
    }

    /// The settings the fit works with.
    struct Parameters {
        /// Room left free next to the notch.
        var gap: CGFloat
        /// The spacing used when the read shows no two neighbouring items.
        var defaultSpacing: CGFloat
        var slack: CGFloat
    }

    struct Plan: Equatable {
        /// The applications to hide.
        var hidden: Set<String>
        /// Applications hidden before that are running but report no items and were never
        /// measured. They stay hidden only while they are in `keepUnseen`.
        var unseen: Set<String>
    }

    /// The widths of the applications whose items are all drawn in this read.
    ///
    /// An application with an item folded into the overflow is left out: measuring only its
    /// drawn items would take it for narrower than it is.
    static func measurements(of bar: Bar) -> [String: NotchWidthCache27.Measurement] {
        var measured = [String: NotchWidthCache27.Measurement]()
        var partial = Set<String>()
        for item in bar.itemsOnBar where !item.isOwn && !item.isConcealed {
            guard let bundleID = item.bundleID else {
                continue
            }
            guard item.isOnScreen else {
                partial.insert(bundleID)
                continue
            }
            guard item.frame.width > 4 else {
                continue
            }
            var measurement = measured[bundleID] ?? NotchWidthCache27.Measurement(widths: [], position: item.frame.minX)
            measurement.widths.append(item.frame.width)
            measurement.position = max(measurement.position, item.frame.minX)
            measured[bundleID] = measurement
        }
        return measured.filter { !partial.contains($0.key) }
    }

    /// The applications to hide so the rest of the notched bar fits, or `nil` if the read does
    /// not show the bar: no notch, or nothing drawn on it, or no system item drawn, as when the
    /// bar is hidden or the read came from another display.
    static func plan(
        bar: Bar,
        saved: [String: MacOS27Section],
        pinned: Set<String>,
        running: Set<String>,
        previous: Set<String>,
        keepUnseen: Set<String>,
        widths: NotchWidthCache27,
        parameters: Parameters
    ) -> Plan? {
        guard let notch = bar.notch else {
            return nil
        }
        let onBar = bar.itemsOnBar
        let drawnFrames = onBar.filter { !$0.isOwn && $0.isDrawn }.map(\.frame)
        guard let rightEnd = drawnFrames.map(\.maxX).max(), onBar.contains(where: { $0.isSystem && $0.isDrawn }) else {
            return nil
        }

        var entries = [Entry]()
        var candidates = [String: [BarItem]]()
        for item in onBar {
            if item.isOwn {
                // Glacier's icon takes room too; its dividers are collapsed to nothing.
                if item.frame.width > 4 {
                    entries.append(Entry(bundleID: item.key, width: item.frame.width, position: item.frame.minX, isFixed: true))
                }
                continue
            }
            guard let bundleID = item.bundleID else {
                // Items that cannot be hidden take room even when folded.
                if !item.isConcealed, item.frame.width > 4 {
                    entries.append(Entry(bundleID: item.key, width: item.frame.width, position: item.frame.minX, isFixed: true))
                }
                continue
            }
            // An application the user put in Hidden or Always Hidden takes no room.
            if let section = saved[bundleID], section != .visible {
                continue
            }
            candidates[bundleID, default: []].append(item)
        }

        for (bundleID, items) in candidates {
            let isPinned = pinned.contains(bundleID)
            let reported = items.filter { $0.frame.width > 4 }
            guard let measurement = widths.measurement(for: bundleID) else {
                // Never seen whole, most likely folded since Glacier started. The frames macOS
                // reports for folded items are the best there is until it is drawn once.
                entries += reported.map {
                    Entry(bundleID: bundleID, width: $0.frame.width, position: $0.frame.minX, isPinned: isPinned)
                }
                continue
            }
            let position = items.filter(\.isDrawn).map(\.frame.minX).max() ?? measurement.position
            entries += measurement.widths.map {
                Entry(bundleID: bundleID, width: $0, position: position, isPinned: isPinned)
            }
            // Items added since the measurement, likely folded, count at their reported width.
            let extra = reported.sorted { !$0.isDrawn && $1.isDrawn }.prefix(max(0, reported.count - measurement.widths.count))
            entries += extra.map {
                Entry(bundleID: bundleID, width: $0.frame.width, position: position, isPinned: isPinned)
            }
        }

        // An application hidden before whose items are not reported now is judged by what was
        // measured, or else kept hidden for a while: showing it only to hide it again would
        // make the bar move for nothing.
        var unseen = Set<String>()
        for bundleID in previous where candidates[bundleID] == nil && running.contains(bundleID) {
            guard saved[bundleID] == nil, !pinned.contains(bundleID) else {
                continue
            }
            if let measurement = widths.measurement(for: bundleID) {
                entries += measurement.widths.map {
                    Entry(bundleID: bundleID, width: $0, position: measurement.position)
                }
            } else {
                unseen.insert(bundleID)
            }
        }

        let hidden = overflowing(
            entries: entries,
            availableWidth: rightEnd - notch.upperBound - parameters.gap,
            spacing: spacing(drawnFrames: drawnFrames, rightOf: notch.upperBound) ?? parameters.defaultSpacing,
            previous: previous,
            slack: parameters.slack
        )
        return Plan(hidden: hidden.union(unseen.intersection(keepUnseen)), unseen: unseen)
    }

    /// The median distance between neighbouring drawn items right of the notch, which depends
    /// on Glacier's item spacing setting.
    static func spacing(drawnFrames: [CGRect], rightOf minX: CGFloat) -> CGFloat? {
        let sorted = drawnFrames.filter { $0.minX >= minX }.sorted { $0.minX < $1.minX }
        let gaps = zip(sorted, sorted.dropFirst())
            .map { $1.minX - $0.maxX }
            .filter { (-6...20).contains($0) }
            .sorted()
        return gaps.isEmpty ? nil : gaps[gaps.count / 2]
    }

    /// The applications that are hidden only to fit, leaving out the ones the user placed.
    static func effective(_ autoHidden: Set<String>, saved: [String: MacOS27Section], pinned: Set<String>) -> Set<String> {
        autoHidden.filter { saved[$0] == nil && !pinned.contains($0) }
    }
}
