//
//  AnnouncementView.swift
//  SimpleNotch
//
//  The row an Announcement adds beneath the Wings on the closed notch.
//

import SwiftUI

struct AnnouncementView: View {
    @EnvironmentObject var vm: BoringViewModel
    let announcement: NotchAnnouncement

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let emoji = announcement.emoji {
                    Text(emoji)
                        .font(.system(size: 15))
                } else {
                    Image(systemName: announcement.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(announcement.tint)
                        .symbolEffect(.bounce, value: appeared)
                }
            }
            .scaleEffect(appeared ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 1) {
                Text(announcement.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                if let subtitle = announcement.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .overlay {
            if announcement.celebrates {
                ConfettiBurst()
                    .frame(width: 260, height: 120)
                    .offset(y: -10)
            }
        }
        .onAppear {
            withMotion(Motion.bouncy) { appeared = true }
        }
    }
}
