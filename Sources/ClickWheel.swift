import SwiftUI

enum WheelZone { case center, menu, play, prev, next }

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
    var onLongMenu: () -> Void
    var onLongPlay: () -> Void
    var topGlyph: String? = nil
    var bottomGlyph: String = "playpause.fill"
    var leftGlyph: String = "backward.fill"
    var rightGlyph: String = "forward.fill"

    @State private var lastAngle: Double? = nil
    @State private var accumulated: Double = 0
    @State private var moved: Bool = false
    @State private var dragging: Bool = false
    @State private var longWork: DispatchWorkItem? = nil
    @State private var longFired: Bool = false
    @State private var pressZone: WheelZone = .center
    @State private var glowZone: WheelZone? = nil
    @State private var glowOpacity: Double = 0

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
                    if let tg = topGlyph {
                        Image(systemName: tg).font(.system(size: s * 0.075))
                    } else {
                        Text("MENU").font(.system(size: s * 0.072, weight: .semibold))
                    }
                    Spacer()
                    Image(systemName: bottomGlyph).font(.system(size: s * 0.075))
                }
                .foregroundColor(theme.wheelLabel)
                .padding(.vertical, s * 0.07)

                HStack {
                    Image(systemName: leftGlyph).font(.system(size: s * 0.075))
                    Spacer()
                    Image(systemName: rightGlyph).font(.system(size: s * 0.075))
                }
                .foregroundColor(theme.wheelLabel)
                .padding(.horizontal, s * 0.075)

                Circle()
                    .fill(theme.wheelC)
                    .overlay(Circle().stroke(theme.divider, lineWidth: 1))
                    .frame(width: s * 0.38, height: s * 0.38)

                if let gz = glowZone {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: s * 0.26, height: s * 0.26)
                        .position(zonePosition(gz, center: center, s: s))
                        .opacity(glowOpacity)
                        .blur(radius: s * 0.035)
                        .allowsHitTesting(false)
                }
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
                            pressZone = zoneFor(value.startLocation, center: center, centerRadius: centerRadius)
                            let zone = pressZone
                            if zone == .center || zone == .menu || zone == .play {
                                let work = DispatchWorkItem {
                                    longFired = true
                                    switch zone {
                                    case .center: onLongCenter()
                                    case .menu: onLongMenu()
                                    case .play: onLongPlay()
                                    default: break
                                    }
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
                        let zone = zoneFor(value.location, center: center, centerRadius: centerRadius)
                        triggerGlow(zone)
                        switch zone {
                        case .center: onSelect()
                        case .menu: onMenu()
                        case .play: onPlayPause()
                        case .prev: onPrev()
                        case .next: onNext()
                        }
                    }
            )
        }
        .frame(width: diameter, height: diameter)
    }

    private func zoneFor(_ p: CGPoint, center: CGPoint, centerRadius: CGFloat) -> WheelZone {
        let dx = p.x - center.x
        let dy = p.y - center.y
        if hypot(dx, dy) < centerRadius { return .center }
        if abs(dx) > abs(dy) { return dx < 0 ? .prev : .next }
        return dy < 0 ? .menu : .play
    }

    private func zonePosition(_ zone: WheelZone, center: CGPoint, s: CGFloat) -> CGPoint {
        let r = s * 0.36
        switch zone {
        case .center: return center
        case .menu: return CGPoint(x: center.x, y: center.y - r)
        case .play: return CGPoint(x: center.x, y: center.y + r)
        case .prev: return CGPoint(x: center.x - r, y: center.y)
        case .next: return CGPoint(x: center.x + r, y: center.y)
        }
    }

    private func triggerGlow(_ zone: WheelZone) {
        glowZone = zone
        glowOpacity = 0.55
        withAnimation(.easeOut(duration: 0.45)) { glowOpacity = 0 }
    }
}
