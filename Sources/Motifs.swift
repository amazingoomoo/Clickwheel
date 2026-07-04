import SwiftUI

// Seeded RNG so the scatter is stable (no flicker between redraws).
private struct RNG {
    private var s: UInt64
    init(_ seed: UInt64) { s = (seed &* 2654435761) | 1 }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double(s >> 11) * (1.0 / 9007199254740992.0)
    }
}

private func gridPoints(_ size: CGSize, _ cols: Int, _ rows: Int, _ jitter: CGFloat, _ rng: inout RNG) -> [CGPoint] {
    var pts: [CGPoint] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let cx = (CGFloat(c) + 0.5) / CGFloat(cols) * size.width + CGFloat(rng.next() * 2 - 1) * jitter * (size.width / CGFloat(cols))
            let cy = (CGFloat(r) + 0.5) / CGFloat(rows) * size.height + CGFloat(rng.next() * 2 - 1) * jitter * (size.height / CGFloat(rows))
            pts.append(CGPoint(x: cx, y: cy))
        }
    }
    return pts
}

// MARK: - Egyptian glyphs (0 ankh, 1 eye, 2 bird, 3 sun, 4 water, 5 feather)

private func egGlyph(_ idx: Int, _ ctx: inout GraphicsContext, _ center: CGPoint, _ box: CGFloat, _ color: Color) {
    let sc = box / 24
    let o = CGPoint(x: center.x - box / 2, y: center.y - box / 2)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * sc, y: o.y + y * sc) }
    let lw = max(0.8, 1.4 * sc)

    switch idx {
    case 0: // ankh
        var path = Path()
        path.addEllipse(in: CGRect(x: o.x + 9 * sc, y: o.y + 2 * sc, width: 6 * sc, height: 6.5 * sc))
        path.move(to: p(12, 8.5)); path.addLine(to: p(12, 21))
        path.move(to: p(6.5, 12)); path.addLine(to: p(17.5, 12))
        ctx.stroke(path, with: .color(color), lineWidth: lw)
    case 1: // eye of Horus
        var path = Path()
        path.move(to: p(3, 12.5)); path.addQuadCurve(to: p(19, 11.5), control: p(11, 8))
        path.move(to: p(3, 12.5)); path.addQuadCurve(to: p(17, 12.8), control: p(10, 16))
        path.move(to: p(11, 14.6)); path.addLine(to: p(11, 19))
        path.move(to: p(7.5, 15)); path.addQuadCurve(to: p(9.6, 18), control: p(6, 20))
        ctx.stroke(path, with: .color(color), lineWidth: lw)
        var pupil = Path()
        pupil.addEllipse(in: CGRect(x: o.x + 9 * sc, y: o.y + 10.3 * sc, width: 3 * sc, height: 3 * sc))
        ctx.fill(pupil, with: .color(color))
    case 2: // standing bird
        var body = Path(); body.addEllipse(in: CGRect(x: o.x + 4 * sc, y: o.y + 10 * sc, width: 12 * sc, height: 6 * sc))
        var head = Path(); head.addEllipse(in: CGRect(x: o.x + 13.7 * sc, y: o.y + 7.7 * sc, width: 4.6 * sc, height: 4.6 * sc))
        ctx.fill(body, with: .color(color)); ctx.fill(head, with: .color(color))
        var beak = Path(); beak.move(to: p(18, 10)); beak.addLine(to: p(21.5, 9)); beak.addLine(to: p(18.3, 11)); beak.closeSubpath()
        ctx.fill(beak, with: .color(color))
        var legs = Path(); legs.move(to: p(9, 15.6)); legs.addLine(to: p(9, 20)); legs.move(to: p(12.5, 15.6)); legs.addLine(to: p(12.5, 20))
        ctx.stroke(legs, with: .color(color), lineWidth: max(0.7, 1.0 * sc))
    case 3: // sun disk
        var ring = Path(); ring.addEllipse(in: CGRect(x: o.x + 6 * sc, y: o.y + 6 * sc, width: 12 * sc, height: 12 * sc))
        ctx.stroke(ring, with: .color(color), lineWidth: lw)
        var dot = Path(); dot.addEllipse(in: CGRect(x: o.x + 10 * sc, y: o.y + 10 * sc, width: 4 * sc, height: 4 * sc))
        ctx.fill(dot, with: .color(color))
    case 4: // water
        var path = Path()
        path.move(to: p(3, 9)); path.addQuadCurve(to: p(9, 9), control: p(6, 5)); path.addQuadCurve(to: p(15, 9), control: p(12, 13)); path.addQuadCurve(to: p(21, 9), control: p(18, 5))
        path.move(to: p(3, 14)); path.addQuadCurve(to: p(9, 14), control: p(6, 10)); path.addQuadCurve(to: p(15, 14), control: p(12, 18)); path.addQuadCurve(to: p(21, 14), control: p(18, 10))
        ctx.stroke(path, with: .color(color), lineWidth: lw)
    default: // feather
        var path = Path()
        path.move(to: p(12, 3)); path.addQuadCurve(to: p(9, 20), control: p(8, 11)); path.addLine(to: p(15, 20)); path.addQuadCurve(to: p(12, 3), control: p(16, 11)); path.closeSubpath()
        ctx.stroke(path, with: .color(color), lineWidth: lw)
        var spine = Path(); spine.move(to: p(12, 6)); spine.addLine(to: p(12, 19))
        ctx.stroke(spine, with: .color(color), lineWidth: max(0.6, 0.9 * sc))
    }
}

private func tarotSparkle(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ color: Color) {
    var v = Path()
    v.move(to: CGPoint(x: c.x, y: c.y - r)); v.addLine(to: CGPoint(x: c.x + r * 0.26, y: c.y))
    v.addLine(to: CGPoint(x: c.x, y: c.y + r)); v.addLine(to: CGPoint(x: c.x - r * 0.26, y: c.y)); v.closeSubpath()
    var h = Path()
    h.move(to: CGPoint(x: c.x - r, y: c.y)); h.addLine(to: CGPoint(x: c.x, y: c.y - r * 0.26))
    h.addLine(to: CGPoint(x: c.x + r, y: c.y)); h.addLine(to: CGPoint(x: c.x, y: c.y + r * 0.26)); h.closeSubpath()
    ctx.fill(v, with: .color(color))
    ctx.fill(h, with: .color(color))
}

private func emeraldDiamond(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ color: Color, filled: Bool) {
    var d = Path()
    d.move(to: CGPoint(x: c.x, y: c.y - r)); d.addLine(to: CGPoint(x: c.x + r * 0.66, y: c.y))
    d.addLine(to: CGPoint(x: c.x, y: c.y + r)); d.addLine(to: CGPoint(x: c.x - r * 0.66, y: c.y)); d.closeSubpath()
    if filled { ctx.fill(d, with: .color(color)) }
    else { ctx.stroke(d, with: .color(color), lineWidth: max(1, r * 0.16)) }
}

private func drawEgypt(_ ctx: inout GraphicsContext, _ size: CGSize) {
    var rng = RNG(11)
    let color = Themes.hex(0x6e5227).opacity(0.22)
    let weights = [0, 0, 1, 1, 2, 2, 3, 4, 5]
    let pts = gridPoints(size, 6, 10, 0.4, &rng)
    for pt in pts {
        let idx = weights[Int(rng.next() * Double(weights.count)) % weights.count]
        let box = CGFloat(22) * CGFloat(0.75 + rng.next() * 0.55)
        egGlyph(idx, &ctx, pt, box, color)
    }
}

private func drawTarot(_ ctx: inout GraphicsContext, _ size: CGSize) {
    var rng = RNG(7)
    let color = Themes.hex(0xd4b13f).opacity(0.30)
    let pts = gridPoints(size, 7, 11, 0.42, &rng)
    for pt in pts {
        let r = CGFloat(9) * CGFloat(0.7 + rng.next() * 0.6)
        tarotSparkle(&ctx, pt, r, color)
    }
}

private func drawEmerald(_ ctx: inout GraphicsContext, _ size: CGSize) {
    var rng = RNG(5)
    let color = Themes.hex(0x2ec46f).opacity(0.26)
    let pts = gridPoints(size, 8, 12, 0.42, &rng)
    for pt in pts {
        let r = CGFloat(8) * CGFloat(0.7 + rng.next() * 0.6)
        emeraldDiamond(&ctx, pt, r, color, filled: rng.next() < 0.5)
    }
}

private func drawCyber(_ ctx: inout GraphicsContext, _ size: CGSize) {
    let W = size.width, H = size.height
    var rng = RNG(42)
    let lanes = 10
    let span = W / CGFloat(lanes)
    let lineColor = Themes.hex(0x29c4ff).opacity(0.5)
    let dotColor = Themes.hex(0x29c4ff).opacity(0.7)

    for i in 0..<lanes {
        let cx = (CGFloat(i) + 0.5) * span
        let half = span * 0.34
        var x = cx + CGFloat(rng.next() * 2 - 1) * half * 0.4
        var y = H - 6
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        var dots = Path()
        dots.addEllipse(in: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6))
        var guardN = 0
        while y > 7 && guardN < 30 {
            guardN += 1
            let roll = rng.next()
            if roll < 0.16 {
                x = min(cx + half, max(cx - half, cx + CGFloat(rng.next() * 2 - 1) * half))
                path.addLine(to: CGPoint(x: x, y: y))
                dots.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                y -= CGFloat(28 + rng.next() * 46); if y < 7 { y = 7 }
                path.addLine(to: CGPoint(x: x, y: y))
            } else if roll < 0.30 {
                let run = CGFloat(16 + rng.next() * 26)
                let dir: CGFloat = rng.next() < 0.5 ? -1 : 1
                let tx = min(cx + half, max(cx - half, x + dir * run))
                let dx = abs(tx - x)
                x = tx; y -= dx; if y < 7 { y = 7 }
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                y -= CGFloat(40 + rng.next() * 80); if y < 7 { y = 7 }
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        dots.addEllipse(in: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6))
        ctx.stroke(path, with: .color(lineColor), lineWidth: 1.2)
        ctx.fill(dots, with: .color(dotColor))
    }
}

struct MotifBackground: View {
    let themeKey: String

    var body: some View {
        Canvas { context, size in
            switch themeKey {
            case "egypt": drawEgypt(&context, size)
            case "tarot": drawTarot(&context, size)
            case "emerald": drawEmerald(&context, size)
            case "cyber": drawCyber(&context, size)
            default: break
            }
        }
        .allowsHitTesting(false)
    }
}
