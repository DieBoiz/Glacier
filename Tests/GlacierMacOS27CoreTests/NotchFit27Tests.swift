import CoreGraphics
import Testing
@testable import GlacierMacOS27Core

@Suite("NotchFit27")
struct NotchFit27Tests {
    typealias Entry = NotchFit27.Entry

    let clock = Entry(bundleID: "com.apple.MenuBarAgent", width: 100, position: 1700, isFixed: true)

    func fit(
        _ entries: [Entry],
        available: CGFloat?,
        spacing: CGFloat = 0,
        previous: Set<String> = [],
        slack: CGFloat = 0
    ) -> Set<String> {
        NotchFit27.overflowing(entries: entries, availableWidth: available, spacing: spacing, previous: previous, slack: slack)
    }

    @Test("Nothing is hidden when everything fits")
    func everythingFits() {
        let entries = [clock, Entry(bundleID: "a", width: 30, position: 1600), Entry(bundleID: "b", width: 30, position: 1500)]
        #expect(fit(entries, available: 300).isEmpty)
    }

    @Test("Items that fill the room exactly all stay")
    func exactFit() {
        let entries = [clock, Entry(bundleID: "a", width: 50, position: 1600), Entry(bundleID: "b", width: 50, position: 1500)]
        #expect(fit(entries, available: 200).isEmpty)
        #expect(fit(entries, available: 199.5) == ["b"])
    }

    @Test("The gaps between items count, but only between them")
    func spacing() {
        let entries = [clock, Entry(bundleID: "a", width: 50, position: 1600), Entry(bundleID: "b", width: 50, position: 1500)]
        #expect(fit(entries, available: 216, spacing: 8).isEmpty)
        #expect(fit(entries, available: 215, spacing: 8) == ["b"])
        // Measured on macOS 27.0: neighbours overlap by 2 points.
        #expect(fit(entries, available: 196, spacing: -2).isEmpty)
    }

    @Test("The leftmost application that does not fit is hidden")
    func oneOverflows() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 40, position: 1600),
            Entry(bundleID: "b", width: 40, position: 1550),
            Entry(bundleID: "c", width: 40, position: 1500),
        ]
        #expect(fit(entries, available: 200) == ["c"])
    }

    @Test("Several applications can be hidden")
    func severalOverflow() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 40, position: 1600),
            Entry(bundleID: "b", width: 40, position: 1550),
            Entry(bundleID: "c", width: 40, position: 1500),
            Entry(bundleID: "d", width: 40, position: 1450),
        ]
        #expect(fit(entries, available: 150) == ["b", "c", "d"])
    }

    @Test("A narrow application further left takes room a wide one could not use")
    func narrowAfterWide() {
        let entries = [
            clock,
            Entry(bundleID: "wide", width: 80, position: 1600),
            Entry(bundleID: "narrow", width: 20, position: 1500),
        ]
        #expect(fit(entries, available: 150) == ["wide"])
    }

    @Test("The order on the bar comes from the positions, not the order given")
    func unordered() {
        let entries = [
            Entry(bundleID: "left", width: 40, position: 1400),
            clock,
            Entry(bundleID: "right", width: 40, position: 1600),
        ]
        #expect(fit(entries, available: 150) == ["left"])
    }

    @Test("Pinned and fixed items are never hidden, but take room")
    func pinnedAndFixed() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 40, position: 1600),
            Entry(bundleID: "pinned", width: 40, position: 1550, isPinned: true),
            Entry(bundleID: "recording", width: 30, position: 1520, isFixed: true),
            Entry(bundleID: "b", width: 40, position: 1450),
        ]
        #expect(fit(entries, available: 250).isEmpty)
        #expect(fit(entries, available: 220) == ["b"])
        // The pinned application sits left of "a" but keeps its room.
        #expect(fit(entries, available: 200) == ["a", "b"])
    }

    @Test("Pinned items that need more than the room hide every other application")
    func pinnedExceedsRoom() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 20, position: 1600),
            Entry(bundleID: "pinned", width: 200, position: 1500, isPinned: true),
            Entry(bundleID: "b", width: 20, position: 1400),
        ]
        #expect(fit(entries, available: 250) == ["a", "b"])
    }

    @Test("A hidden application stays hidden until it fits with room to spare")
    func hysteresisKeeps() {
        let entries = [clock, Entry(bundleID: "a", width: 40, position: 1600), Entry(bundleID: "b", width: 40, position: 1500)]
        #expect(fit(entries, available: 185, previous: ["b"], slack: 10) == ["b"])
        #expect(fit(entries, available: 189, previous: ["b"], slack: 10) == ["b"])
        // Without having been hidden, the same application stays.
        #expect(fit(entries, available: 185, slack: 10).isEmpty)
    }

    @Test("A hidden application comes back once it fits with room to spare")
    func hysteresisReleases() {
        let entries = [clock, Entry(bundleID: "a", width: 40, position: 1600), Entry(bundleID: "b", width: 40, position: 1500)]
        #expect(fit(entries, available: 190, previous: ["b"], slack: 10).isEmpty)
    }

    @Test("Room kept for the slack is not taken from the applications further left")
    func slackIsNotConsumed() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 40, position: 1600),
            Entry(bundleID: "b", width: 40, position: 1500),
        ]
        #expect(fit(entries, available: 180, previous: ["a"], slack: 10).isEmpty)
    }

    @Test("Nothing is hidden without entries or without room")
    func degenerate() {
        #expect(fit([], available: 200).isEmpty)
        let entries = [clock, Entry(bundleID: "a", width: 40, position: 1600)]
        #expect(fit(entries, available: nil).isEmpty)
        #expect(fit(entries, available: 0).isEmpty)
        #expect(fit(entries, available: -20).isEmpty)
    }

    @Test("An application with one pinned item is pinned as a whole")
    func mixedPinned() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 40, position: 1600),
            Entry(bundleID: "multi", width: 40, position: 1550, isPinned: true),
            Entry(bundleID: "multi", width: 40, position: 1500),
        ]
        #expect(fit(entries, available: 200) == ["a"])
    }

    @Test("Hysteresis counts the gaps between items as well")
    func hysteresisWithSpacing() {
        let entries = [clock, Entry(bundleID: "a", width: 40, position: 1600), Entry(bundleID: "b", width: 40, position: 1500)]
        // 104 + 44 + 44 - 4 = 188 without slack.
        #expect(fit(entries, available: 188, spacing: 4).isEmpty)
        #expect(fit(entries, available: 197, spacing: 4, previous: ["b"], slack: 10) == ["b"])
        #expect(fit(entries, available: 198, spacing: 4, previous: ["b"], slack: 10).isEmpty)
    }

    @Test("An application's items are hidden together and their widths add up")
    func severalItems() {
        let entries = [
            clock,
            Entry(bundleID: "a", width: 30, position: 1600),
            Entry(bundleID: "multi", width: 30, position: 1560),
            Entry(bundleID: "multi", width: 30, position: 1520),
        ]
        #expect(fit(entries, available: 190).isEmpty)
        #expect(fit(entries, available: 189) == ["multi"])
        #expect(fit(entries, available: 192, spacing: 1) == ["multi"])
        #expect(fit(entries, available: 193, spacing: 1).isEmpty)
    }
}

@Suite("NotchFit27 layout")
struct NotchFit27LayoutTests {
    @Test("Hidden applications join Hidden, and the user's own sections win")
    func layout() {
        let saved: [String: MacOS27Section] = ["kept": .alwaysHidden, "manual": .hidden]
        let layout = NotchFit27.layout(saved: saved, autoHidden: ["kept", "auto", "pinned"], pinned: ["pinned"])
        #expect(layout == ["kept": .alwaysHidden, "manual": .hidden, "auto": .hidden])
    }

    @Test("Without applications to hide, the saved layout is used as it is")
    func noAutoHidden() {
        let saved: [String: MacOS27Section] = ["a": .hidden]
        #expect(NotchFit27.layout(saved: saved, autoHidden: [], pinned: ["b"]) == saved)
    }

    @Test("Moving an application to Visible pins it, and moving it anywhere else unpins it")
    func pinning() {
        let pinned = SectionLayout27.pinnedVisible(settingSection: .visible, for: "a", in: ["b"])
        #expect(pinned == ["a", "b"])
        #expect(SectionLayout27.pinnedVisible(settingSection: .hidden, for: "a", in: pinned) == ["b"])
        #expect(SectionLayout27.pinnedVisible(settingSection: .alwaysHidden, for: "b", in: pinned) == ["a"])
    }
}

@Suite("NotchWidthCache27")
struct NotchWidthCache27Tests {
    typealias Measurement = NotchWidthCache27.Measurement

    @Test("A new application is a change")
    func newApplication() {
        var cache = NotchWidthCache27()
        let changed = cache.record(["a": Measurement(widths: [30], position: 1500)], now: 0)
        #expect(changed)
        #expect(cache.measurement(for: "a")?.widths == [30])
    }

    @Test("Small width changes and moves are not a change, but the position is kept")
    func noise() {
        var cache = NotchWidthCache27()
        _ = cache.record(["a": Measurement(widths: [30, 20], position: 1500)], now: 0)
        let changed = cache.record(["a": Measurement(widths: [31, 20], position: 1540)], now: 1)
        #expect(!changed)
        #expect(cache.measurement(for: "a")?.position == 1540)
    }

    @Test("A wider application or another item is a change")
    func change() {
        var cache = NotchWidthCache27()
        _ = cache.record(["a": Measurement(widths: [30], position: 1500)], now: 0)
        let wider = cache.record(["a": Measurement(widths: [60], position: 1500)], now: 1)
        #expect(wider)
        let anotherItem = cache.record(["a": Measurement(widths: [30, 30], position: 1500)], now: 2)
        #expect(anotherItem)
    }

    @Test("An application that shrinks keeps its widest width until the window runs out")
    func peak() {
        var cache = NotchWidthCache27()
        _ = cache.record(["a": Measurement(widths: [60], position: 1500)], now: 0)
        let shrunk = cache.record(["a": Measurement(widths: [30], position: 1510)], now: 10)
        #expect(!shrunk)
        #expect(cache.measurement(for: "a") == Measurement(widths: [60], position: 1510))
        let expired = cache.record(["a": Measurement(widths: [30], position: 1510)], now: 10 + NotchWidthCache27.peakWindow + 1)
        #expect(expired)
        #expect(cache.measurement(for: "a")?.widths == [30])
    }

    @Test("Applications not measured this time keep their widths")
    func keepsUnmeasured() {
        var cache = NotchWidthCache27()
        _ = cache.record(["a": Measurement(widths: [30], position: 1500), "b": Measurement(widths: [40], position: 1400)], now: 0)
        let changed = cache.record(["a": Measurement(widths: [30], position: 1560)], now: 1)
        #expect(!changed)
        #expect(cache.measurement(for: "b")?.widths == [40])
    }
}
