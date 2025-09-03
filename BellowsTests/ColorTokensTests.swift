import Testing
import SwiftUI
@testable import Bellows

@MainActor
struct ColorTokensTests {
    @Test func accentMatchesTheme() {
        let manager = ThemeManager.shared
        for theme in Theme.allCases {
            manager.setTheme(theme)
            let accent = DS.ColorToken.accent
            #expect(String(describing: accent) == String(describing: theme.accentColor))
        }
    }

    @Test func cardExistsAcrossAppearances() {
        let manager = ThemeManager.shared
        for mode in AppearanceMode.allCases {
            manager.setAppearanceMode(mode)
            let card = DS.ColorToken.card
            #expect(!String(describing: card).isEmpty)
        }
    }
}

