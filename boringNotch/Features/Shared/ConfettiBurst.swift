//
//  ConfettiBurst.swift
//  SimpleNotch
//
//  A one-shot confetti burst drawn with Canvas from a single start time, so it
//  costs nothing once it has fallen away. Used by Announcements, today's
//  Birthday and the Tomato's celebration.
//

import SwiftUI

struct ConfettiBurst: View {
    var colors: [Color] = [.red, .orange, .yellow, .green, .mint, .pink, .purple]
    var count = 36
    var lifetime: TimeInterval = 1.8

    @State private var start = Date()
    @State private var pieces: [Piece] = []
    @State private var finished = false

    struct Piece {
        var angle: Double
        var speed: Double
        var spin: Double
        var size: CGSize
        var color: Color
        var isCircle: Bool
    }

    var body: some View {
        Group {
            if !finished && !Motion.reduceMotion {
                TimelineView(.animation) { context in
                    Canvas { ctx, size in
                        let t = context.date.timeIntervalSince(start)
                        let origin = CGPoint(x: size.width / 2, y: size.height * 0.35)
                        let fade = max(0, 1 - t / lifetime)
                        for piece in pieces {
                            // Ballistic arc with drag, so pieces burst fast then float.
                            let travel = piece.speed * (1 - exp(-3 * t)) / 3
                            let x = origin.x + cos(piece.angle) * travel
                            let y = origin.y + sin(piece.angle) * travel + 60 * t * t
                            var c = ctx
                            c.opacity = fade
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .radians(piece.spin * t))
                            let rect = CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size)
                            let path = piece.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1)
                            c.fill(path, with: .color(piece.color))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            pieces = (0..<count).map { _ in
                Piece(
                    angle: Double.random(in: -.pi * 0.95 ... -.pi * 0.05) + (Bool.random() ? 0 : .pi * 0.5 * Double.random(in: -0.3...0.3)),
                    speed: Double.random(in: 140...320),
                    spin: Double.random(in: -10...10),
                    size: CGSize(width: Double.random(in: 3...6), height: Double.random(in: 5...9)),
                    color: colors.randomElement() ?? .white,
                    isCircle: Int.random(in: 0..<4) == 0
                )
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(lifetime))
                finished = true
            }
        }
    }
}
