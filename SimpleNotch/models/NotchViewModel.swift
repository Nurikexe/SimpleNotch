//
//  NotchViewModel.swift
//  SimpleNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

class NotchViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = NotchViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    let animationLibrary: NotchAnimations = .init()
    let animation: Animation?

    @Published var contentType: ContentType = .normal
    @Published private(set) var notchState: NotchState = .closed

    @Published var dragDetectorTargeting: Bool = false
    @Published var generalDropTargeting: Bool = false
    @Published var dropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false
    @Published var anyDropZoneTargeting: Bool = false
    var cancellables: Set<AnyCancellable> = []
    
    @Published var hideOnClosed: Bool = true

    @Published var edgeAutoOpenActive: Bool = false
    @Published var isHoveringCalendar: Bool = false

    @Published var screenUUID: String?

    /// The panel this view model is shown in; set by the AppDelegate.
    weak var hostWindow: NotchSkyLightWindow?
    /// True while the notch holds keyboard focus.
    @Published private(set) var keyboardSessionActive = false
    /// True when the notch was opened on purpose (shortcut, announcement click),
    /// so moving the pointer away must not close it. Cleared on close.
    @Published var pinnedOpen = false

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    
    
    deinit {
        destroy()
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        animation = animationLibrary.animation

        super.init()
        
        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        Publishers.CombineLatest3($dropZoneTargeting, $dragDetectorTargeting, $generalDropTargeting)
            .map { shelf, drag, general in
                shelf || drag || general
            }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
        
        setupDetectorObserver()
    }
    
    private func setupDetectorObserver() {
        // Publisher for the user’s fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.smooth) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    // MARK: Pointer watch
    // SwiftUI's hover-exit can be lost when the app's activation changes under
    // the pointer (e.g. opening Settings from the notch). While the notch is
    // open, also watch plain mouse moves and close once the pointer has been
    // clearly outside for a moment. Exists only while open: no idle cost.

    private var pointerMonitors: [Any] = []
    private var pointerOutsideSince: Date?
    private var pointerCloseTask: Task<Void, Never>?

    private func startPointerWatch() {
        guard pointerMonitors.isEmpty else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) {
            pointerMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            handler(event)
            return event
        }) {
            pointerMonitors.append(local)
        }
    }

    private func stopPointerWatch() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors.removeAll()
        pointerOutsideSince = nil
        pointerCloseTask?.cancel()
        pointerCloseTask = nil
    }

    private func pointerMoved() {
        guard notchState == .open else { return }
        if isMouseHovering(margin: 12) {
            pointerOutsideSince = nil
            pointerCloseTask?.cancel()
            return
        }
        guard pointerOutsideSince == nil else { return }
        pointerOutsideSince = .now
        pointerCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled, self.notchState == .open,
                  !self.isMouseHovering(margin: 12),
                  !self.pinnedOpen,
                  !SharingStateManager.shared.preventNotchClose,
                  NSEvent.pressedMouseButtons == 0
            else { return }
            withMotion(Motion.notchClose) { self.close() }
        }
    }

    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation, margin: CGFloat) -> Bool {
        guard let frame = getScreenFrame(screenUUID) else { return false }
        let rect = CGRect(
            x: frame.midX - notchSize.width / 2 - margin,
            y: frame.maxY - notchSize.height - margin,
            width: notchSize.width + margin * 2,
            height: notchSize.height + margin
        )
        return rect.contains(position) || position.y >= frame.maxY && abs(position.x - frame.midX) <= rect.width / 2
    }

    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation) -> Bool {
        let screenFrame = getScreenFrame(screenUUID)
        if let frame = screenFrame {
            
            let baseY = frame.maxY - notchSize.height
            let baseX = frame.midX - notchSize.width / 2
            
            return position.y >= baseY && position.x >= baseX && position.x <= baseX + notchSize.width
        }
        
        return false
    }

    func open() {
        self.notchSize = openNotchSize
        self.notchState = .open
        startPointerWatch()
        
        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    /// Lets the notch receive key events without activating SimpleNotch, so the
    /// app the user was in stays frontmost (and receives a later paste).
    func beginKeyboardSession() {
        guard let window = hostWindow else { return }
        window.acceptsKeyboard = true
        window.makeKey()
        keyboardSessionActive = true
    }

    func endKeyboardSession() {
        guard keyboardSessionActive || hostWindow?.isKeyWindow == true else { return }
        keyboardSessionActive = false
        guard let window = hostWindow else { return }
        let wasKey = window.isKeyWindow
        window.acceptsKeyboard = false
        if wasKey {
            window.resignKey()
            NSWorkspace.shared.frontmostApplication?.activate()
        }
    }

    func close() {
        // Do not close while a share picker or sharing service is active
        if SharingStateManager.shared.preventNotchClose {
            return
        }
        pinnedOpen = false
        stopPointerWatch()
        endKeyboardSession()
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false

        coordinator.currentView = coordinator.restingTab()
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}
