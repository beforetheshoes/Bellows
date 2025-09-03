import Testing
import SwiftUI
@testable import Bellows

@MainActor
struct ThemeAppearanceIndependenceTests {
    @Test func changingAppearanceDoesNotChangeTheme() {
        let manager = ThemeManager.shared
        manager.setTheme(.warm)
        let themeBefore = manager.currentTheme

        manager.setAppearanceMode(.dark)
        #expect(manager.currentTheme == themeBefore)

        manager.setAppearanceMode(.system)
        #expect(manager.currentTheme == themeBefore)
    }

    @Test func dsAccentFollowsThemeNotAppearance() {
        let manager = ThemeManager.shared
        manager.setTheme(.cool)
        manager.setAppearanceMode(.light)
        let accentLight = DS.ColorToken.accent

        manager.setAppearanceMode(.dark)
        let accentDark = DS.ColorToken.accent

        // With the current design, accent is theme-only and should not change with appearance
        #expect(String(describing: accentLight) == String(describing: accentDark))
        #expect(String(describing: accentLight) == String(describing: Theme.cool.accentColor))
    }
}

