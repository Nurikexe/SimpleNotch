//
//  TabButton.swift
//  SimpleNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

struct TabButton: View {
    let label: LocalizedStringKey
    let icon: String
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 18)
                .padding(.horizontal, 8)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .help(Text(label))
    }
}
