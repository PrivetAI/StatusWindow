import SwiftUI

// MARK: - Icon vocabulary
//
// Every glyph in this app is drawn here in code. There are no system symbols and
// no emoji anywhere in the interface. Each icon takes an explicit `size` rather
// than reading it from the drawing context, because a Canvas closure's reported
// size is not the parent's size.

enum SWGlyph: String, CaseIterable {
    case timeline
    case partners
    case log
    case health
    case settings
    case calendar
    case shield
    case clock
    case vial
    case swab
    case syringe
    case lock
    case unlock
    case alert
    case chevronRight
    case chevronLeft
    case chevronDown
    case plus
    case minus
    case close
    case check
    case pencil
    case trash
    case copy
    case search
    case book
    case chart
    case dot
    case info
}

struct SWIcon: View {
    let glyph: SWGlyph
    var size: CGFloat = 22
    var color: Color = SWTheme.ink
    var lineWidth: CGFloat = 1.7

    var body: some View {
        Canvas { context, _ in
            SWIconDrawing.draw(glyph: glyph,
                               in: CGSize(width: size, height: size),
                               context: &context,
                               color: color,
                               lineWidth: lineWidth)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum SWIconDrawing {

    // swiftlint:disable:next cyclomatic_complexity
    static func draw(glyph: SWGlyph,
                     in size: CGSize,
                     context: inout GraphicsContext,
                     color: Color,
                     lineWidth: CGFloat) {

        let w = max(1, size.width)
        let h = max(1, size.height)
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        let shading = GraphicsContext.Shading.color(color)

        func px(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: w * fx, y: h * fy)
        }

        switch glyph {

        case .timeline:
            // A horizontal window bar with a marker crossing it.
            var bar = Path()
            bar.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.24, width: w * 0.76, height: h * 0.16),
                               cornerSize: CGSize(width: h * 0.08, height: h * 0.08))
            context.stroke(bar, with: shading, style: stroke)
            var bar2 = Path()
            bar2.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.56, width: w * 0.50, height: h * 0.16),
                                cornerSize: CGSize(width: h * 0.08, height: h * 0.08))
            context.stroke(bar2, with: shading, style: stroke)
            var marker = Path()
            marker.move(to: px(0.70, 0.12))
            marker.addLine(to: px(0.70, 0.88))
            context.stroke(marker, with: shading, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [h * 0.10, h * 0.08]))

        case .partners:
            // Two overlapping neutral tokens, no human figures.
            var a = Path()
            a.addEllipse(in: CGRect(x: w * 0.08, y: h * 0.26, width: w * 0.46, height: h * 0.46))
            context.stroke(a, with: shading, style: stroke)
            var b = Path()
            b.addEllipse(in: CGRect(x: w * 0.46, y: h * 0.26, width: w * 0.46, height: h * 0.46))
            context.stroke(b, with: shading, style: stroke)

        case .log:
            // A page with ruled lines.
            var page = Path()
            page.addRoundedRect(in: CGRect(x: w * 0.20, y: h * 0.10, width: w * 0.60, height: h * 0.80),
                                cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
            context.stroke(page, with: shading, style: stroke)
            for i in 0..<3 {
                var line = Path()
                let y = 0.32 + CGFloat(i) * 0.18
                line.move(to: px(0.32, y))
                line.addLine(to: px(0.68, y))
                context.stroke(line, with: shading, style: stroke)
            }

        case .health:
            // A rounded shield outline.
            var shield = Path()
            shield.move(to: px(0.50, 0.08))
            shield.addLine(to: px(0.86, 0.24))
            shield.addCurve(to: px(0.50, 0.92),
                            control1: px(0.86, 0.62),
                            control2: px(0.70, 0.84))
            shield.addCurve(to: px(0.14, 0.24),
                            control1: px(0.30, 0.84),
                            control2: px(0.14, 0.62))
            shield.closeSubpath()
            context.stroke(shield, with: shading, style: stroke)

        case .settings:
            // Three sliders.
            for i in 0..<3 {
                let y = 0.26 + CGFloat(i) * 0.24
                var line = Path()
                line.move(to: px(0.14, y))
                line.addLine(to: px(0.86, y))
                context.stroke(line, with: shading, style: stroke)
                var knob = Path()
                let kx: CGFloat = i == 1 ? 0.66 : 0.36
                knob.addEllipse(in: CGRect(x: w * (kx - 0.09), y: h * (y - 0.09),
                                           width: w * 0.18, height: h * 0.18))
                context.fill(knob, with: .color(SWTheme.paper))
                context.stroke(knob, with: shading, style: stroke)
            }

        case .calendar:
            var frame = Path()
            frame.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.20, width: w * 0.76, height: h * 0.68),
                                 cornerSize: CGSize(width: w * 0.09, height: w * 0.09))
            context.stroke(frame, with: shading, style: stroke)
            var top = Path()
            top.move(to: px(0.12, 0.40))
            top.addLine(to: px(0.88, 0.40))
            context.stroke(top, with: shading, style: stroke)
            var pegL = Path()
            pegL.move(to: px(0.32, 0.10))
            pegL.addLine(to: px(0.32, 0.26))
            context.stroke(pegL, with: shading, style: stroke)
            var pegR = Path()
            pegR.move(to: px(0.68, 0.10))
            pegR.addLine(to: px(0.68, 0.26))
            context.stroke(pegR, with: shading, style: stroke)
            var day = Path()
            day.addRoundedRect(in: CGRect(x: w * 0.56, y: h * 0.52, width: w * 0.20, height: h * 0.20),
                               cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
            context.fill(day, with: shading)

        case .shield:
            var shield = Path()
            shield.move(to: px(0.50, 0.08))
            shield.addLine(to: px(0.86, 0.24))
            shield.addCurve(to: px(0.50, 0.92), control1: px(0.86, 0.62), control2: px(0.70, 0.84))
            shield.addCurve(to: px(0.14, 0.24), control1: px(0.30, 0.84), control2: px(0.14, 0.62))
            shield.closeSubpath()
            context.stroke(shield, with: shading, style: stroke)
            var tick = Path()
            tick.move(to: px(0.34, 0.48))
            tick.addLine(to: px(0.46, 0.60))
            tick.addLine(to: px(0.68, 0.36))
            context.stroke(tick, with: shading, style: stroke)

        case .clock:
            var ring = Path()
            ring.addEllipse(in: CGRect(x: w * 0.10, y: h * 0.10, width: w * 0.80, height: h * 0.80))
            context.stroke(ring, with: shading, style: stroke)
            var hands = Path()
            hands.move(to: px(0.50, 0.28))
            hands.addLine(to: px(0.50, 0.52))
            hands.addLine(to: px(0.70, 0.62))
            context.stroke(hands, with: shading, style: stroke)

        case .vial:
            var body = Path()
            body.move(to: px(0.34, 0.12))
            body.addLine(to: px(0.34, 0.72))
            body.addCurve(to: px(0.66, 0.72), control1: px(0.34, 0.92), control2: px(0.66, 0.92))
            body.addLine(to: px(0.66, 0.12))
            context.stroke(body, with: shading, style: stroke)
            var cap = Path()
            cap.move(to: px(0.28, 0.12))
            cap.addLine(to: px(0.72, 0.12))
            context.stroke(cap, with: shading, style: stroke)
            var fill = Path()
            fill.move(to: px(0.34, 0.52))
            fill.addLine(to: px(0.66, 0.52))
            context.stroke(fill, with: shading, style: stroke)

        case .swab:
            var stick = Path()
            stick.move(to: px(0.28, 0.84))
            stick.addLine(to: px(0.64, 0.34))
            context.stroke(stick, with: shading, style: stroke)
            var tip = Path()
            tip.addEllipse(in: CGRect(x: w * 0.58, y: h * 0.10, width: w * 0.26, height: h * 0.30))
            context.stroke(tip, with: shading, style: stroke)

        case .syringe:
            var barrel = Path()
            barrel.addRoundedRect(in: CGRect(x: w * 0.30, y: h * 0.22, width: w * 0.34, height: h * 0.44),
                                  cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
            context.stroke(barrel, with: shading, style: stroke)
            var needle = Path()
            needle.move(to: px(0.47, 0.66))
            needle.addLine(to: px(0.47, 0.90))
            context.stroke(needle, with: shading, style: stroke)
            var plunger = Path()
            plunger.move(to: px(0.47, 0.22))
            plunger.addLine(to: px(0.47, 0.08))
            context.stroke(plunger, with: shading, style: stroke)
            var flange = Path()
            flange.move(to: px(0.24, 0.30))
            flange.addLine(to: px(0.70, 0.30))
            context.stroke(flange, with: shading, style: stroke)

        case .lock, .unlock:
            var body = Path()
            body.addRoundedRect(in: CGRect(x: w * 0.20, y: h * 0.44, width: w * 0.60, height: h * 0.44),
                                cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
            context.stroke(body, with: shading, style: stroke)
            var shackle = Path()
            if glyph == .lock {
                shackle.move(to: px(0.32, 0.44))
                shackle.addLine(to: px(0.32, 0.28))
                shackle.addCurve(to: px(0.68, 0.28), control1: px(0.32, 0.06), control2: px(0.68, 0.06))
                shackle.addLine(to: px(0.68, 0.44))
            } else {
                shackle.move(to: px(0.32, 0.44))
                shackle.addLine(to: px(0.32, 0.28))
                shackle.addCurve(to: px(0.78, 0.30), control1: px(0.32, 0.04), control2: px(0.78, 0.06))
            }
            context.stroke(shackle, with: shading, style: stroke)

        case .alert:
            var tri = Path()
            tri.move(to: px(0.50, 0.10))
            tri.addLine(to: px(0.92, 0.84))
            tri.addLine(to: px(0.08, 0.84))
            tri.closeSubpath()
            context.stroke(tri, with: shading, style: stroke)
            var bar = Path()
            bar.move(to: px(0.50, 0.40))
            bar.addLine(to: px(0.50, 0.60))
            context.stroke(bar, with: shading, style: stroke)
            var pt = Path()
            pt.addEllipse(in: CGRect(x: w * 0.455, y: h * 0.68, width: w * 0.09, height: h * 0.09))
            context.fill(pt, with: shading)

        case .chevronRight:
            var p = Path()
            p.move(to: px(0.38, 0.20))
            p.addLine(to: px(0.66, 0.50))
            p.addLine(to: px(0.38, 0.80))
            context.stroke(p, with: shading, style: stroke)

        case .chevronLeft:
            var p = Path()
            p.move(to: px(0.62, 0.20))
            p.addLine(to: px(0.34, 0.50))
            p.addLine(to: px(0.62, 0.80))
            context.stroke(p, with: shading, style: stroke)

        case .chevronDown:
            var p = Path()
            p.move(to: px(0.22, 0.38))
            p.addLine(to: px(0.50, 0.66))
            p.addLine(to: px(0.78, 0.38))
            context.stroke(p, with: shading, style: stroke)

        case .plus:
            var p = Path()
            p.move(to: px(0.50, 0.16))
            p.addLine(to: px(0.50, 0.84))
            p.move(to: px(0.16, 0.50))
            p.addLine(to: px(0.84, 0.50))
            context.stroke(p, with: shading, style: stroke)

        case .minus:
            var p = Path()
            p.move(to: px(0.18, 0.50))
            p.addLine(to: px(0.82, 0.50))
            context.stroke(p, with: shading, style: stroke)

        case .close:
            var p = Path()
            p.move(to: px(0.24, 0.24))
            p.addLine(to: px(0.76, 0.76))
            p.move(to: px(0.76, 0.24))
            p.addLine(to: px(0.24, 0.76))
            context.stroke(p, with: shading, style: stroke)

        case .check:
            var p = Path()
            p.move(to: px(0.20, 0.54))
            p.addLine(to: px(0.42, 0.74))
            p.addLine(to: px(0.80, 0.26))
            context.stroke(p, with: shading, style: stroke)

        case .pencil:
            var body = Path()
            body.move(to: px(0.20, 0.80))
            body.addLine(to: px(0.28, 0.58))
            body.addLine(to: px(0.68, 0.16))
            body.addLine(to: px(0.86, 0.32))
            body.addLine(to: px(0.44, 0.74))
            body.closeSubpath()
            context.stroke(body, with: shading, style: stroke)

        case .trash:
            var lid = Path()
            lid.move(to: px(0.16, 0.26))
            lid.addLine(to: px(0.84, 0.26))
            context.stroke(lid, with: shading, style: stroke)
            var handle = Path()
            handle.move(to: px(0.38, 0.26))
            handle.addLine(to: px(0.38, 0.14))
            handle.addLine(to: px(0.62, 0.14))
            handle.addLine(to: px(0.62, 0.26))
            context.stroke(handle, with: shading, style: stroke)
            var can = Path()
            can.move(to: px(0.24, 0.26))
            can.addLine(to: px(0.30, 0.88))
            can.addLine(to: px(0.70, 0.88))
            can.addLine(to: px(0.76, 0.26))
            context.stroke(can, with: shading, style: stroke)

        case .copy:
            var back = Path()
            back.addRoundedRect(in: CGRect(x: w * 0.14, y: h * 0.12, width: w * 0.52, height: h * 0.56),
                                cornerSize: CGSize(width: w * 0.07, height: w * 0.07))
            context.stroke(back, with: shading, style: stroke)
            var front = Path()
            front.addRoundedRect(in: CGRect(x: w * 0.34, y: h * 0.32, width: w * 0.52, height: h * 0.56),
                                 cornerSize: CGSize(width: w * 0.07, height: w * 0.07))
            context.fill(front, with: .color(SWTheme.card))
            context.stroke(front, with: shading, style: stroke)

        case .search:
            var ring = Path()
            ring.addEllipse(in: CGRect(x: w * 0.14, y: h * 0.14, width: w * 0.52, height: h * 0.52))
            context.stroke(ring, with: shading, style: stroke)
            var tail = Path()
            tail.move(to: px(0.62, 0.62))
            tail.addLine(to: px(0.86, 0.86))
            context.stroke(tail, with: shading, style: stroke)

        case .book:
            var spine = Path()
            spine.move(to: px(0.50, 0.20))
            spine.addLine(to: px(0.50, 0.86))
            context.stroke(spine, with: shading, style: stroke)
            var left = Path()
            left.move(to: px(0.50, 0.20))
            left.addCurve(to: px(0.12, 0.26), control1: px(0.34, 0.12), control2: px(0.20, 0.16))
            left.addLine(to: px(0.12, 0.80))
            left.addCurve(to: px(0.50, 0.86), control1: px(0.24, 0.76), control2: px(0.36, 0.80))
            context.stroke(left, with: shading, style: stroke)
            var right = Path()
            right.move(to: px(0.50, 0.20))
            right.addCurve(to: px(0.88, 0.26), control1: px(0.66, 0.12), control2: px(0.80, 0.16))
            right.addLine(to: px(0.88, 0.80))
            right.addCurve(to: px(0.50, 0.86), control1: px(0.76, 0.76), control2: px(0.64, 0.80))
            context.stroke(right, with: shading, style: stroke)

        case .chart:
            var axis = Path()
            axis.move(to: px(0.14, 0.12))
            axis.addLine(to: px(0.14, 0.86))
            axis.addLine(to: px(0.88, 0.86))
            context.stroke(axis, with: shading, style: stroke)
            for i in 0..<3 {
                var bar = Path()
                let x = 0.28 + CGFloat(i) * 0.22
                let top = 0.62 - CGFloat(i) * 0.18
                bar.addRoundedRect(in: CGRect(x: w * x, y: h * top,
                                              width: w * 0.14, height: h * (0.86 - top)),
                                   cornerSize: CGSize(width: w * 0.03, height: w * 0.03))
                context.fill(bar, with: shading)
            }

        case .dot:
            var p = Path()
            p.addEllipse(in: CGRect(x: w * 0.30, y: h * 0.30, width: w * 0.40, height: h * 0.40))
            context.fill(p, with: shading)

        case .info:
            var ring = Path()
            ring.addEllipse(in: CGRect(x: w * 0.10, y: h * 0.10, width: w * 0.80, height: h * 0.80))
            context.stroke(ring, with: shading, style: stroke)
            var stem = Path()
            stem.move(to: px(0.50, 0.46))
            stem.addLine(to: px(0.50, 0.72))
            context.stroke(stem, with: shading, style: stroke)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: w * 0.455, y: h * 0.28, width: w * 0.09, height: h * 0.09))
            context.fill(dot, with: shading)
        }
    }
}

// MARK: - Colour chip

struct SWChipDot: View {
    let colorIndex: Int
    var size: CGFloat = 12
    var ringed: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(SWTheme.chip(colorIndex))
                .frame(width: size, height: size)
            if ringed {
                Circle()
                    .stroke(SWTheme.card, lineWidth: 2)
                    .frame(width: size + 4, height: size + 4)
            }
        }
        .frame(width: size + 6, height: size + 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Partner token
//
// Initials on a coloured disc. No imagery of people anywhere in this app.

struct SWPartnerToken: View {
    let initials: String
    let colorIndex: Int
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle()
                .fill(SWTheme.chip(colorIndex).opacity(0.16))
            Circle()
                .stroke(SWTheme.chip(colorIndex).opacity(0.55), lineWidth: 1.4)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundColor(SWTheme.chip(colorIndex))
        }
        .frame(width: size, height: size)
    }
}
