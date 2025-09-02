import SwiftUI

@MainActor
struct StreakHeaderView: View {
    let streak: Int
    let days: [DayLog]

    @State private var rotate = false
    @State private var lastStreak: Int = 0
    @State private var showConfetti = false
    @State private var emberGlow: Double = 0.0
    @State private var emberPulse: CGFloat = 1.0
    @State private var particleFloat: Double = 0.0
    @State private var innerGlow: Double = 0.0

    private var emberIntensity: Double {
        return Analytics.enhancedEmberIntensity(streak: streak, days: days)
    }

    private var emberColors: [Color] {
        if streak == 0 {
            return [.gray.opacity(0.3), .gray.opacity(0.6)]
        }
        
        let intensity = emberIntensity
        if intensity < 0.2 {
            return [.orange.opacity(0.4), .red.opacity(0.3)]
        } else if intensity < 0.5 {
            return [.orange, .red.opacity(0.8), .yellow.opacity(0.6)]
        } else if intensity < 0.8 {
            return [.yellow, .orange, .red]
        } else {
            return [.white, .yellow, .orange, .red]
        }
    }

    private var milestoneText: String {
        if streak >= 365 { return "Year of Fire" }
        if streak >= 100 { return "Blazing Century" }
        if streak >= 30 { return "Burning Bright" }
        if streak >= 7 { return "Week of Flame" }
        return ""
    }

    private var shouldShowMilestone: Bool {
        streak > 0 && (streak % 7 == 0 || streak % 30 == 0 || streak % 100 == 0 || streak >= 365)
    }

    var body: some View {
        ZStack {
            // Background with subtle ember glow
            backgroundView

            HStack(spacing: 20) {
                emberView
                textContent
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            if showConfetti { 
                ConfettiBurst(trigger: streak)
                    .transition(.asymmetric(insertion: .scale, removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            lastStreak = streak
            startEmberAnimations()
        }
        .onChange(of: streak) { _, newValue in
            if newValue > lastStreak {
                lastStreak = newValue
                showConfetti = true
                
                // Dramatic ember flare on streak increase
                withAnimation(.easeOut(duration: 0.8)) {
                    emberPulse = 1.3
                    emberGlow = 1.0
                    innerGlow = 0.8
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    startEmberAnimations()
                    showConfetti = false
                }
            } else {
                startEmberAnimations()
            }
        }
    }
    
    private var backgroundView: some View {
        let gradientColors = streak > 0 ? [emberColors.first?.opacity(0.1) ?? .clear, .clear] : [.clear]
        
        return RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: gradientColors,
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            )
    }
    
    private var emberView: some View {
        ZStack {
            particleEffects
            mainEmberShape
            innerGlowShape
            emberText
        }
    }
    
    private var particleEffects: some View {
        Group {
            if streak > 0 {
                ForEach(0..<Int(emberIntensity * 8 + 2), id: \.self) { i in
                    let xOffset = CGFloat(cos(Double(i) * 0.8 + particleFloat) * (20 + Double(i * 3)))
                    let yOffset = CGFloat(sin(Double(i) * 1.2 + particleFloat) * (15 + Double(i * 2))) - CGFloat(particleFloat * 20)
                    
                    Circle()
                        .fill(emberColors[i % emberColors.count])
                        .frame(width: CGFloat(2 + i), height: CGFloat(2 + i))
                        .offset(x: xOffset, y: yOffset)
                        .opacity(0.6 - Double(i) * 0.05)
                        .blur(radius: 1)
                }
            }
        }
    }
    
    private var mainEmberShape: some View {
        let emberGradient = RadialGradient(
            colors: emberColors,
            center: UnitPoint(x: 0.5, y: 0.7),
            startRadius: 5,
            endRadius: 50
        )
        let shadowColor = emberColors.first?.opacity(emberGlow) ?? .clear
        let shadowColor2 = emberColors.first?.opacity(emberGlow * 0.5) ?? .clear
        
        return EmberShape()
            .fill(emberGradient)
            .frame(width: 80, height: 96)
            .scaleEffect(emberPulse)
            .shadow(color: shadowColor, radius: emberGlow * 20)
            .shadow(color: shadowColor2, radius: emberGlow * 35)
    }
    
    private var innerGlowShape: some View {
        Group {
            if streak > 0 {
                let innerGradient = LinearGradient(
                    colors: [.white.opacity(innerGlow), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                EmberShape()
                    .fill(innerGradient)
                    .frame(width: 60, height: 72)
                    .scaleEffect(emberPulse * 0.8)
                    .blur(radius: 2)
            }
        }
    }
    
    private var emberText: some View {
        VStack(spacing: 2) {
            Text("\(streak)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(streak == 0 ? Color.secondary : Color.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            Text("DAYS")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(streak == 0 ? Color.secondary : Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
        }
        .scaleEffect(emberPulse)
    }
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streak")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if shouldShowMilestone && !milestoneText.isEmpty {
                let milestoneGradient = LinearGradient(
                    colors: emberColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                Text(milestoneText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(milestoneGradient)
                    .transition(.scale.combined(with: .opacity))
            } else if streak > 0 {
                Text("Keep it burning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Light the flame")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func startEmberAnimations() {
        let intensity = emberIntensity
        
        // Base glow based on intensity
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            emberGlow = intensity * 0.8 + 0.1
        }
        
        // Pulsing ember
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            emberPulse = 1.0 + (intensity * 0.15)
        }
        
        // Inner glow
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            innerGlow = intensity * 0.6
        }
        
        // Floating particles
        if streak > 0 {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                particleFloat += 2 * .pi
            }
        }
    }
}

// Custom ember shape
struct EmberShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create teardrop/flame shape
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.05)) // Top point
        
        // Right curve
        path.addQuadCurve(
            to: CGPoint(x: width * 0.85, y: height * 0.4),
            control: CGPoint(x: width * 0.75, y: height * 0.15)
        )
        
        path.addQuadCurve(
            to: CGPoint(x: width * 0.7, y: height * 0.8),
            control: CGPoint(x: width * 0.95, y: height * 0.6)
        )
        
        // Bottom curve
        path.addQuadCurve(
            to: CGPoint(x: width * 0.3, y: height * 0.8),
            control: CGPoint(x: width * 0.5, y: height * 0.95)
        )
        
        // Left curve
        path.addQuadCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.4),
            control: CGPoint(x: width * 0.05, y: height * 0.6)
        )
        
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.05),
            control: CGPoint(x: width * 0.25, y: height * 0.15)
        )
        
        return path
    }
}
