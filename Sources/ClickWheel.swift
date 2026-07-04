import SwiftUI

struct ClickWheel: View {
    @Environment(\.appTheme) var theme
    var diameter: CGFloat
    var onScrollUp: () -> Void
    var onScrollDown: () -> Void
    var onMenu: () -> Void
    var onSelect: () -> Void
    var onPrev: () -> Void
    var onNext: () -> Void
    var onPlayPause: () -> Void
    var onLongCenter: () -> Void

    @State private var lastAngle: Double? = nil
    @State private var accumulated: Double = 0
    @State private var moved: Bool = false
    @State private var dragging: Bool = false
    @State private var longWork: DispatchWorkItem? = nil
    @State private var longFired: Bool = false

    private let stepDegrees: Double = 24
    private let tapSlop: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let centerRadius = s * 0.19

            ZStack {
                Circle()
                    .fill(theme.wheel)
                    .overlay(Circle().stroke(theme.divider, lineWidth: 1))

                VStack {
                    Text("MENU").font(.system(size: s * 0.072, weight: .semibold))
                    Spacer()
                    Image(systemName: "playpause.fill").font(.system(size: s * 0.075))
                }
                .foregroundColor(theme.wheelLabel)
                .padding(.vertical, s * 0.07)

                HStack {
                    Image(systemName: "backward.fill").font(.system(size: s * 0.075))
                    Spacer()
                    Image(systemName: "forward.fill").font(.system(size: s * 0.075))
                }
                .foregroundColor(theme.wheelLabel)
                .padding(.horizontal, s * 0.075)

                Circle()
                    .fill(theme.wheelC)
                    .overlay(Circle().stroke(theme.divider, lineWidth: 1))
                    .frame(width: s * 0.38, height: s * 0.38)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            moved = false
                            longFired = false
                            lastAngle = nil
                            accumulated = 0
                            let start = value.startLocation
                            if hypot(start.x - center.x, start.y - center.y) < centerRadius {
                                let work = DispatchWorkItem {
                                    longFired = true
                                    onLongCenter()
                                }
                                longWork = work
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                            }
                        }
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = hypot(dx, dy)
                        if hypot(value.location.x - value.startLocation.x, value.location.y - value.startLocation.y) > tapSlop {
                            moved = true
                            longWork?.cancel()
                        }
                        if dist > centerRadius {
                            let angle = atan2(dy, dx) * 180 / .pi
                            if let last = lastAngle {
                                var delta = angle - last
                                if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
                                accumulated += delta
                                while accumulated >= stepDegrees { onScrollDown(); accumulated -= stepDegrees }
                                while accumulated <= -stepDegrees { onScrollUp(); accumulated += stepDegrees }
                            }
                            lastAngle = angle
                        }
                    }
                    .onEnded { value in
                        dragging = false
                        longWork?.cancel()
                        if moved || longFired { return }
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = hypot(dx, dy)
                        if dist < centerRadius { onSelect(); return }
                        if abs(dx) > abs(dy) {
                            if dx < 0 { onPrev() } else { onNext() }
                        } else {
                            if dy < 0 { onMenu() } else { onPlayPause() }
                        }
                    }
            )
        }
        .frame(width: diameter, height: diameter)
    }
}
