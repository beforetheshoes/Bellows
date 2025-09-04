import SwiftUI
import Observation

// Cross‑platform system colors helpers
private extension Color {
#if os(iOS) || os(tvOS) || os(watchOS)
    static var systemBackgroundCompat: Color { Color(uiColor: .systemBackground) }
    static var secondarySystemBackgroundCompat: Color { Color(uiColor: .secondarySystemBackground) }
    static var separatorCompat: Color { Color(uiColor: .separator) }
#elseif os(macOS)
    static var systemBackgroundCompat: Color { Color(nsColor: .windowBackgroundColor) }
    static var secondarySystemBackgroundCompat: Color { Color(nsColor: .underPageBackgroundColor) }
    static var separatorCompat: Color { Color(nsColor: .separatorColor) }
#endif
}

import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case sepia = "sepia"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .sepia:
            return "Sepia"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .sepia:
            return .light  // Sepia uses light mode as base
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .system, .light, .dark:
            return Color.clear  // Use system defaults
        case .sepia:
            return Color(red: 0.96, green: 0.92, blue: 0.84)  // Warm sepia background
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch self {
        case .system, .light, .dark:
            return Color.clear  // Use system defaults
        case .sepia:
            // Slightly lighter sepia card to reduce heaviness
            return Color(red: 0.95, green: 0.91, blue: 0.82)
        }
    }
}

// MARK: - Theme Model

enum Theme: String, CaseIterable {
    case classic = "classic"
    case warm = "warm"
    case cool = "cool"
    case vibrant = "vibrant"
    
    var displayName: String {
        switch self {
        case .classic:
            return "Classic"
        case .warm:
            return "Warm"
        case .cool:
            return "Cool"
        case .vibrant:
            return "Vibrant"
        }
    }
    
    // Base accent used for tests and static references
    var accentColor: Color {
        switch self {
        case .classic:
            return .accentColor
        case .warm:
            return .orange
        case .cool:
            return .blue
        case .vibrant:
            return .pink
        }
    }
    
    func accentColor(for appearanceMode: AppearanceMode) -> Color {
        let isDarkMode = appearanceMode.colorScheme == .dark
        
        switch self {
        case .classic:
            return .accentColor
        case .warm:
            return isDarkMode ? .red : .orange  // Light accent for dark, dark accent for light/sepia
        case .cool:
            return .blue  // Use darkest blue consistently across all modes
        case .vibrant:
            return isDarkMode ? .pink : .purple // Light accent for dark, dark accent for light/sepia
        }
    }
    
    var gradientStart: Color {
        switch self {
        case .classic:
            return .blue
        case .warm:
            return .orange
        case .cool:
            return .cyan
        case .vibrant:
            return .purple
        }
    }
    
    var gradientEnd: Color {
        switch self {
        case .classic:
            return .purple
        case .warm:
            return .red
        case .cool:
            return .blue
        case .vibrant:
            return .pink
        }
    }
}

// MARK: - Theme Manager

@MainActor
@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    @ObservationIgnored @AppStorage("selectedTheme") private var storedTheme: String = Theme.classic.rawValue
    @ObservationIgnored @AppStorage("selectedAppearanceMode") private var storedAppearanceMode: String = AppearanceMode.system.rawValue
    
    var currentTheme: Theme = .classic
    var currentAppearanceMode: AppearanceMode = .system
    
    private init() {
        // Load theme from stored value
        if let theme = Theme(rawValue: storedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .classic
        }
        
        // Load appearance mode from stored value
        if let appearanceMode = AppearanceMode(rawValue: storedAppearanceMode) {
            self.currentAppearanceMode = appearanceMode
        } else {
            self.currentAppearanceMode = .system
        }
    }
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        storedTheme = theme.rawValue
    }
    
    func setAppearanceMode(_ appearanceMode: AppearanceMode) {
        currentAppearanceMode = appearanceMode
        storedAppearanceMode = appearanceMode.rawValue
    }
}

// MARK: - Design System

enum DS {
    enum ColorToken {
        // Appearance-aware background colors
        @MainActor
        static var background: Color {
            let appearanceMode = ThemeManager.shared.currentAppearanceMode
            return appearanceMode.backgroundColor != .clear ? appearanceMode.backgroundColor : Color.systemBackgroundCompat
        }
        
        @MainActor
        static var card: Color {
            let appearanceMode = ThemeManager.shared.currentAppearanceMode
            // Use custom card color for Sepia; otherwise prefer platform dynamic
            if appearanceMode.secondaryBackgroundColor != .clear {
                return appearanceMode.secondaryBackgroundColor
            }
            #if os(iOS) || os(tvOS) || os(watchOS)
            // systemGray6 provides a lighter card in light/sepia and adapts in dark
            return Color(uiColor: .systemGray6)
            #elseif os(macOS)
            // Slightly lighter container background that adapts to light/dark
            return Color(nsColor: .controlBackgroundColor)
            #else
            return Color.secondarySystemBackgroundCompat
            #endif
        }
        
        static let secondaryText = Color.secondary
        static let separator = Color.separatorCompat
        
        // Theme-aware colors
        @MainActor
        static var accent: Color {
            let themeManager = ThemeManager.shared
            // Theme color should be independent of appearance selection
            return themeManager.currentTheme.accentColor
        }
        
        @MainActor
        static var gradientStart: Color {
            ThemeManager.shared.currentTheme.gradientStart
        }
        
        @MainActor
        static var gradientEnd: Color {
            ThemeManager.shared.currentTheme.gradientEnd
        }
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 14
        static let spacing: CGFloat = 16
        static let chipCorner: CGFloat = 10
        static let contentMaxWidth: CGFloat = 720
    }

    enum FontToken {
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let largeNumber = Font.system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
        static let cardTitle = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)
    }
}

// MARK: - Reusable SectionCard container

@MainActor
struct SectionCard<Content: View>: View {
    private var themeManager = ThemeManager.shared
    private let content: Content
    private let cornerRadius: CGFloat
    private let vPad: CGFloat
    private let hPad: CGFloat

    init(cornerRadius: CGFloat = DS.Metrics.cornerRadius,
         vPad: CGFloat = 12,
         hPad: CGFloat = 16,
         @ViewBuilder _ content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.vPad = vPad
        self.hPad = hPad
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.ColorToken.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.ColorToken.accent, lineWidth: 1)
            )
            .id("\(themeManager.currentTheme.rawValue)-\(themeManager.currentAppearanceMode.rawValue)")
    }
}
