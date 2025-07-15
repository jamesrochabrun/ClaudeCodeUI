//import SwiftUI
//import Observation
//
//@Observable
//@MainActor
//final class ThemeManager {
//    private var appearanceSettings: AppearanceSettings?
//    
//    var currentTheme: Theme {
//        guard let themeId = appearanceSettings?.themeId,
//              let theme = Theme.theme(withId: themeId) else {
//            // Fallback to saved theme or default
//            let savedThemeId = UserDefaults.standard.string(forKey: "themeId") ?? "anthropic"
//            return Theme.theme(withId: savedThemeId) ?? Theme.anthropic
//        }
//        return theme
//    }
//    
//    init() {
//        // Simple init, no need to load theme here as computed property handles it
//    }
//    
//    func configure(with appearanceSettings: AppearanceSettings) {
//        self.appearanceSettings = appearanceSettings
//    }
//    
//    // Convert theme colors to SwiftUI Colors
//    func color(for keyPath: KeyPath<Theme.ThemeColors, String>) -> Color {
//        Color(hex: currentTheme.colors[keyPath: keyPath])
//    }
//    
//    // Convenience accessors
//    var primary: Color { color(for: \.primary) }
//    var secondary: Color { color(for: \.secondary) }
//    var tertiary: Color { color(for: \.tertiary) }
//    var background: Color { color(for: \.background) }
//    var secondaryBackground: Color { color(for: \.secondaryBackground) }
//    var tertiaryBackground: Color { color(for: \.tertiaryBackground) }
//    var primaryText: Color { color(for: \.primaryText) }
//    var secondaryText: Color { color(for: \.secondaryText) }
//    var tertiaryText: Color { color(for: \.tertiaryText) }
//    var accent: Color { color(for: \.accent) }
//    var accentSecondary: Color { color(for: \.accentSecondary) }
//    var success: Color { color(for: \.success) }
//    var warning: Color { color(for: \.warning) }
//    var error: Color { color(for: \.error) }
//    var info: Color { color(for: \.info) }
//    var border: Color { color(for: \.border) }
//    var divider: Color { color(for: \.divider) }
//    var shadow: Color { color(for: \.shadow) }
//    var codeBackground: Color { color(for: \.codeBackground) }
//    var codeText: Color { color(for: \.codeText) }
//    var link: Color { color(for: \.link) }
//    var selection: Color { color(for: \.selection) }
//}
