import CoreGraphics
import Testing
@testable import GlacierMacOS27Core

@Suite("NotchFit27 planning")
struct NotchFitPlanning27Tests {
    typealias BarItem = NotchFit27.BarItem
    typealias Measurement = NotchWidthCache27.Measurement

    // A 14-inch built-in display with the notch at 790...1010. The clock ends at 1790, so with
    // an 8 point gap there are 772 points for the items.
    let display = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    let parameters = NotchFit27.Parameters(gap: 8, defaultSpacing: 0, slack: 10)

    var clock: BarItem {
        BarItem(bundleID: nil, key: "clock", frame: CGRect(x: 1690, y: 0, width: 100, height: 24), isOnScreen: true, isSystem: true)
    }

    func app(_ bundleID: String, x: CGFloat, width: CGFloat, drawn: Bool = true, concealed: Bool = false) -> BarItem {
        BarItem(bundleID: bundleID, key: bundleID, frame: CGRect(x: x, y: 0, width: width, height: 24), isOnScreen: drawn, isConcealed: concealed)
    }

    /// An item that cannot be hidden and leaves `room` points free for the applications.
    func filler(room: CGFloat) -> BarItem {
        BarItem(bundleID: nil, key: "filler", frame: CGRect(x: 1011, y: 0, width: 772 - 100 - room, height: 24), isOnScreen: true)
    }

    func bar(_ items: [BarItem], notch: ClosedRange<CGFloat>? = 790...1010) -> NotchFit27.Bar {
        NotchFit27.Bar(items: items, displayBounds: display, notch: notch)
    }

    func plan(
        _ bar: NotchFit27.Bar,
        saved: [String: MacOS27Section] = [:],
        pinned: Set<String> = [],
        running: Set<String> = [],
        previous: Set<String> = [],
        keepUnseen: Set<String> = [],
        widths: NotchWidthCache27 = NotchWidthCache27()
    ) -> NotchFit27.Plan? {
        NotchFit27.plan(
            bar: bar,
            saved: saved,
            pinned: pinned,
            running: running,
            previous: previous,
            keepUnseen: keepUnseen,
            widths: widths,
            parameters: parameters
        )
    }

    @Test("A read that does not show the notched bar gives no plan")
    func nilPaths() {
        let items = [clock, app("a", x: 1500, width: 30)]
        #expect(plan(bar(items, notch: nil)) == nil)
        #expect(plan(bar([])) == nil)
        // Nothing but concealed items, as when the bar is hidden.
        #expect(plan(bar([app("a", x: 1500, width: 30, concealed: true)])) == nil)
        // No system item drawn, as when the read came from another display.
        #expect(plan(bar([app("a", x: 1500, width: 30)])) == nil)
        #expect(plan(bar(items)) == NotchFit27.Plan(hidden: [], unseen: []))
    }

    @Test("Applications that do not fit are hidden")
    func overflow() {
        let items = [clock, filler(room: 40), app("a", x: 1500, width: 30), app("b", x: 1400, width: 30)]
        #expect(plan(bar(items))?.hidden == ["b"])
    }

    @Test("Applications the user put in Hidden or Always Hidden take no room and are not chosen")
    func savedSections() {
        let items = [
            clock,
            filler(room: 40),
            app("manual", x: 1550, width: 30, concealed: true),
            app("always", x: 1520, width: 30, concealed: true),
            app("a", x: 1500, width: 30),
        ]
        let result = plan(bar(items), saved: ["manual": .hidden, "always": .alwaysHidden], previous: ["manual"])
        #expect(result?.hidden == [])
    }

    @Test("Pinned applications keep their room")
    func pinned() {
        let items = [clock, filler(room: 40), app("a", x: 1500, width: 30), app("pinned", x: 1400, width: 30)]
        #expect(plan(bar(items), pinned: ["pinned"])?.hidden == ["a"])
    }

    @Test("A partly folded application is not measured")
    func partialMeasurement() {
        let items = [
            clock,
            app("whole", x: 1500, width: 30),
            app("partly", x: 1450, width: 30),
            app("partly", x: 1020, width: 30, drawn: false),
            app("hidden", x: 1400, width: 30, concealed: true),
        ]
        let measured = NotchFit27.measurements(of: bar(items))
        #expect(Set(measured.keys) == ["whole"])
        #expect(measured["whole"] == Measurement(widths: [30], position: 1500))
    }

    @Test("Items beyond the measured ones count at their reported width")
    func partialFit() {
        var widths = NotchWidthCache27()
        _ = widths.record(["a": Measurement(widths: [30], position: 1500)], now: 0)
        let items = [
            clock,
            filler(room: 50),
            app("a", x: 1500, width: 30),
            app("a", x: 1020, width: 30, drawn: false),
        ]
        #expect(plan(bar(items), widths: widths)?.hidden == ["a"])
        #expect(plan(bar(Array(items.prefix(3))), widths: widths)?.hidden == [])
    }

    @Test("A hidden application is judged by its measured width, not its stale frame")
    func concealedUsesCache() {
        var widths = NotchWidthCache27()
        _ = widths.record(["a": Measurement(widths: [60], position: 1500)], now: 0)
        let items = [clock, filler(room: 50), app("a", x: 1500, width: 2, concealed: true)]
        #expect(plan(bar(items), previous: ["a"], widths: widths)?.hidden == ["a"])
    }

    @Test("A hidden application that reports no items is judged by its measured width")
    func unreportedMeasured() {
        var widths = NotchWidthCache27()
        _ = widths.record(["gone": Measurement(widths: [30], position: 1500)], now: 0)
        let items = [clock, filler(room: 100)]
        let result = plan(bar(items), running: ["gone"], previous: ["gone"], widths: widths)
        #expect(result == NotchFit27.Plan(hidden: [], unseen: []))
    }

    @Test("A hidden application never measured stays hidden only while it may")
    func keptEntries() {
        let items = [clock, filler(room: 100)]
        let kept = plan(bar(items), running: ["gone"], previous: ["gone"], keepUnseen: ["gone"])
        #expect(kept == NotchFit27.Plan(hidden: ["gone"], unseen: ["gone"]))
        let released = plan(bar(items), running: ["gone"], previous: ["gone"], keepUnseen: [])
        #expect(released == NotchFit27.Plan(hidden: [], unseen: ["gone"]))
        // An application that quit is dropped at once.
        #expect(plan(bar(items), previous: ["gone"], keepUnseen: ["gone"]) == NotchFit27.Plan(hidden: [], unseen: []))
    }

    @Test("Items that cannot be hidden take room even when folded")
    func foldedFixed() {
        let recording = BarItem(bundleID: nil, key: "recording", frame: CGRect(x: 1020, y: 0, width: 30, height: 24), isOnScreen: false)
        let items = [clock, filler(room: 50), app("a", x: 1500, width: 30)]
        #expect(plan(bar(items))?.hidden == [])
        #expect(plan(bar(items + [recording]))?.hidden == ["a"])
    }

    @Test("The spacing comes from the drawn neighbours right of the notch")
    func spacing() {
        let frames = [
            CGRect(x: 1242, y: 0, width: 34, height: 24),
            CGRect(x: 1274, y: 0, width: 34, height: 24),
            CGRect(x: 1306, y: 0, width: 34, height: 24),
            CGRect(x: 500, y: 0, width: 34, height: 24),
        ]
        #expect(NotchFit27.spacing(drawnFrames: frames, rightOf: 1010) == -2)
        #expect(NotchFit27.spacing(drawnFrames: [frames[0]], rightOf: 1010) == nil)
    }

    @Test("Only applications the user did not place count as hidden to fit")
    func effective() {
        let result = NotchFit27.effective(["a", "b", "c"], saved: ["b": .hidden], pinned: ["c"])
        #expect(result == ["a"])
    }
}
