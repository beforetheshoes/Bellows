import SwiftUI

@MainActor
struct AnimatedBlobBackground: View {
    var colors: [Color]
    var speed: Double = 0.25

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { context, size in
                let w = size.width
                let h = size.height
                func blob(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: Color) {
                    let rect = CGRect(x: cx - r, y: cy - r, width: 2*r, height: 2*r)
                    let gradient = Gradient(colors: [color.opacity(0.55), color.opacity(0.15), .clear])
                    let path = Path(ellipseIn: rect)
                    context.fill(path, with: .radialGradient(gradient,
                                                             center: CGPoint(x: cx, y: cy),
                                                             startRadius: 0,
                                                             endRadius: r))
                }
                let a = CGFloat(sin(t) * 0.4 + 0.5)
                let b = CGFloat(cos(t * 1.3) * 0.4 + 0.5)
                let c = CGFloat(sin(t * 0.7 + 1.2) * 0.4 + 0.5)
                if colors.count >= 3 {
                    blob(w * a, h * 0.35, max(w,h) * 0.45, colors[0])
                    blob(w * 0.3, h * b, max(w,h) * 0.50, colors[1])
                    blob(w * 0.7, h * c, max(w,h) * 0.40, colors[2])
                } else if let color = colors.first {
                    blob(w * 0.5, h * 0.5, max(w,h) * 0.55, color)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
struct ConfettiBurst: View {
    var trigger: Int
    var duration: Double = 1.4

    @State private var start: Date = .now

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = min(max(elapsed / duration, 0), 1)
            ZStack {
                ForEach(0..<60, id: \.self) { i in
                    let seed = Double((i + trigger * 37) % 997)
                    let x0 = CGFloat(frac(sin(seed) * 43758.5453))
                    let y0 = CGFloat(frac(cos(seed) * 24634.6345))
                    let hue = frac(sin(seed*1.3) * 0.5 + 0.5)
                    let x = x0 + CGFloat((progress * 0.6) * cos(seed))
                    let y = y0 + CGFloat((progress * 0.9) * (0.5 + abs(sin(seed*2))))
                    Rectangle()
                        .fill(Color(hue: hue, saturation: 0.85, brightness: 1.0))
                        .frame(width: 4, height: 10)
                        .rotationEffect(.degrees(Double(progress) * 720 + seed * 10))
                        .position(x: x * 240 + 10, y: y * 90 + 10)
                        .opacity(1 - progress)
                }
            }
        }
        .onAppear { start = .now }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func frac(_ x: Double) -> Double { x - floor(x) }
}
