//
//  GlacierBar.swift
//  Glacier
//

import Combine
import OSLog
import SwiftUI

// MARK: - GlacierBarPanel

final class GlacierBarPanel: NSPanel {
    /// The shared app state.
    private weak var appState: AppState?

    /// Manager for the Glacier Bar's color.
    private let colorManager = GlacierBarColorManager()

    /// The currently displayed section.
    private(set) var currentSection: MenuBarSection.Name?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    private var showGeneration = 0

    /// Creates a new Glacier Bar panel.
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        self.title = "Glacier Bar"
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.allowsToolTipsWhenApplicationIsInactive = true
        self.isFloatingPanel = true
        self.animationBehavior = .none
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .mainMenu + 1
        self.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace]
    }

    /// Sets up the panel.
    func performSetup(with appState: AppState) {
        self.appState = appState
        configureCancellables()
        colorManager.performSetup(with: self)
    }

    /// Configures the internal observers.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        // Hide the panel when the active space or screen parameters change.
        Publishers.Merge(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification),
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        )
        .sink { [weak self] _ in
            self?.hide()
        }
        .store(in: &c)

        // Update the panel's origin whenever its size changes.
        publisher(for: \.frame).map(\.size)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, let screen else {
                    return
                }
                updateOrigin(for: screen)
            }
            .store(in: &c)

        if let controlItem = appState?.menuBarManager.controlItem(withName: .hidden) {
            // Use the hidden control item's frame to determine if the menu bar
            // is hidden. Hide the panel if so.
            controlItem.$frame
                .combineLatest(controlItem.$screen)
                .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] (frame, screen) in
                    guard let self else {
                        return
                    }

                    guard let frame, let screen else {
                        hide()
                        return
                    }

                    // Icon is not vertically visible. We can infer that the
                    // menu bar is hidden.
                    if frame.maxY > screen.frame.maxY {
                        hide()
                    }
                }
                .store(in: &c)
        }

        cancellables = c
    }

    /// Updates the panel's frame origin for display on the given screen.
    private func updateOrigin(for screen: NSScreen) {
        guard let appState else {
            return
        }

        func getOrigin(for glacierBarLocation: GlacierBarLocation) -> CGPoint {
            let menuBarHeight = screen.getMenuBarHeight() ?? 0
            let originY = ((screen.frame.maxY - 1) - menuBarHeight) - frame.height

            var originForRightOfScreen: CGPoint {
                CGPoint(x: screen.frame.maxX - frame.width, y: originY)
            }

            switch glacierBarLocation {
            case .dynamic:
                if appState.hidEventManager.isMouseInsideEmptyMenuBarSpace(appState: appState, screen: screen) {
                    return getOrigin(for: .mousePointer)
                }
                return getOrigin(for: .glacierIcon)
            case .mousePointer:
                guard let location = MouseHelpers.locationAppKit else {
                    return getOrigin(for: .glacierIcon)
                }

                let lowerBound = screen.frame.minX
                let upperBound = screen.frame.maxX - frame.width

                guard lowerBound <= upperBound else {
                    return originForRightOfScreen
                }

                return CGPoint(x: (location.x - frame.width / 2).clamped(to: lowerBound...upperBound), y: originY)
            case .glacierIcon:
                let lowerBound = screen.frame.minX
                let upperBound = screen.frame.maxX - frame.width

                guard
                    lowerBound <= upperBound,
                    let controlItem = appState.itemManager.itemCache.managedItems.first(matching: .visibleControlItem),
                    // Bridging API is more reliable than controlItem.frame in some
                    // cases (like if the item is offscreen).
                    let itemBounds = Bridging.getWindowBounds(for: controlItem.windowID)
                else {
                    return originForRightOfScreen
                }

                return CGPoint(x: (itemBounds.midX - frame.width / 2).clamped(to: lowerBound...upperBound), y: originY)
            }
        }

        setFrameOrigin(getOrigin(for: appState.settings.general.glacierBarLocation))
    }

    /// Shows the panel on the given screen, displaying the given
    /// menu bar section.
    func show(section: MenuBarSection.Name, on screen: NSScreen) async {
        let requestedAt = ContinuousClock.now
        guard let appState else {
            return
        }

        showGeneration += 1
        let generation = showGeneration

        // IMPORTANT: We must set the navigation state and current section
        // before updating the caches.
        appState.navigationState.isGlacierBarPresented = true
        currentSection = section

        if #available(macOS 27.0, *), !Defaults.bool(forKey: .macOS27GlacierBarWaitsForRefresh) {
            // Waiting for this refresh cannot help the bar that is about to open on macOS 27:
            // the hidden items are concealed, so they can be neither read nor photographed,
            // and the bar shows the images stored while they were drawn. The wait only held
            // the bar back by a scan of every process and a capture of the display. The
            // refresh runs alongside instead, for the visible items and any still missing.
            // The `MacOS27GlacierBarWaitsForRefresh` default brings the wait back, for measuring.
            Task {
                await appState.itemManager.cacheItemsIfNeeded()
                await appState.imageCache.updateCache()
            }
        } else {
            let cacheTask = Task(timeout: .seconds(1)) {
                await appState.itemManager.cacheItemsIfNeeded()
                await appState.imageCache.updateCache()
            }

            do {
                try await cacheTask.value
            } catch {
                Logger.default.error("Cache update failed when showing GlacierBarPanel - \(error)")
            }

            guard generation == showGeneration else {
                return
            }
        }

        contentView = GlacierBarHostingView(
            appState: appState,
            colorManager: colorManager,
            screen: screen,
            section: section
        )

        updateOrigin(for: screen)

        // Color manager must be updated after updating the panel's origin,
        // but before it is shown.
        //
        // Color manager handles frame changes automatically, but does so on
        // the main queue, so we need to update manually once before showing
        // the panel to prevent the color from flashing.
        colorManager.updateAllProperties(with: frame, screen: screen)
        if #available(macOS 27.0, *) {
            colorManager.setColor27()
        }

        orderFrontRegardless()
        if #available(macOS 27.0, *) {
            let elapsed = (ContinuousClock.now - requestedAt).components
            let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
            Logger.default.debug("Glacier Bar shown \(milliseconds, privacy: .public) ms after it was requested")
        }
    }

    /// Hides the panel.
    func hide() {
        if
            let name = currentSection,
            let section = appState?.menuBarManager.section(withName: name)
        {
            section.hide()
        }
        close()
    }

    override func close() {
        showGeneration += 1
        super.close()
        contentView = nil
        currentSection = nil
        appState?.navigationState.isGlacierBarPresented = false
    }
}

// MARK: - GlacierBarHostingView

private final class GlacierBarHostingView: NSHostingView<GlacierBarContentView> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }

    init(
        appState: AppState,
        colorManager: GlacierBarColorManager,
        screen: NSScreen,
        section: MenuBarSection.Name
    ) {
        let rootView = GlacierBarContentView(
            appState: appState,
            appearanceManager: appState.appearanceManager,
            colorManager: colorManager,
            itemManager: appState.itemManager,
            imageCache: appState.imageCache,
            menuBarManager: appState.menuBarManager,
            screen: screen,
            section: section
        )
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(*, unavailable)
    required init(rootView: GlacierBarContentView) {
        fatalError("init(rootView:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - GlacierBarContentView

private struct GlacierBarContentView: View {
    // Not observed, as the app state forwards changes from all of its
    // submodels. The ones this view depends on are observed directly.
    let appState: AppState
    @ObservedObject var appearanceManager: MenuBarAppearanceManager
    @ObservedObject var colorManager: GlacierBarColorManager
    @ObservedObject var itemManager: MenuBarItemManager
    @ObservedObject var imageCache: MenuBarItemImageCache
    @ObservedObject var menuBarManager: MenuBarManager
    @State private var frame = CGRect.zero
    @State private var scrollIndicatorsFlashTrigger = 0

    let screen: NSScreen
    let section: MenuBarSection.Name

    private var items: [MenuBarItem] {
        itemManager.itemCache.managedItems(for: section)
    }

    private var configuration: MenuBarAppearanceConfigurationV2 {
        appearanceManager.configuration
    }

    private var horizontalPadding: CGFloat {
        if #available(macOS 26.0, *) {
            return 3
        }
        return configuration.hasRoundedShape ? 7 : 5
    }

    private var verticalPadding: CGFloat {
        if #available(macOS 26.0, *) {
            return screen.hasNotch && configuration.hasRoundedShape ? 2 : 0
        }
        return screen.hasNotch ? 0 : 2
    }

    private var contentHeight: CGFloat? {
        guard let menuBarHeight = screen.getMenuBarHeight() else {
            return nil
        }
        if configuration.shapeKind != .noShape && configuration.isInset && screen.hasNotch {
            return menuBarHeight - appearanceManager.menuBarInsetAmount * 2
        }
        return menuBarHeight
    }

    private var clipShape: some InsettableShape {
        if configuration.hasRoundedShape {
            RoundedRectangle(cornerRadius: frame.height / 2, style: .circular)
        } else if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: frame.height / 4, style: .continuous)
        } else {
            RoundedRectangle(cornerRadius: frame.height / 5, style: .continuous)
        }
    }

    private var shadowOpacity: CGFloat {
        configuration.current.hasShadow ? 0.5 : 0.33
    }

    var body: some View {
        ZStack {
            content
                .frame(height: contentHeight)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .menuBarItemContainer(appState: appState, colorInfo: colorManager.colorInfo)
                .foregroundStyle(colorManager.colorInfo?.color.brightness ?? 0 > 0.67 ? .black : .white)
                .clipShape(clipShape)
                .shadow(color: .black.opacity(shadowOpacity), radius: 2.5)

            if configuration.current.hasBorder {
                clipShape
                    .inset(by: configuration.current.borderWidth / 2)
                    .stroke(lineWidth: configuration.current.borderWidth)
                    .foregroundStyle(Color(cgColor: configuration.current.borderColor))
            }
        }
        .padding(5)
        .frame(maxWidth: screen.frame.width)
        .fixedSize()
        .onFrameChange(update: $frame)
    }

    @ViewBuilder
    private var content: some View {
        if menuBarManager.isMenuBarHiddenBySystemUserDefaults {
            Text("Glacier cannot display menu bar items for automatically hidden menu bars")
                .padding(.horizontal, 10)
        } else if itemManager.itemCache.managedItems.isEmpty {
            HStack {
                Text("Loading menu bar items…")
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.horizontal, 10)
        } else if imageCache.cacheFailed(for: section) {
            Text("Unable to display menu bar items")
                .padding(.horizontal, 10)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(items, id: \.windowID) { item in
                        GlacierBarItemView(
                            image: imageCache.images[item.tag],
                            itemManager: itemManager,
                            menuBarManager: menuBarManager,
                            item: item,
                            section: section
                        )
                    }
                }
            }
            .environment(\.isScrollEnabled, frame.width == screen.frame.width)
            .defaultScrollAnchor(.trailing)
            .scrollIndicatorsFlash(trigger: scrollIndicatorsFlashTrigger)
            .task {
                scrollIndicatorsFlashTrigger += 1
            }
        }
    }
}

// MARK: - GlacierBarItemView

private struct GlacierBarItemView: View {
    // The managers are only used by the click actions, so they aren't
    // observed. The content view passes in the image.
    let image: MenuBarItemImageCache.CapturedImage?
    let itemManager: MenuBarItemManager
    let menuBarManager: MenuBarManager

    let item: MenuBarItem
    let section: MenuBarSection.Name

    private func clickAction(for mouseButton: CGMouseButton) -> () -> Void {
        return { [weak itemManager, weak menuBarManager] in
            guard let itemManager, let menuBarManager else {
                return
            }
            let glacierBarDisplayID = menuBarManager.glacierBarPanel.screen?.displayID
            menuBarManager.section(withName: section)?.hide()
            Task {
                try? await Task.sleep(for: .milliseconds(25))
                if #available(macOS 27.0, *), let appState = itemManager.appState {
                    await ItemClicker27.click(item: item, mouseButton: mouseButton, glacierBarDisplayID: glacierBarDisplayID, appState: appState)
                    return
                }
                if Bridging.isWindowOnScreen(item.windowID) {
                    try await itemManager.click(item: item, with: mouseButton)
                } else {
                    await itemManager.temporarilyShow(item: item, clickingWith: mouseButton)
                }
            }
        }
    }

    private var leftClickAction: () -> Void {
        clickAction(for: .left)
    }

    private var rightClickAction: () -> Void {
        clickAction(for: .right)
    }

    /// The item's image, or its app icon and name when the image is not available, for
    /// example without the Screen Recording permission.
    @ViewBuilder
    private var itemContent: some View {
        if let image {
            Image(nsImage: image.nsImage)
        } else {
            VStack(spacing: 1) {
                if let icon = item.sourceApplication?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Text(item.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 56)
            .padding(.horizontal, 2)
        }
    }

    var body: some View {
        itemContent
            .contentShape(Rectangle())
            .overlay {
                GlacierBarItemClickView(
                    item: item,
                    leftClickAction: leftClickAction,
                    rightClickAction: rightClickAction
                )
            }
            .accessibilityLabel(item.displayName)
            .accessibilityAction(named: "left click", leftClickAction)
            .accessibilityAction(named: "right click", rightClickAction)
    }
}

// MARK: - GlacierBarItemClickView

private struct GlacierBarItemClickView: NSViewRepresentable {
    private final class Represented: NSView {
        let item: MenuBarItem

        let leftClickAction: () -> Void
        let rightClickAction: () -> Void

        private var lastLeftMouseDownDate = Date.now
        private var lastRightMouseDownDate = Date.now

        private var lastLeftMouseDownLocation = CGPoint.zero
        private var lastRightMouseDownLocation = CGPoint.zero

        init(
            item: MenuBarItem,
            leftClickAction: @escaping () -> Void,
            rightClickAction: @escaping () -> Void
        ) {
            self.item = item
            self.leftClickAction = leftClickAction
            self.rightClickAction = rightClickAction
            super.init(frame: .zero)
            self.toolTip = item.displayName
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            lastLeftMouseDownDate = .now
            lastLeftMouseDownLocation = NSEvent.mouseLocation
        }

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
            lastRightMouseDownDate = .now
            lastRightMouseDownLocation = NSEvent.mouseLocation
        }

        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            guard
                Date.now.timeIntervalSince(lastLeftMouseDownDate) < 0.5,
                lastLeftMouseDownLocation.distance(to: NSEvent.mouseLocation) < 5
            else {
                return
            }
            leftClickAction()
        }

        override func rightMouseUp(with event: NSEvent) {
            super.rightMouseUp(with: event)
            guard
                Date.now.timeIntervalSince(lastRightMouseDownDate) < 0.5,
                lastRightMouseDownLocation.distance(to: NSEvent.mouseLocation) < 5
            else {
                return
            }
            rightClickAction()
        }
    }

    let item: MenuBarItem

    let leftClickAction: () -> Void
    let rightClickAction: () -> Void

    func makeNSView(context: Context) -> NSView {
        Represented(
            item: item,
            leftClickAction: leftClickAction,
            rightClickAction: rightClickAction
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}
