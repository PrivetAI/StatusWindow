import SwiftUI

/// The screen shown while the launch check resolves. It carries no personal
/// content at all, so nothing sensitive is visible before the lock engages.
struct SWLoadingScreen: View {
    @State private var sweep: Double = 0

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 22) {
                Spacer(minLength: 0)

                SWLoadingMark(progress: sweep)
                    .frame(width: 108, height: 108)

                VStack(spacing: 6) {
                    Text("Status Window")
                        .font(SWFont.display(24))
                        .foregroundColor(SWTheme.ink)
                    Text("A private testing-window record")
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                }

                Spacer(minLength: 0)

                Text("Everything stays on this device.")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkFaint)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                sweep = 1
            }
        }
    }
}

/// A calendar window with a travelling day marker — the app's own mark, drawn
/// entirely in code.
private struct SWLoadingMark: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let w = max(1, size.width)
            let h = max(1, size.height)

            var frame = Path()
            frame.addRoundedRect(in: CGRect(x: w * 0.10, y: h * 0.18,
                                            width: w * 0.80, height: h * 0.68),
                                 cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
            context.fill(frame, with: .color(SWTheme.tealSoft.opacity(0.55)))
            context.stroke(frame, with: .color(SWTheme.teal.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2, lineJoin: .round))

            var rule = Path()
            rule.move(to: CGPoint(x: w * 0.10, y: h * 0.36))
            rule.addLine(to: CGPoint(x: w * 0.90, y: h * 0.36))
            context.stroke(rule, with: .color(SWTheme.teal.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1.6))

            for row in 0..<2 {
                for column in 0..<4 {
                    let x = w * (0.19 + CGFloat(column) * 0.18)
                    let y = h * (0.50 + CGFloat(row) * 0.18)
                    var cell = Path()
                    cell.addEllipse(in: CGRect(x: x - w * 0.035, y: y - h * 0.035,
                                               width: w * 0.07, height: h * 0.07))
                    context.fill(cell, with: .color(SWTheme.teal.opacity(0.28)))
                }
            }

            let markerX = w * (0.16 + CGFloat(SWMath.clamp(progress, 0, 1)) * 0.68)
            var marker = Path()
            marker.move(to: CGPoint(x: markerX, y: h * 0.14))
            marker.addLine(to: CGPoint(x: markerX, y: h * 0.90))
            context.stroke(marker, with: .color(SWTheme.amber),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }
}
