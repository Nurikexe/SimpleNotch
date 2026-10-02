//
//  NotchWings.swift
//  SimpleNotch
//
//  The Wings: two live-indicator areas either side of the hardware notch on
//  the closed notch. Media, Focus and downloads all lay themselves out here.
//

import SwiftUI

struct NotchWings<Leading: View, Trailing: View>: View {
    @EnvironmentObject var vm: NotchViewModel
    /// Width of each wing; defaults to a square the height of the notch content.
    var wingWidth: CGFloat?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    static func defaultSide(for vm: NotchViewModel) -> CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12)
    }

    var body: some View {
        let side = Self.defaultSide(for: vm)
        let width = wingWidth ?? side
        HStack(spacing: 0) {
            leading
                .frame(width: width, height: side, alignment: .leading)
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top + 8)
            trailing
                .frame(width: width, height: side, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }

    /// How much wider than the hardware notch the closed notch becomes.
    static func extraWidth(wingWidth: CGFloat) -> CGFloat {
        2 * wingWidth + 20
    }
}
