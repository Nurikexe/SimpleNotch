//
//  NotchRouter.swift
//  SimpleNotch
//
//  Lets features open the notch on a given screen, on a given Tab, without
//  knowing how the AppDelegate manages one or many notch windows.
//

import AppKit
import SwiftUI

@MainActor
final class NotchRouter {
    static let shared = NotchRouter()

    /// Supplied by the AppDelegate: the view model showing the notch on a screen.
    var viewModelForScreen: ((NSScreen) -> BoringViewModel?)?

    private init() {}

    /// The screen the pointer is on, falling back to the main screen.
    func screenUnderPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }

    func viewModel(on screen: NSScreen? = nil) -> BoringViewModel? {
        guard let screen = screen ?? screenUnderPointer() else { return nil }
        return viewModelForScreen?(screen)
    }

    /// Opens the notch on `tab`. `pinned` keeps it open when the pointer is
    /// elsewhere (used by keyboard shortcuts); `keyboard` gives it key focus.
    @discardableResult
    func open(_ tab: NotchViews?, on screen: NSScreen? = nil, pinned: Bool = false, keyboard: Bool = false) -> BoringViewModel? {
        guard let vm = viewModel(on: screen) else { return nil }
        if let tab { BoringViewCoordinator.shared.currentView = tab }
        vm.pinnedOpen = pinned
        withMotion(Motion.notchOpen) {
            vm.open()
        }
        if keyboard { vm.beginKeyboardSession() }
        return vm
    }

    func close(on screen: NSScreen? = nil) {
        guard let vm = viewModel(on: screen) else { return }
        withMotion(Motion.notchClose) {
            vm.close()
        }
    }

    /// Opens `tab` if the notch is closed or showing another Tab; closes it if
    /// it is already open on `tab`.
    func toggle(_ tab: NotchViews, keyboard: Bool = false) {
        guard let vm = viewModel() else { return }
        if vm.notchState == .open && BoringViewCoordinator.shared.currentView == tab {
            close()
        } else {
            open(tab, pinned: true, keyboard: keyboard)
        }
    }
}
