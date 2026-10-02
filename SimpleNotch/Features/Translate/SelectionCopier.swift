//
//  SelectionCopier.swift
//  SimpleNotch
//
//  Reads the selection of the frontmost app by sending it ⌘C, then puts the
//  user's pasteboard back. Needs Accessibility (docs/adr/0003).
//

import AppKit
import CoreGraphics

enum SelectionCopier {
    /// Posts a synthetic ⌘C to the frontmost app.
    static func postCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        // Explicit flags, so the ⌃⌥ still held from the shortcut don't leak in.
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// A copy of everything on a pasteboard, so it can be put back.
struct PasteboardSnapshot {
    /// The nspasteboard.org marker that tells clipboard managers (including
    /// our own Clipboard history) to ignore a write.
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    init(of pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }
    }

    /// Writes the saved contents back, marked transient so the restore never
    /// becomes a new Clip.
    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let objects: [NSPasteboardItem] = items.compactMap { entries in
            guard !entries.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        guard let first = objects.first else { return }
        first.setData(Data(), forType: Self.transientType)
        pasteboard.writeObjects(objects)
    }
}
