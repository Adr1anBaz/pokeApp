import SwiftUI

/// Where things sit in the battle scene, as fractions of its width/height (same as Android).
enum Anchors {
    // Bottom-center of each sprite (where it stands on its platform).
    static let theirX: CGFloat = 0.70
    static let theirY: CGFloat = 0.52
    static let myX: CGFloat = 0.27
    static let myY: CGFloat = 0.99

    static func center(_ side: Side, in size: CGSize) -> CGPoint {
        side == .mine
            ? CGPoint(x: myX * size.width, y: (myY - 0.2) * size.height)
            : CGPoint(x: theirX * size.width, y: (theirY - 0.13) * size.height)
    }
}

/// Small deterministic generator so every frame draws the same particles.
private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 1_000_000) / 1_000_000
    }
}

/// How a move's impact looks; chosen from its type.
private enum Pattern {
    case flames, bubbles, bolt, leaves, shards, rings, shadow, rocks, wind, swarm, sparkle, burst

    init(type: String?) {
        switch type {
        case "fire", "dragon": self = .flames
        case "water", "poison": self = .bubbles
        case "electric": self = .bolt
        case "grass": self = .leaves
        case "ice": self = .shards
        case "psychic": self = .rings
        case "ghost", "dark": self = .shadow
        case "rock", "ground": self = .rocks
        case "flying": self = .wind
        case "bug": self = .swarm
        case "fairy": self = .sparkle
        default: self = .burst
        }
    }
}

/// One attack's visual: an optional projectile (special moves) followed by an impact at the target.
/// Port of android/.../ui/battle/Effects.kt.
final class AttackEffect {
    private struct Particle { let a, b, c, d: CGFloat }

    let special: Bool
    private let fromSide: Side
    private let pattern: Pattern
    private let color: Color
    private let dark: Color
    private let particles: [Particle]

    init(type: String?, special: Bool, fromSide: Side, seed: Int) {
        self.special = special
        self.fromSide = fromSide
        pattern = Pattern(type: type)
        color = PokeTypes.style(type).color
        dark = PokeTypes.style(type).dark
        var rnd = SeededRandom(seed: seed)
        particles = (0..<18).map { _ in Particle(a: rnd.next(), b: rnd.next(), c: rnd.next(), d: rnd.next()) }
    }

    /// [p] goes 0...1 over the whole effect.
    func draw(_ g: GraphicsContext, size: CGSize, progress p: CGFloat) {
        let from = Anchors.center(fromSide, in: size)
        let to = Anchors.center(fromSide == .mine ? .theirs : .mine, in: size)
        let u = size.width / 10

        func circle(_ c: CGPoint, _ r: CGFloat, _ color: Color) {
            g.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
        }
        func ring(_ c: CGPoint, _ r: CGFloat, _ color: Color, _ width: CGFloat) {
            g.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color), lineWidth: width)
        }
        func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat) {
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            g.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        func clamp(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

        let impactStart: CGFloat = special ? 0.4 : 0
        if special && p < impactStart {
            let t = p / impactStart
            let pos = CGPoint(x: from.x + (to.x - from.x) * t,
                              y: from.y + (to.y - from.y) * t - sin(t * .pi) * u * 0.8)
            circle(pos, u * 0.55, color.opacity(0.35))
            circle(pos, u * 0.35, color)
            circle(pos, u * 0.15, .white)
            return
        }
        let t = clamp((p - impactStart) / (1 - impactStart))

        switch pattern {
        case .flames:
            for q in particles {
                let x = to.x + (q.a - 0.5) * u * 2.2
                let y = to.y + u * 0.8 - t * u * (1.2 + q.b * 1.6)
                let r = u * (0.25 + q.c * 0.35) * (1 - t * 0.8)
                circle(CGPoint(x: x, y: y), r * 0.55, Color(hex: 0xFFE070).opacity(Double(1 - t)))
                circle(CGPoint(x: x, y: y + r * 0.3), r, color.opacity(Double((1 - t) * 0.8)))
            }
        case .bubbles:
            for (i, q) in particles.enumerated() {
                let angle = q.a * 2 * .pi
                let dist = t * u * (0.8 + q.b * 1.4)
                let c = CGPoint(x: to.x + cos(angle) * dist, y: to.y + sin(angle) * dist - t * u * 0.4)
                let r = u * (0.15 + q.c * 0.25)
                circle(c, r, color.opacity(Double((1 - t) * 0.5)))
                ring(c, r, Color.white.opacity(Double(1 - t)), u * 0.05)
                if i % 3 == 0 { circle(CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), r * 0.3, Color.white.opacity(Double(1 - t))) }
            }
        case .bolt:
            let flicker = Int(t * 9) % 2 == 0
            if t < 0.85 && flicker {
                for k in 0..<3 {
                    var path = Path()
                    var x = to.x + (particles[k].a - 0.5) * u * 1.5
                    var y = to.y - u * 3.5
                    path.move(to: CGPoint(x: x, y: y))
                    for s in 0..<6 {
                        x += (particles[(k * 5 + s) % particles.count].b - 0.5) * u * 1.2
                        y += u * 0.62
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    g.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: u * 0.22, lineCap: .round, lineJoin: .round))
                    g.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: u * 0.12, lineCap: .round, lineJoin: .round))
                }
            }
            circle(to, u * (0.5 + t * 1.5), color.opacity(Double((1 - t) * 0.5)))
        case .leaves:
            for q in particles {
                let angle = q.a * 2 * .pi + t * 4
                let dist = u * (0.3 + t * (1.2 + q.b))
                let c = CGPoint(x: to.x + cos(angle) * dist, y: to.y + sin(angle) * dist * 0.7)
                var leaf = g
                leaf.translateBy(x: c.x, y: c.y)
                leaf.rotate(by: .degrees(Double(angle * 57.3 + t * 360)))
                leaf.opacity = Double(1 - t * 0.7)
                leaf.fill(Path(ellipseIn: CGRect(x: -u * 0.28, y: -u * 0.12, width: u * 0.56, height: u * 0.24)),
                          with: .color(q.c > 0.5 ? color : dark))
            }
        case .shards:
            for q in particles {
                let angle = q.a * 2 * .pi
                let dist = u * t * (1.2 + q.b * 1.5)
                let c = CGPoint(x: to.x + cos(angle) * dist, y: to.y + sin(angle) * dist)
                let s = u * (0.18 + q.c * 0.2)
                var path = Path()
                path.move(to: CGPoint(x: c.x, y: c.y - s * 1.6))
                path.addLine(to: CGPoint(x: c.x + s, y: c.y))
                path.addLine(to: CGPoint(x: c.x, y: c.y + s * 1.6))
                path.addLine(to: CGPoint(x: c.x - s, y: c.y))
                path.closeSubpath()
                g.fill(path, with: .color(Color.white.opacity(Double(1 - t))))
                g.stroke(path, with: .color(color.opacity(Double(1 - t))), lineWidth: u * 0.06)
            }
        case .rings:
            for k in 0..<4 {
                let tt = clamp(t * 1.6 - CGFloat(k) * 0.2)
                if tt > 0 { ring(to, u * (0.2 + tt * 2), color.opacity(Double(1 - tt)), u * 0.16) }
            }
        case .shadow:
            circle(to, u * 2.2, Color(hex: 0x201030).opacity(Double(sin(t * .pi) * 0.55)))
            for q in particles {
                let angle = q.a * 2 * .pi
                let dist = u * (2.2 - t * 2) * (0.6 + q.b * 0.6)
                circle(CGPoint(x: to.x + cos(angle) * dist, y: to.y + sin(angle) * dist),
                       u * (0.15 + q.c * 0.2), color.opacity(Double(sin(t * .pi))))
            }
        case .rocks:
            for q in particles.prefix(9) {
                let tt = clamp((t - q.d * 0.4) / 0.6)
                if tt <= 0 { continue }
                let x = to.x + (q.a - 0.5) * u * 2.4
                let y = to.y - u * 3 + tt * u * (3 + q.b * 0.6)
                let s = u * (0.25 + q.c * 0.3)
                var rock = g
                rock.translateBy(x: x, y: y)
                rock.rotate(by: .degrees(Double(tt * 200 * (q.a - 0.5))))
                rock.opacity = Double(1 - max(tt - 0.8, 0) * 5)
                rock.fill(Path(CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(dark))
                rock.fill(Path(CGRect(x: -s / 2, y: -s / 2, width: s * 0.6, height: s * 0.6)), with: .color(color))
            }
        case .wind:
            for k in 0..<5 {
                let tt = clamp(t * 1.4 - CGFloat(k) * 0.08)
                let y = to.y + CGFloat(k - 2) * u * 0.45
                let x0 = to.x - u * 2.5 + tt * u * 3.5
                // Arc from 200° to 340° of an ellipse 1.6u × 0.8u (like Android's drawArc).
                let center = CGPoint(x: x0 + u * 0.8, y: y)
                var arc = Path()
                for step in 0...12 {
                    let deg = 200 + 140 * Double(step) / 12
                    let rad = CGFloat(deg * .pi / 180)
                    let point = CGPoint(x: center.x + cos(rad) * u * 0.8, y: center.y + sin(rad) * u * 0.4)
                    if step == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
                }
                g.stroke(arc, with: .color(Color.white.opacity(Double(1 - tt))), style: StrokeStyle(lineWidth: u * 0.12, lineCap: .round))
            }
        case .swarm:
            for q in particles {
                let angle = q.a * 2 * .pi + t * 10 * (q.b > 0.5 ? 1 : -1)
                let dist = u * (0.6 + q.c * 0.9) * (1 - t * 0.5)
                circle(CGPoint(x: to.x + cos(angle) * dist, y: to.y + sin(angle) * dist * 0.6), u * 0.1, dark.opacity(Double(1 - t * 0.6)))
            }
        case .sparkle:
            for q in particles {
                let twinkle = max(sin((t * 3 + q.d) * .pi), 0)
                let c = CGPoint(x: to.x + (q.a - 0.5) * u * 2.6, y: to.y + (q.b - 0.5) * u * 2.2)
                let s = u * (0.15 + q.c * 0.3) * twinkle
                line(CGPoint(x: c.x - s, y: c.y), CGPoint(x: c.x + s, y: c.y), .white, u * 0.07)
                line(CGPoint(x: c.x, y: c.y - s), CGPoint(x: c.x, y: c.y + s), .white, u * 0.07)
                circle(c, s * 0.4, color.opacity(Double(twinkle)))
            }
        case .burst:
            let r = u * (0.4 + t * 1.6)
            for k in 0..<10 {
                let a = CGFloat(k) * .pi / 5 + particles[k].a * 0.3
                let start = CGPoint(x: to.x + cos(a) * r * 0.4, y: to.y + sin(a) * r * 0.4)
                let end = CGPoint(x: to.x + cos(a) * r, y: to.y + sin(a) * r)
                line(start, end, Color.white.opacity(Double(1 - t)), u * 0.14)
                line(start, end, color.opacity(Double(1 - t)), u * 0.07)
            }
            circle(to, u * 0.5 * (1 - t), Color.white.opacity(Double((1 - t) * 0.8)))
        }
    }
}
