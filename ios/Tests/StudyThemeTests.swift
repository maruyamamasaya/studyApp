import XCTest
import SwiftUI
@testable import StudyApp

final class StudyThemeTests: XCTestCase {
    func testAllSourceThemesRestoreAndUnknownValueFallsBack() {
        XCTAssertEqual(StudyTheme.allCases.map(\.rawValue), ["living-aurora", "pulse-neon", "blue-cosmos", "windows-98"])
        for theme in StudyTheme.allCases { XCTAssertEqual(StudyTheme.restored(theme.rawValue), theme) }
        XCTAssertEqual(StudyTheme.restored("removed-theme"), .aurora)
        XCTAssertEqual(StudyTheme.restored(""), .aurora)
    }

    func testAccentAndButtonLabelsRemainReadableInBothAppearances() {
        for theme in StudyTheme.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let accent = UIColor(theme.accent).resolvedColor(with: traits)
                let surface = UIColor(theme.surface).resolvedColor(with: traits)
                let label = UIColor(theme.onAccent).resolvedColor(with: traits)
                XCTAssertGreaterThanOrEqual(contrast(accent, surface), 4.5, "\(theme.title), \(style): link")
                XCTAssertGreaterThanOrEqual(contrast(accent, label), 4.5, "\(theme.title), \(style): button")
            }
        }
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &alpha)
            func linear(_ value: CGFloat) -> Double {
                let x = Double(value)
                return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
            }
            return linear(r) * 0.2126 + linear(g) * 0.7152 + linear(b) * 0.0722
        }
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
