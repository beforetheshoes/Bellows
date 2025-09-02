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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var emberIntensity: Double {
        return Analytics.enhancedEmberIntensity(streak: streak, days: days)
    }

    private var emberColors: [Color] {
        if streak == 0 {
            return [.gray.opacity(0.2), .black]
        }
        
        let intensity = emberIntensity
        if intensity < 0.2 {
            // Just starting to glow - dark red
            return [Color(red: 0.8, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.05, blue: 0.05), .black]
        } else if intensity < 0.4 {
            // Getting warmer - red to orange
            return [Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.8, green: 0.1, blue: 0.1), .black]
        } else if intensity < 0.6 {
            // Hot - orange dominant
            return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.6, green: 0.1, blue: 0.1)]
        } else if intensity < 0.8 {
            // Very hot - orange to yellow
            return [Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.8, green: 0.2, blue: 0.1)]
        } else {
            // Extremely hot - white hot
            return [.white, Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.8, green: 0.2, blue: 0.1)]
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

            HStack(spacing: 0) {
                emberView
                    .frame(maxWidth: .infinity)
                
                textContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)

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
                
                // More dramatic ember flare on streak increase
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.6)) {
                        emberPulse = 1.5
                        emberGlow = 1.5
                        innerGlow = 1.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
            emberText
        }
        .frame(maxWidth: .infinity)
    }
    
    private var particleEffects: some View {
        Group {
            if streak > 0 {
                ForEach(0..<Int(emberIntensity * 10 + 3), id: \.self) { i in
                    let xOffset = CGFloat(cos(Double(i) * 0.8 + particleFloat) * (28 + Double(i * 4)))
                    let yOffset = CGFloat(sin(Double(i) * 1.2 + particleFloat) * (22 + Double(i * 3))) - CGFloat(particleFloat * 28)
                    
                    Circle()
                        .fill(emberColors[i % emberColors.count])
                        .frame(width: CGFloat(3 + i), height: CGFloat(3 + i))
                        .offset(x: xOffset, y: yOffset)
                        .opacity(0.7 - Double(i) * 0.04)
                        .blur(radius: 1.5)
                }
            }
        }
    }
    
    private var mainEmberShape: some View {
        ZStack {
            // Black base ember (the coal/charcoal base)
            EmberShape()
                .fill(.black)
                .frame(width: 140, height: 168)
            
            // Glowing hot spots based on intensity
            if emberIntensity > 0 {
                let glowGradient = RadialGradient(
                    colors: emberColors,
                    center: UnitPoint(x: 0.5, y: 0.8),
                    startRadius: 0,
                    endRadius: 60
                )
                
                EmberShape()
                    .fill(glowGradient)
                    .frame(width: 140, height: 168)
                    .opacity(emberIntensity * 0.9 + 0.1)
                    .blendMode(.screen)
            }
            
            // Additional hot spots for higher intensity
            if emberIntensity > 0.3 {
                let hotSpotGradient = RadialGradient(
                    colors: [.white.opacity(emberIntensity), .orange.opacity(emberIntensity * 0.8), .clear],
                    center: UnitPoint(x: 0.4, y: 0.7),
                    startRadius: 0,
                    endRadius: 25
                )
                
                Circle()
                    .fill(hotSpotGradient)
                    .frame(width: 30, height: 30)
                    .offset(x: -10, y: 10)
                    .blendMode(.screen)
            }
            
            if emberIntensity > 0.6 {
                let hotSpot2Gradient = RadialGradient(
                    colors: [.white.opacity(emberIntensity * 0.8), .yellow.opacity(emberIntensity * 0.6), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 20
                )
                
                Circle()
                    .fill(hotSpot2Gradient)
                    .frame(width: 25, height: 25)
                    .offset(x: 8, y: -5)
                    .blendMode(.screen)
            }
        }
        .scaleEffect(emberPulse)
        .shadow(color: emberColors.first?.opacity(emberGlow * 0.8) ?? .clear, radius: emberGlow * 15)
        .shadow(color: .orange.opacity(emberGlow * 0.4), radius: emberGlow * 25)
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
                    .frame(width: 105, height: 126)
                    .scaleEffect(emberPulse * 0.8)
                    .blur(radius: 2)
            }
        }
    }
    
    private var emberText: some View {
        VStack(spacing: 4) {
            Text("\(streak)")
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(streak == 0 ? Color.secondary : Color.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            Text("DAYS")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(streak == 0 ? Color.secondary : Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
        }
        .scaleEffect(emberPulse)
    }
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streak")
                .font(.largeTitle)
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
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Light the flame")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func startEmberAnimations() {
        let intensity = emberIntensity
        
        // Respect accessibility settings but make animations more visible
        guard !reduceMotion else {
            emberGlow = intensity * 0.5 + 0.2
            emberPulse = 1.0 + (intensity * 0.1)
            innerGlow = intensity * 0.4
            return
        }
        
        // Enhanced base glow - more noticeable on all platforms
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            emberGlow = intensity * 1.0 + 0.3
        }
        
        // More pronounced pulsing ember
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            emberPulse = 1.0 + (intensity * 0.2)
        }
        
        // Brighter inner glow
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            innerGlow = intensity * 0.8
        }
        
        // More active floating particles
        if streak > 0 {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                particleFloat += 2 * .pi
            }
        }
    }
}

// Realistic ember shape with black base
struct EmberShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create more angular, coal-like ember shape
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.9)) // Bottom left
        
        // Bottom edge (irregular)
        path.addLine(to: CGPoint(x: width * 0.35, y: height * 0.95))
        path.addLine(to: CGPoint(x: width * 0.65, y: height * 0.92))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.87))
        
        // Right edge
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.7))
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.3))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.15))
        
        // Top edge (more irregular)
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.08))
        path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.05))
        path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.1))
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.2))
        
        // Left edge
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.35))
        path.addLine(to: CGPoint(x: width * 0.1, y: height * 0.55))
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.75))
        
        path.closeSubpath()
        
        return path
    }
}
