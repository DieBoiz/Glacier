//
//  GlacierBarColorManager.swift
//  Glacier
//

import Combine
import SwiftUI

final class GlacierBarColorManager: ObservableObject {
    @Published private(set) var colorInfo: MenuBarAverageColorInfo?

    private weak var glacierBarPanel: GlacierBarPanel?

    private var windowImage: CGImage?

    private var cancellables = Set<AnyCancellable>()

    func performSetup(with glacierBarPanel: GlacierBarPanel) {
        self.glacierBarPanel = glacierBarPanel
        configureCancellables()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        if let glacierBarPanel {
            glacierBarPanel.publisher(for: \.screen)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] screen in
                    guard
                        let self,
                        let screen,
                        screen == .main
                    else {
                        return
                    }
                    updateWindowImage(for: screen)
                }
                .store(in: &c)

            glacierBarPanel.publisher(for: \.isVisible)
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak glacierBarPanel] isVisible in
                    guard
                        let self,
                        let glacierBarPanel,
                        let screen = glacierBarPanel.screen,
                        isVisible,
                        screen == .main
                    else {
                        return
                    }
                    updateColorInfo(with: glacierBarPanel.frame, screen: screen)
                }
                .store(in: &c)

            glacierBarPanel.publisher(for: \.frame)
                .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self, weak glacierBarPanel] frame in
                    guard
                        let self,
                        let glacierBarPanel,
                        let screen = glacierBarPanel.screen,
                        glacierBarPanel.isVisible,
                        screen == .main
                    else {
                        return
                    }
                    withAnimation(.interactiveSpring) {
                        self.updateColorInfo(with: frame, screen: screen)
                    }
                }
                .store(in: &c)

            Publishers.Merge4(
                NSWorkspace.shared.notificationCenter
                    .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
                    .replace(with: ()),
                NotificationCenter.default
                    .publisher(for: NSApplication.didChangeScreenParametersNotification)
                    .replace(with: ()),
                DistributedNotificationCenter.default()
                    .publisher(for: DistributedNotificationCenter.interfaceThemeChangedNotification)
                    .replace(with: ()),
                // Only poll while the panel is visible. Showing the panel
                // updates the color anyway.
                glacierBarPanel.publisher(for: \.isVisible)
                    .removeDuplicates()
                    .map { isVisible in
                        if isVisible {
                            Timer.publish(every: 5, on: .main, in: .default)
                                .autoconnect()
                                .replace(with: ())
                                .eraseToAnyPublisher()
                        } else {
                            Empty<Void, Never>().eraseToAnyPublisher()
                        }
                    }
                    .switchToLatest()
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak glacierBarPanel] in
                guard
                    let self,
                    let glacierBarPanel,
                    glacierBarPanel.isVisible,
                    let screen = glacierBarPanel.screen,
                    screen == .main
                else {
                    return
                }
                if #available(macOS 27.0, *) {
                    // The color is flat on macOS 27, but follows the system appearance.
                    setColor27()
                    return
                }
                updateWindowImage(for: screen)
                withAnimation {
                    self.updateColorInfo(with: glacierBarPanel.frame, screen: screen)
                }
            }
            .store(in: &c)
        }

        cancellables = c
    }

    private func updateWindowImage(for screen: NSScreen) {
        if #available(macOS 27.0, *) {
            // The menu bar window cannot be captured on macOS 27, and the
            // color is flat there anyway (see ``setColor27()``).
            return
        }

        let windows = WindowInfo.createWindows(option: .onScreen)
        let displayID = screen.displayID

        guard
            let menuBarWindow = WindowInfo.menuBarWindow(from: windows, for: displayID),
            let wallpaperWindow = WindowInfo.wallpaperWindow(from: windows, for: displayID)
        else {
            return
        }

        guard let image = ScreenCapture.captureWindows(
            with: [menuBarWindow.windowID, wallpaperWindow.windowID],
            screenBounds: withMutableCopy(of: wallpaperWindow.bounds) { $0.size.height = 1 },
            option: .nominalResolution
        ) else {
            return
        }

        windowImage = image
    }

    private func updateColorInfo(with frame: CGRect, screen: NSScreen) {
        guard let image = windowImage else {
            return
        }

        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)

        let insetScreenFrame = screen.frame.insetBy(dx: frame.width / 2, dy: 0)
        let percentage = ((frame.midX - insetScreenFrame.minX) / insetScreenFrame.width).clamped(to: 0...1)

        let cropRect = CGRect(x: imageBounds.width * percentage, y: 0, width: 0, height: 1)
            .insetBy(dx: -150, dy: 0)
            .intersection(imageBounds)

        guard
            let croppedImage = image.cropping(to: cropRect),
            let averageColor = croppedImage.averageColor()
        else {
            return
        }

        // Just use `menuBarWindow` as the source for now, regardless
        // of whether its image contributed to the average.
        colorInfo = MenuBarAverageColorInfo(color: averageColor, source: .menuBarWindow)
    }

    func updateAllProperties(with frame: CGRect, screen: NSScreen) {
        updateWindowImage(for: screen)
        updateColorInfo(with: frame, screen: screen)
    }

    /// One flat colour for macOS 27, where the menu bar window cannot be captured.
    ///
    /// Item images are cut out of a capture of the bar, so a colour read off the bar
    /// would only match the moment of that capture: when a dark window later sits under
    /// the menu bar, or the Glacier Bar opens on the other display, the panel and the items
    /// disagree. A flat colour that follows the system appearance always agrees with the
    /// glyphs, which the capture takes in that same appearance.
    static func flatColor27() -> CGColor {
        var color = NSColor.windowBackgroundColor
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? color
        }
        return color.cgColor
    }

    /// Sets the flat macOS 27 colour.
    func setColor27() {
        colorInfo = MenuBarAverageColorInfo(color: Self.flatColor27(), source: .menuBarWindow)
    }
}
