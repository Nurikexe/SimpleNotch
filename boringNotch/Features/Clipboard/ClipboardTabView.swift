//
//  ClipboardTabView.swift
//  SimpleNotch
//
//  The Clipboard Tab: search on top, Pinned clips first, then the history.
//  Click or Return pastes into the previous app; ⌥ copies only.
//

import AppKit
import SwiftUI

struct ClipboardTabView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var manager = ClipboardManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var selection: Clip.ID?
    /// Set only by ↑/↓, so hovering never scrolls the list under the pointer.
    @State private var scrollRequest: Clip.ID?
    @State private var hint: Hint?
    @State private var hintTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool
    /// False while the Tab itself animates in. Rows built then would run their
    /// own pop-in on top of the Tab's transition and visibly jiggle sideways.
    @State private var listSettled = false
    @Namespace private var selectionNamespace

    private enum Hint: Equatable {
        case copied
        case needsAccessibility
    }

    private var filteredPinned: [Clip] { manager.pinnedClips.filter(matches) }
    private var filteredRecent: [Clip] { manager.recentClips.filter(matches) }
    /// Every visible Clip in on-screen order, for ↑/↓.
    private var visible: [Clip] { filteredPinned + filteredRecent }

    private func matches(_ clip: Clip) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || clip.searchableText.localizedCaseInsensitiveContains(trimmed)
    }

    private var rowTransition: AnyTransition { reduceMotion ? .opacity : .softPop }
    private var listRowTransition: AnyTransition { listSettled ? rowTransition : .identity }

    var body: some View {
        VStack(spacing: 6) {
            searchField
            ZStack(alignment: .bottom) {
                list
                if let hint {
                    hintView(hint)
                        .padding(.bottom, 4)
                        .transition(rowTransition)
                }
            }
            .animation(Motion.respecting(Motion.snappy), value: hint)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            selection = visible.first?.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                listSettled = true
            }
            if vm.keyboardSessionActive { searchFocused = true }
        }
        .onChange(of: vm.keyboardSessionActive) { _, active in
            searchFocused = active
        }
        .onChange(of: query) { _, _ in
            withMotion(Motion.snappy) { selection = visible.first?.id }
        }
        .onDisappear { hintTask?.cancel() }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search clipboard", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.return, phases: .down) { press in
                    pickSelection(copyOnly: press.modifiers.contains(.option))
                    return .handled
                }
                .onKeyPress(.escape) { close(); return .handled }
                .onExitCommand { close() }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(rowTransition)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture {
            // Typing needs key focus, which only a keyboard session gives the notch.
            if !vm.keyboardSessionActive { vm.beginKeyboardSession() }
            searchFocused = true
        }
        .animation(Motion.respecting(Motion.snappy), value: query.isEmpty)
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        if visible.isEmpty {
            emptyState
                .transition(.opacity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if !filteredPinned.isEmpty {
                            sectionHeader("Pinned", symbol: "pin.fill")
                            ForEach(filteredPinned) { row(for: $0) }
                            if !filteredRecent.isEmpty {
                                sectionHeader("Recent", symbol: "clock")
                            }
                        }
                        ForEach(filteredRecent) { row(for: $0) }
                    }
                    .padding(.bottom, hint == nil ? 0 : 30)
                    .animation(Motion.respecting(Motion.snappy), value: manager.clips)
                }
                // Rows lay out once, in place, while the Tab transitions in.
                .transaction { if !listSettled { $0.animation = nil } }
                .onChange(of: scrollRequest) { _, id in
                    guard let id else { return }
                    withMotion(Motion.smooth) { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func row(for clip: Clip) -> some View {
        ClipRow(
            clip: clip,
            isSelected: selection == clip.id,
            selectionNamespace: selectionNamespace,
            onHover: { hovering in
                guard hovering, selection != clip.id else { return }
                withMotion(Motion.snappy) { selection = clip.id }
            },
            onPick: { copyOnly in pick(clip, copyOnly: copyOnly) },
            onTogglePin: { manager.togglePin(clip) },
            onDelete: { manager.delete(clip) }
        )
        .id(clip.id)
        .transition(listRowTransition)
    }

    private func sectionHeader(_ title: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.leading, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .transition(listRowTransition)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 20, weight: .light))
                .contentTransition(.symbolEffect(.replace))
            Text(query.isEmpty ? "Nothing copied yet" : "No matching clips")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hint

    private func hintView(_ hint: Hint) -> some View {
        HStack(spacing: 8) {
            switch hint {
            case .copied:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: hint)
                Text("Copied")
            case .needsAccessibility:
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Copied. Allow Accessibility to paste automatically.")
                    .lineLimit(1)
                Button("Grant access") {
                    AccessibilityPermission.shared.requestAccessibilityAuthorization()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.16)))
                Button {
                    withMotion(Motion.snappy) { self.hint = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(white: 0.16)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
    }

    private func showHint(_ newHint: Hint) {
        hintTask?.cancel()
        withMotion(Motion.snappy) { hint = newHint }
        guard newHint == .copied else { return }
        hintTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withMotion(Motion.snappy) { hint = nil }
        }
    }

    // MARK: - Actions

    private func moveSelection(_ delta: Int) {
        let ids = visible.map(\.id)
        guard !ids.isEmpty else { return }
        let current = selection.flatMap { ids.firstIndex(of: $0) } ?? (delta > 0 ? -1 : ids.count)
        let next = min(max(current + delta, 0), ids.count - 1)
        withMotion(Motion.snappy) { selection = ids[next] }
        scrollRequest = ids[next]
    }

    private func pickSelection(copyOnly: Bool) {
        guard let clip = visible.first(where: { $0.id == selection }) ?? visible.first else { return }
        pick(clip, copyOnly: copyOnly)
    }

    /// Writes the Clip to the pasteboard, then (unless `copyOnly`) closes the
    /// notch and pastes it into the app the user was in.
    private func pick(_ clip: Clip, copyOnly: Bool) {
        guard manager.copyToPasteboard(clip) else { return }
        withMotion(Motion.snappy) { selection = clip.id }
        if copyOnly {
            showHint(.copied)
            return
        }
        guard AccessibilityPermission.shared.isTrusted else {
            showHint(.needsAccessibility)
            return
        }
        close()
        Task { @MainActor in
            // Let the previous app take key focus back before it receives ⌘V.
            try? await Task.sleep(for: .milliseconds(120))
            ClipboardManager.shared.postPaste()
        }
    }

    private func close() {
        withMotion(Motion.notchClose) { vm.close() }
    }
}

// MARK: - Row

private struct ClipRow: View {
    let clip: Clip
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let onHover: (Bool) -> Void
    let onPick: (_ copyOnly: Bool) -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var manager = ClipboardManager.shared
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            leading
                .frame(width: 22, height: 22)
            preview
                .frame(maxWidth: .infinity, alignment: .leading)
            if let icon = manager.appIcon(for: clip.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .opacity(0.85)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(Self.relativeTime(clip.date, now: context.date))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 26, alignment: .trailing)
            pinButton
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .matchedGeometryEffect(id: "clipSelection", in: selectionNamespace)
            }
        }
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .onTapGesture {
            onPick(NSEvent.modifierFlags.contains(.option))
        }
        .contextMenu {
            Button(clip.pinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Copy") { onPick(true) }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .task(id: clip.id) {
            guard clip.kind == .image else { return }
            thumbnail = manager.cachedThumbnail(for: clip)
            if thumbnail == nil {
                let image = await manager.thumbnail(for: clip)
                withMotion(Motion.smooth) { thumbnail = image }
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch clip.kind {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .transition(.opacity)
            } else {
                typeIcon
            }
        case .file:
            if let icon = manager.fileIcon(for: clip) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                typeIcon
            }
        case .text, .link:
            typeIcon
        }
    }

    private var typeIcon: some View {
        Image(systemName: clip.symbolName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder
    private var preview: some View {
        switch clip.kind {
        case .text:
            Text(Self.singleLine(clip.text ?? ""))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.white)
        case .link:
            Text(clip.text ?? "")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1))
        case .image:
            if let size = clip.imagePixelSize {
                Text("Image  \(Int(size.width))×\(Int(size.height))")
                    .foregroundStyle(.white)
            } else {
                Text("Image")
                    .foregroundStyle(.white)
            }
        case .file:
            let names = clip.fileURLs.map(\.lastPathComponent)
            HStack(spacing: 4) {
                Text(names.first ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white)
                if names.count > 1 {
                    Text("+\(names.count - 1)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: clip.pinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(clip.pinned ? Color.white : Color.secondary)
                .rotationEffect(.degrees(clip.pinned ? 0 : 45))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(clip.pinned || isSelected ? 1 : 0.35)
        .help(clip.pinned ? "Unpin" : "Pin")
    }

    private static func singleLine(_ text: String) -> String {
        let prefix = text.prefix(300)
        return prefix
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ⏎ ")
    }

    private static func relativeTime(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return String(localized: "now") }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return String(localized: "\(minutes)m") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "\(hours)h") }
        return String(localized: "\(hours / 24)d")
    }
}
