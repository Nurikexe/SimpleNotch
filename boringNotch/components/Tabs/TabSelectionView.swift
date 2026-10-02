//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation
    @Default(.tabHomeEnabled) private var homeOn
    @Default(.boringShelf) private var shelfOn
    @Default(.tabClipboardEnabled) private var clipboardOn
    @Default(.tabFocusEnabled) private var focusOn
    @Default(.tabTranslateEnabled) private var translateOn
    @Default(.tabBirthdaysEnabled) private var birthdaysOn

    private var tabs: [NotchViews] {
        // Reading the @Default properties keeps this view live when a Tab is toggled.
        _ = (homeOn, shelfOn, clipboardOn, focusOn, translateOn, birthdaysOn)
        return NotchViews.enabledTabs
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let selected = coordinator.currentView == tab
                TabButton(label: tab.label, icon: tab.icon, selected: selected) {
                    withMotion(Motion.snappy) {
                        coordinator.select(tab)
                    }
                }
                .frame(height: 26)
                .foregroundStyle(selected ? .white : .gray)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    }
                }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
