import CoreText
import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Colours from the screen designs, with dark-mode counterparts.
enum Theme {
    /// Page ground.
    static let background = Color(light: 0xF5F7FA, dark: 0x0F151C)
    /// Cards and the navigation bar.
    static let card = Color(light: 0xFFFFFF, dark: 0x1A222C)
    /// Text fields inside cards.
    static let field = Color(light: 0xF5F7FA, dark: 0x0F151C)
    /// Primary text.
    static let ink = Color(light: 0x16202B, dark: 0xEEF2F6)
    /// Secondary text and quiet icons.
    static let muted = Color(light: 0x5B6673, dark: 0x9AA6B2)
    /// Selected tab, round + buttons, the Finish button.
    static let accent = Color(light: 0xBFD9F7, dark: 0x2F5482)
    /// Text buttons.
    static let link = Color(light: 0x2A66A8, dark: 0x8DBBF0)
    /// Field and outline-button borders.
    static let border = Color(light: 0x8593A1, dark: 0x5B6673)
    /// Hairlines between rows.
    static let divider = Color(light: 0xE3E8EE, dark: 0x2A3440)
    /// Destructive actions.
    static let danger = Color(light: 0xB3261E, dark: 0xFF8A80)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let pageMargin: CGFloat = 16
}

/// Type from the screen designs: Barlow Condensed for headings and numbers,
/// the system font (in place of Inter) for everything else.
///
/// Barlow Condensed is used when its font files are in the app bundle. Without
/// them the system condensed font stands in.
enum AppFont {
    private static let semibold = "BarlowCondensed-SemiBold"
    private static let bold = "BarlowCondensed-Bold"

    /// Registers any font files shipped in the bundle, so none need listing in Info.plist.
    static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    private static let hasSemibold = UIFont(name: semibold, size: 12) != nil
    private static let hasBold = UIFont(name: bold, size: 12) != nil

    static func display(_ size: CGFloat, bold isBold: Bool = false, relativeTo style: Font.TextStyle = .title2) -> Font {
        if isBold, hasBold {
            return .custom(bold, size: size, relativeTo: style)
        }
        if !isBold, hasSemibold {
            return .custom(semibold, size: size, relativeTo: style)
        }
        let scaled = UIFontMetrics(forTextStyle: .title2).scaledValue(for: size)
        return .system(size: scaled, weight: isBold ? .bold : .semibold).width(.condensed)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
    }
}

extension View {
    /// A white rounded card.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    func hideKeyboard() {
        dismissKeyboard()
    }
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
