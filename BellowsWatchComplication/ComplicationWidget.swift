import WidgetKit
import SwiftUI

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let intensity: Double
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), streak: 7, intensity: 0.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh periodically (e.g., every hour)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> ComplicationEntry {
        // Prefer checking the container URL to avoid noisy CFPreferences logs when entitlements are missing.
        let groupID = "group.com.ryanleewilliams.Bellows"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil else {
            return ComplicationEntry(date: Date(), streak: 0, intensity: 0)
        }
        let defaults = UserDefaults(suiteName: groupID)
        let streak = defaults?.integer(forKey: "complication_streak") ?? 0
        let intensity = defaults?.double(forKey: "complication_intensity") ?? 0
        return ComplicationEntry(date: Date(), streak: streak, intensity: intensity)
    }
}

// A tiny ember shape suitable for small complication sizes
struct MiniEmberShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w*0.20, y: h*0.88))
        p.addLine(to: CGPoint(x: w*0.35, y: h*0.94))
        p.addLine(to: CGPoint(x: w*0.65, y: h*0.90))
        p.addLine(to: CGPoint(x: w*0.80, y: h*0.84))
        p.addLine(to: CGPoint(x: w*0.86, y: h*0.68))
        p.addLine(to: CGPoint(x: w*0.90, y: h*0.50))
        p.addLine(to: CGPoint(x: w*0.86, y: h*0.32))
        p.addLine(to: CGPoint(x: w*0.76, y: h*0.16))
        p.addLine(to: CGPoint(x: w*0.60, y: h*0.10))
        p.addLine(to: CGPoint(x: w*0.45, y: h*0.08))
        p.addLine(to: CGPoint(x: w*0.30, y: h*0.12))
        p.addLine(to: CGPoint(x: w*0.24, y: h*0.22))
        p.addLine(to: CGPoint(x: w*0.16, y: h*0.36))
        p.addLine(to: CGPoint(x: w*0.12, y: h*0.54))
        p.addLine(to: CGPoint(x: w*0.16, y: h*0.74))
        p.closeSubpath()
        return p
    }
}

fileprivate func emberColors(for intensity: Double) -> [Color] {
    if intensity <= 0 { return [.gray.opacity(0.2), .black] }
    switch intensity {
    case ..<0.2: return [Color(red: 0.8, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.05, blue: 0.05), .black]
    case ..<0.4: return [Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.8, green: 0.1, blue: 0.1), .black]
    case ..<0.6: return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.6, green: 0.1, blue: 0.1)]
    case ..<0.8: return [Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.8, green: 0.2, blue: 0.1)]
    default: return [.white, Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.8, green: 0.2, blue: 0.1)]
    }
}

struct ComplicationView: View {
    var entry: ComplicationProvider.Entry
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            // Keep a minimum display intensity so low streaks still feel warm
            let displayIntensity = max(0.25, entry.intensity)
            let colors = emberColors(for: displayIntensity)
            ZStack {
                // Subtle ember outline (no solid fill that can mask text)
                MiniEmberShape()
                    .stroke(Color.white.opacity(0.15), lineWidth: max(1, size * 0.06))
                    .frame(width: size * 0.90, height: size * 0.90)

                // Glow layer (lightens beneath)
                MiniEmberShape()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: colors),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.55
                        )
                    )
                    .opacity(0.15 + displayIntensity * 0.75)
                    .blendMode(.plusLighter)
                    .frame(width: size * 0.90, height: size * 0.90)
                    .compositingGroup()

                // Hot spots when burning hot
                if displayIntensity > 0.55 {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(displayIntensity), .orange.opacity(displayIntensity*0.7), .clear]), center: .center, startRadius: 0, endRadius: size * 0.18))
                        .offset(x: size * 0.10, y: size * -0.06)
                        .blendMode(.plusLighter)
                }
                if displayIntensity > 0.80 {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(displayIntensity*0.8), .yellow.opacity(displayIntensity*0.6), .clear]), center: .center, startRadius: 0, endRadius: size * 0.14))
                        .offset(x: size * -0.08, y: size * 0.10)
                        .blendMode(.plusLighter)
                }

                // Streak text with adaptive coloring
                if renderingMode == .fullColor {
                    ZStack {
                        Text("\(entry.streak)")
                            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.5))
                            .offset(x: 0.7, y: 0.7)
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                        Text("\(entry.streak)")
                            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
                } else {
                    Text("\(entry.streak)")
                        .font(.system(size: size * 0.50, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .widgetAccentable()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "bellows://quickadd")!)
        // Provide a background for the widget to satisfy watchOS/WidgetKit requirements
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct BellowsStreakWidget: Widget {
    let kind: String = "BellowsComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("Bellows Streak")
        .description("Shows your current streak with ember intensity.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct ComplicationWidget_Previews: PreviewProvider {
    static var previews: some View {
        ComplicationView(entry: ComplicationEntry(date: Date(), streak: 12, intensity: 0.8))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
