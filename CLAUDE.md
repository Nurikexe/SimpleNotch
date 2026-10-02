# SimpleNotch

Read `CONTEXT.md` for the project's vocabulary and `docs/adr/` for decisions that must not be undone.

## Motion standard

Every animation must feel smooth and expensive — Apple-quality. This is a hard requirement, not polish for later.

- **Springs only for movement and size.** Use SwiftUI springs (`.smooth`, `.snappy`, `.bouncy`, `.spring(response:dampingFraction:)`). Never `.linear` or `.easeInOut` for anything that moves, grows or shrinks. Reuse the original notch springs (open `response 0.42 / damping 0.8`, close `0.45 / 1.0`) and keep shared constants in one place, so all the motion feels like one system.
- **Interruptible.** Every animation must retarget smoothly if its state changes mid-flight (hover out while opening, pause during a transition). Springs carry velocity, so never chain fixed-duration steps with `DispatchQueue.asyncAfter`.
- **Continuous, not stepped.** Progress (rings, the Progress line) is computed from the real clock every frame via `TimelineView(.animation)`, so it glides at 120 Hz on ProMotion instead of jumping once a second. Digits change with `.contentTransition(.numericText())`.
- **Shared elements move, they don't pop.** Use `matchedGeometryEffect` when something exists in both the Closed and Open notch (the Tomato, artwork, timer). Insertions and removals use combined transitions (opacity + scale + slight blur), never a bare appear or disappear.
- **SF Symbols animate** with `.symbolEffect` / `.contentTransition(.symbolEffect)`.
- **Cheap to render.** Animate transform, opacity and blur. Don't animate things that force relayout of large trees. Target zero hitches in Instruments' Animation Hitches template.
- **Idle means idle.** No animation runs while the notch is closed and nothing is live. CPU must sit at ~0% at rest.
- **Respect Reduce Motion.** When `accessibilityReduceMotion` is on, swap bounces and travel for cross-fades.
