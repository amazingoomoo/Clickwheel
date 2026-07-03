import SwiftUI

/// A classic click-wheel control.
///
/// All interaction is handled by a single `DragGesture` to avoid the
/// gesture-priority conflicts you hit when layering taps and drags:
///  - Rotating a finger around the ring emits scroll up/down.
///  - A tap in the middle emits `select`.
///  - A tap on the ring emits menu / play-pause / prev / next depending on
///    which quadrant (top / bottom / left / right) was tapped.
struct ClickWheel: View {
    var onScrollUp: () -> Void
    var onScrollDown: () -> Void
    var onMenu: () -> Void
    var onSelect: () -> Void
    var onPrev: () -> Void
    var onNext: () -> Void
    var onPlayPause: () -> Void

    @State private var lastAngle: Double? = nil
    @State private var accumulated: Double = 0
    @State private var moved: Bool = false

    /// Degrees of rotation per scroll "notch".
    private let stepDegrees: Double = 24
    /// How far (points) a touch may travel and still count as a tap.
    private let tapSlop: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let centerRadius = size * 0.19

            ZStack {
                // Outer ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.wheelTop, Theme.wheelBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                // Labels (purely visual — not interactive)
                VStack {
                    Text("MENU")
                        .font(.system(size: size * 0.075, weight: .bold))
                        .foregroundColor(Theme.inkSoft)
                    Spacer()
                    Image(systemName: "playpause.fill")
                        .font(.system(size: size * 0.075))
                        .foregroundColor(Theme.inkSoft)
                }
                .padding(.vertical, size * 0.055)

                HStack {
                    Image(systemName: "backward.fill")
                        .font(.system(size: size * 0.075))
                        .foregroundColor(Theme.inkSoft)
                    Spacer()
                    Image(systemName: "forward.fill")
                        .font(.system(size: size * 0.075))
                        .foregroundColor(Theme.inkSoft)
                }
                .padding(.horizontal, size * 0.075)

                // Center button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.centerTop, Theme.centerBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = sqrt(dx * dx + dy * dy)
                        let travel = hypot(
                            value.location.x - value.startLocation.x,
                            value.location.y - value.startLocation.y
                        )
                        if travel > tapSlop { moved = true }

                        // Rotational scrubbing only when outside the centre button.
                        if dist > centerRadius {
                            let angle = atan2(dy, dx) * 180 / .pi
                            if let last = lastAngle {
                                var delta = angle - last
                                if delta > 180 { delta -= 360 }
                                else if delta < -180 { delta += 360 }
                                accumulated += delta
                                while accumulated >= stepDegrees {
                                    onScrollDown()
                                    accumulated -= stepDegrees
                                }
                                while accumulated <= -stepDegrees {
                                    onScrollUp()
                                    accumulated += stepDegrees
                                }
                            }
                            lastAngle = angle
                        }
                    }
                    .onEnded { value in
                        let wasMoved = moved
                        // Reset for next interaction.
                        moved = false
                        lastAngle = nil
                        accumulated = 0

                        if wasMoved { return } // it was a scroll, not a tap

                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = sqrt(dx * dx + dy * dy)

                        if dist < centerRadius {
                            onSelect()
                            return
                        }
                        // Ring tap: decide quadrant.
                        if abs(dx) > abs(dy) {
                            if dx < 0 { onPrev() } else { onNext() }
                        } else {
                            if dy < 0 { onMenu() } else { onPlayPause() }
                        }
                    }
            )
        }
    }
}
