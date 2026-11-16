import SwiftUI
import UIKit

/// Aegyo's type ramp. Every size in the app is a design size that scales with the user's Dynamic Type setting,
/// so `.aegyo(16)` is `.system(size: 16)` at the default text size and grows (or shrinks) with Settings › Text Size.
extension Font {
    static func aegyo(_ size: CGFloat, _ weight: Font.Weight = .regular, _ design: Font.Design = .default) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.ui)
        let font: UIFont
        if let descriptor = base.fontDescriptor.withDesign(design.ui) {
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = base
        }
        // Scale with the body text style so 16pt tracks the system body size at every setting, capped by the root view.
        return Font(UIFontMetrics(forTextStyle: .body).scaledFont(for: font))
    }

    static func aegyo(_ size: CGFloat, design: Font.Design) -> Font { aegyo(size, .regular, design) }
}

private extension Font.Weight {
    var ui: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

private extension Font.Design {
    var ui: UIFontDescriptor.SystemDesign {
        switch self {
        case .rounded: .rounded
        case .monospaced: .monospaced
        case .serif: .serif
        default: .default
        }
    }
}
