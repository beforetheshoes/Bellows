import SwiftUI

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

enum DS {
    enum ColorToken {
        static let background = Color.systemBackgroundCompat
        static let card = Color.secondarySystemBackgroundCompat
        static let accent = Color.accentColor
        static let secondaryText = Color.secondary
        static let separator = Color.separatorCompat
        static let gradientStart = Color.blue
        static let gradientEnd = Color.purple
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
