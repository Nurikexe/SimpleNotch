//
//  BirthdaysTabView.swift
//  SimpleNotch
//
//  The Birthdays Tab: a compact list sorted by Countdown, with an inline card
//  for adding and editing a Birthday that slides over the list.
//

import AppKit
import SwiftUI

private enum BirthdayStyle {
    /// Warm accent for Birthdays within the next week.
    static let warm = Color(red: 1.0, green: 0.62, blue: 0.32)
    static let soonWindow = 7
}

struct BirthdaysTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var store = BirthdayStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The Birthday being edited; nil while the form is closed.
    @State private var draft: Birthday?
    @State private var isNew = false

    private var list: [Birthday] { store.sorted }

    private var hasBirthdayToday: Bool {
        list.first.map { $0.countdown(from: store.today) == 0 } ?? false
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                header
                if list.isEmpty {
                    emptyState
                        .transition(.notchContent)
                } else {
                    rows
                }
            }
            .blur(radius: draft == nil ? 0 : 6)
            .opacity(draft == nil ? 1 : 0.35)
            .allowsHitTesting(draft == nil)

            if let draft {
                BirthdayFormCard(
                    draft: draft,
                    isNew: isNew,
                    onSave: save,
                    onCancel: closeForm
                )
                .id(draft.id)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .notchContent.combined(with: .offset(y: 24))
                )
                .zIndex(1)
            }
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            // Celebrate each time the Tab appears on someone's Birthday.
            if hasBirthdayToday {
                ConfettiBurst(count: 40)
                    .frame(height: 140)
                    .allowsHitTesting(false)
            }
        }
        .onDisappear {
            if draft != nil { endTyping() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("Birthdays")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            if !list.isEmpty {
                Text("\(list.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
                    .animation(Motion.respecting(Motion.snappy), value: list.count)
            }
            Spacer()
            Button(action: openNew) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .help("Add a birthday")
        }
    }

    // MARK: List

    private var rows: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(list) { birthday in
                    BirthdayRow(birthday: birthday, today: store.today)
                        .contextMenu {
                            Button("Edit") { openEdit(birthday) }
                            Button("Delete", role: .destructive) {
                                withMotion(Motion.snappy) { store.delete(birthday) }
                            }
                        }
                        .onTapGesture(count: 2) { openEdit(birthday) }
                        .transition(.softPop)
                }
            }
            .animation(Motion.respecting(Motion.snappy), value: list.map(\.id))
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🎈")
                .font(.system(size: 26))
            Text("No birthdays yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("Add the people you never want to forget.")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            Button(action: openNew) {
                Label("Add birthday", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(BirthdayStyle.warm.opacity(0.22)))
                    .foregroundStyle(BirthdayStyle.warm)
            }
            .buttonStyle(PressScaleStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Form

    private func openNew() {
        let now = Calendar.current.dateComponents([.day, .month], from: Date())
        isNew = true
        beginTyping()
        withMotion(Motion.notchOpen) {
            draft = Birthday(name: "", day: now.day ?? 1, month: now.month ?? 1)
        }
    }

    private func openEdit(_ birthday: Birthday) {
        isNew = false
        beginTyping()
        withMotion(Motion.notchOpen) { draft = birthday }
    }

    private func save(_ birthday: Birthday) {
        withMotion(Motion.snappy) { store.save(birthday) }
        closeForm()
    }

    private func closeForm() {
        endTyping()
        withMotion(Motion.notchClose) { draft = nil }
    }

    private func beginTyping() {
        vm.pinnedOpen = true
        vm.beginKeyboardSession()
    }

    private func endTyping() {
        vm.endKeyboardSession()
        vm.pinnedOpen = false
    }
}

// MARK: - Row

private struct BirthdayRow: View {
    let birthday: Birthday
    let today: Date

    @State private var hovering = false

    private var countdown: Int { birthday.countdown(from: today) }
    private var age: Int? { birthday.ageTurning(from: today) }
    private var isToday: Bool { countdown == 0 }
    private var isSoon: Bool { countdown <= BirthdayStyle.soonWindow }

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(birthday.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isToday {
                        Text("🎉")
                            .font(.system(size: 12))
                            .transition(.softPop)
                    }
                }
                HStack(spacing: 4) {
                    Text(birthday.shortDate)
                    if let age {
                        Text("·")
                        Text("turns \(age)")
                            .contentTransition(.numericText(value: Double(age)))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            }
            Spacer(minLength: 8)
            countdownLabel
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isToday ? 7 : 5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isToday ? BirthdayStyle.warm.opacity(0.55) : .clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering = $0 }
        .animation(Motion.respecting(Motion.snappy), value: hovering)
        .animation(Motion.respecting(Motion.smooth), value: countdown)
    }

    private var background: Color {
        if isToday { return BirthdayStyle.warm.opacity(hovering ? 0.26 : 0.2) }
        if isSoon { return BirthdayStyle.warm.opacity(hovering ? 0.15 : 0.1) }
        return Color.white.opacity(hovering ? 0.1 : 0.06)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(isSoon ? BirthdayStyle.warm.opacity(0.25) : Color.white.opacity(0.1))
            if let emoji = birthday.emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: 15))
            } else {
                Text(birthday.initial)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSoon ? BirthdayStyle.warm : .white)
            }
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var countdownLabel: some View {
        Group {
            switch countdown {
            case 0:
                Text("Today!")
                    .font(.system(size: 12, weight: .bold))
            case 1:
                Text("tomorrow")
                    .font(.system(size: 11, weight: .semibold))
            default:
                Text("in \(countdown) days")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .foregroundStyle(isSoon ? BirthdayStyle.warm : Color.gray)
    }
}

// MARK: - Form card

private struct BirthdayFormCard: View {
    @State var draft: Birthday
    let isNew: Bool
    let onSave: (Birthday) -> Void
    let onCancel: () -> Void

    @State private var hasYear: Bool
    @State private var yearValue: Int
    @State private var emojiText: String
    @State private var submitted = false
    @FocusState private var focus: Field?

    private enum Field { case name, emoji, year }

    private static let currentYear = Calendar.current.component(.year, from: Date())

    init(draft: Birthday, isNew: Bool, onSave: @escaping (Birthday) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _hasYear = State(initialValue: draft.year != nil)
        _yearValue = State(initialValue: draft.year ?? (Self.currentYear - 30))
        _emojiText = State(initialValue: draft.emoji ?? "")
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("🙂", text: $emojiText)
                    .focused($focus, equals: .emoji)
                    .multilineTextAlignment(.center)
                    .frame(width: 34)
                    .fieldStyle()
                    .onChange(of: emojiText) { _, newValue in
                        // Keep a single character (one grapheme, so flags and skin tones survive).
                        if newValue.count > 1 { emojiText = String(newValue.suffix(1)) }
                    }
                    .help("Emoji (optional)")
                TextField("Name", text: $draft.name)
                    .focused($focus, equals: .name)
                    .fieldStyle()
                    .onSubmit(submit)
            }

            HStack(spacing: 8) {
                CycleStepper(
                    value: $draft.day,
                    range: 1...Birthday.maxDays(inMonth: draft.month),
                    label: { "\($0)" },
                    width: 26,
                    help: "Day"
                )
                CycleStepper(
                    value: $draft.month,
                    range: 1...12,
                    label: { Calendar.current.monthSymbols[$0 - 1] },
                    width: 72,
                    help: "Month"
                )
                .onChange(of: draft.month) { _, month in
                    draft.day = min(draft.day, Birthday.maxDays(inMonth: month))
                }

                Toggle("Year", isOn: $hasYear.animation(Motion.respecting(Motion.snappy)))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)

                if hasYear {
                    TextField("Year", value: $yearValue, format: .number.grouping(.never))
                        .focused($focus, equals: .year)
                        .frame(width: 52)
                        .fieldStyle()
                        .onSubmit(submit)
                        .transition(.softPop)
                }
                Spacer(minLength: 0)
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(FormButtonStyle(prominent: false))
                Button(isNew ? "Add" : "Save", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(FormButtonStyle(prominent: true))
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .animation(Motion.respecting(Motion.snappy), value: canSave)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.11))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            Task { @MainActor in focus = .name }
        }
    }

    private func submit() {
        // Return can reach both the field's onSubmit and the default button.
        guard canSave, !submitted else { return }
        submitted = true
        var result = draft
        result.name = trimmedName
        let emoji = emojiText.trimmingCharacters(in: .whitespacesAndNewlines)
        result.emoji = emoji.isEmpty ? nil : emoji
        if hasYear, (1900...Self.currentYear).contains(yearValue) {
            result.year = yearValue
        } else {
            result.year = nil
        }
        result.day = min(result.day, Birthday.maxDays(inMonth: result.month))
        onSave(result)
    }
}

// MARK: - Styles

private extension View {
    func fieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

private struct FormButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(prominent ? BirthdayStyle.warm : Color.white.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Motion.respecting(Motion.snappy), value: configuration.isPressed)
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.respecting(Motion.snappy), value: configuration.isPressed)
    }
}

/// "‹ 2 ›": a compact in-notch stepper that wraps around. Click the chevrons
/// or scroll over it; long menus don't fit the notch.
private struct CycleStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: (Int) -> String
    let width: CGFloat
    let help: LocalizedStringKey

    @State private var scrollMonitor: Any?
    @State private var accumulated: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            chevron("chevron.left") { step(-1) }
            Text(label(value))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.numericText())
                .frame(minWidth: width)
            chevron("chevron.right") { step(1) }
        }
        .padding(.horizontal, 3)
        .frame(height: 24)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .help(help)
        .onHover { $0 ? installScroll() : removeScroll() }
        .onDisappear(perform: removeScroll)
    }

    private func chevron(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.gray)
                .frame(width: 16, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private func step(_ delta: Int) {
        let count = range.count
        let next = ((value - range.lowerBound + delta) % count + count) % count + range.lowerBound
        withMotion(Motion.snappy) { value = next }
    }

    private func installScroll() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            accumulated += event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
            while abs(accumulated) >= 10 {
                // Scrolling up moves forward, like turning a dial.
                step(accumulated > 0 ? 1 : -1)
                accumulated -= accumulated > 0 ? 10 : -10
            }
            return nil
        }
    }

    private func removeScroll() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        accumulated = 0
    }
}
