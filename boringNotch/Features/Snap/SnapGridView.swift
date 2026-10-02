//
//  SnapGridView.swift
//  SimpleNotch
//
//  The Snap grid: every Layout as a miniature screen. The notch window gets no
//  hover events while another app drags a window, so each tile reports its
//  frame and WindowSnapManager hit-tests the pointer itself.
//

import SwiftUI

struct SnapGridView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var hover = WindowSnapManager.shared.hover

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(Array(SnapLayout.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 10) {
                        ForEach(row) { layout in
                            SnapTile(layout: layout, isHovered: hover.layout == layout)
                                .onGeometryChange(for: CGRect.self) { proxy in
                                    proxy.frame(in: .global)
                                } action: { frame in
                                    WindowSnapManager.shared.registerTileFrame(
                                        frame, for: layout, screenID: vm.screenUUID, window: vm.hostWindow
                                    )
                                }
                        }
                    }
                }
            }

            caption
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var caption: some View {
        Group {
            if let layout = hover.layout {
                Text(layout.title)
                    .foregroundStyle(.white)
            } else {
                Text("Drop the window on a layout")
                    .foregroundStyle(.gray)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1)
        .contentTransition(.interpolate)
    }
}

/// One Layout drawn as a tiny screen with its region filled in.
private struct SnapTile: View {
    let layout: SnapLayout
    let isHovered: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 58, height: 36)
    private let cornerRadius: CGFloat = 7
    private let inset: CGFloat = 3
    private let menuBarHeight: CGFloat = 3

    var body: some View {
        let unit = layout.unitRect
        let area = CGSize(
            width: Self.size.width - inset * 2,
            height: Self.size.height - inset * 2 - menuBarHeight - 1
        )

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.16 : 0.07))

            // Menu bar of the miniature screen.
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: Self.size.width - inset * 2 - 6, height: 1.5)
                .offset(x: inset + 3, y: inset)

            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.95 : 0.42))
                .frame(
                    width: max(2, unit.width * area.width - 1.5),
                    height: max(2, unit.height * area.height - 1.5)
                )
                .offset(
                    x: inset + unit.minX * area.width + 0.75,
                    y: inset + menuBarHeight + 1 + unit.minY * area.height + 0.75
                )
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(isHovered ? 0.55 : 0.1), lineWidth: 1)
        }
        .shadow(color: .white.opacity(isHovered ? 0.35 : 0), radius: isHovered ? 10 : 0)
        .scaleEffect(isHovered && !reduceMotion ? 1.12 : 1)
        .zIndex(isHovered ? 1 : 0)
        .accessibilityElement()
        .accessibilityLabel(layout.title)
    }
}
