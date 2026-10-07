import SwiftUI
import MarkdownUI

// Names and dark palettes follow living-aurora-ui's four visual themes.
enum StudyTheme: String, CaseIterable, Identifiable {
    case aurora = "living-aurora", neon = "pulse-neon", cosmos = "blue-cosmos", classic = "windows-98"
    static let storageKey = "learnleaf.visualTheme"
    var id: String { rawValue }
    static func restored(_ value: String) -> StudyTheme { StudyTheme(rawValue: value) ?? .aurora }
    var title: String {
        switch self {
        case .aurora: return "Living Aurora"
        case .neon: return "Pulse Neon"
        case .cosmos: return "Blue Cosmos"
        case .classic: return "Windows 98"
        }
    }
    var detail: String {
        switch self {
        case .aurora: return "紫とシアンの柔らかな光"
        case .neon: return "緑のシグナルと回路模様"
        case .cosmos: return "青い星雲と静かな星空"
        case .classic: return "青緑のデスクトップと立体的な枠"
        }
    }
    private func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    var accent: Color {
        switch self {
        case .aurora: return adaptive(light: 0x0F6E7A, dark: 0x55DDE0)
        case .neon: return adaptive(light: 0x006B53, dark: 0x45F0C4)
        case .cosmos: return adaptive(light: 0x225BB5, dark: 0x69A7FF)
        case .classic: return adaptive(light: 0x000080, dark: 0x000080)
        }
    }
    var violet: Color {
        switch self {
        case .aurora: return adaptive(light: 0x7A66BA, dark: 0x8B6CFF)
        case .neon: return adaptive(light: 0x245DB0, dark: 0x4388FF)
        case .cosmos: return adaptive(light: 0x576BC0, dark: 0xB5DCFF)
        case .classic: return accent
        }
    }
    var background: Color {
        switch self {
        case .aurora: return adaptive(light: 0xF2F5FA, dark: 0x05070C)
        case .neon: return adaptive(light: 0xEBF5F0, dark: 0x030706)
        case .cosmos: return adaptive(light: 0xEDF3FC, dark: 0x020611)
        case .classic: return adaptive(light: 0x008080, dark: 0x008080)
        }
    }
    var surface: Color {
        switch self {
        case .aurora: return adaptive(light: 0xFFFFFF, dark: 0x0D1220)
        case .neon: return adaptive(light: 0xF7FFFB, dark: 0x071612)
        case .cosmos: return adaptive(light: 0xFAFCFF, dark: 0x070F22)
        case .classic: return adaptive(light: 0xC0C0C0, dark: 0xC0C0C0)
        }
    }
    var readerSurface: Color { self == .classic ? .white : surface }
    var radius: CGFloat {
        switch self { case .aurora: return 18; case .neon: return 10; case .cosmos: return 20; case .classic: return 0 }
    }
    var onAccent: Color { self == .classic ? .white : adaptive(light: 0xFFFFFF, dark: 0x000000) }
    var gradient: LinearGradient { LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

enum StudyAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "learnleaf.appearance"
    var id: String { rawValue }
    var title: String { switch self { case .system: return "端末に合わせる"; case .light: return "ライト"; case .dark: return "ダーク" } }
    var colorScheme: ColorScheme? { switch self { case .system: return nil; case .light: return .light; case .dark: return .dark } }
}

private struct StudyThemeKey: EnvironmentKey { static let defaultValue = StudyTheme.aurora }
extension EnvironmentValues {
    var studyTheme: StudyTheme {
        get { self[StudyThemeKey.self] }
        set { self[StudyThemeKey.self] = newValue }
    }
}

extension StudyTheme {
    var reader: Theme {
        Theme.gitHub
        .text { ForegroundColor(.primary); BackgroundColor(nil); FontSize(16) }
        .link { ForegroundColor(self.accent) }
        .paragraph { c in
            c.label.relativeLineSpacing(.em(0.38)).markdownMargin(top: 0, bottom: 20)
        }
        .heading1 { c in
            c.label.markdownTextStyle { FontWeight(.bold); FontSize(.em(1.5)) }
                .markdownMargin(top: 32, bottom: 16)
        }
        .heading2 { c in
            VStack(alignment: .leading, spacing: 10) {
                c.label.markdownTextStyle { FontWeight(.bold); FontSize(.em(1.3)) }
                RoundedRectangle(cornerRadius: 2).fill(self.gradient).frame(width: 38, height: 3)
            }.markdownMargin(top: 30, bottom: 16)
        }
        .blockquote { c in
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2).fill(self.accent).frame(width: 3)
                c.label
            }.padding(16).background(self.accent.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: self.radius)).markdownMargin(top: 8, bottom: 20)
        }
        .codeBlock { c in
            VStack(alignment: .leading, spacing: 0) {
                if let language = c.language { Text(language.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 12) }
                ScrollView(.horizontal) {
                    c.label.markdownTextStyle { FontFamilyVariant(.monospaced); FontSize(.em(0.85)) }
                        .relativeLineSpacing(.em(0.2)).padding(16)
                }
            }.background(self.accent.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: self.radius))
                .markdownMargin(top: 8, bottom: 20)
        }
        .table { c in
            ScrollView(.horizontal) {
                c.label.markdownTableBorderStyle(.init(color: .secondary.opacity(0.2)))
                    .markdownTableBackgroundStyle(.alternatingRows(self.surface, self.accent.opacity(0.05)))
            }.markdownMargin(top: 8, bottom: 20)
        }
    }
}

struct TagPill: View {
    @Environment(\.studyTheme) private var design
    let text: String
    var selected = false
    var body: some View {
        Text(text).font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(selected ? design.onAccent : design.accent)
            .background(selected ? design.accent : design.accent.opacity(0.09), in: Capsule())
    }
}

// Tags retain their intrinsic width and wrap, including at accessibility text sizes.
struct TagFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 320, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: ProposedViewSize(width: min(subviews[index].sizeThatFits(.unspecified).width, bounds.width), height: nil))
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0; var y: CGFloat = 0; var row: CGFloat = 0; var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: min(view.sizeThatFits(.unspecified).width, width), height: nil))
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; row = max(row, size.height)
        }
        return (CGSize(width: width, height: y + row), points)
    }
}

// Stable seeds avoid star positions changing while navigating or scrolling.
struct StudyBackdrop: View {
    @Environment(\.studyTheme) private var design
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                design.background
                if design != .classic {
                    RadialGradient(colors: [design.violet.opacity(scheme == .dark ? 0.25 : 0.09), .clear], center: .topLeading, startRadius: 0, endRadius: geometry.size.height * 0.75)
                    RadialGradient(colors: [design.accent.opacity(scheme == .dark ? 0.15 : 0.06), .clear], center: .bottomTrailing, startRadius: 0, endRadius: geometry.size.width)
                    Canvas { context, size in
                        if design == .cosmos {
                            var seed: UInt64 = 73
                            func random() -> Double {
                                seed = (seed &* 1664525 &+ 1013904223) % 4294967296
                                return Double(seed) / 4294967296
                            }
                            for index in 0..<240 {
                                let x = random() * size.width, y = random() * size.height
                                let radius = index % 37 == 0 ? 1.4 : 0.35 + random() * 0.55
                                let opacity = 0.2 + random() * 0.65
                                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color((scheme == .dark ? Color.white : design.accent).opacity(opacity)))
                            }
                        } else if design == .neon {
                            for index in 0..<12 {
                                let x = CGFloat(index) * size.width / 11
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(path, with: .color(design.accent.opacity(0.08)), lineWidth: 0.5)
                            }
                            for index in 0..<10 {
                                let y = CGFloat(index) * size.height / 9
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(path, with: .color(design.violet.opacity(0.05)), lineWidth: 0.5)
                                context.fill(Path(ellipseIn: CGRect(x: size.width * 0.73, y: y - 2, width: 4, height: 4)), with: .color(design.accent.opacity(0.45)))
                            }
                        }
                    }
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct StudyTileSurface: View {
    @Environment(\.studyTheme) private var design
    @Environment(\.accessibilityReduceTransparency) private var opaque
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        RoundedRectangle(cornerRadius: design.radius).fill(design.surface)
            .overlay {
                if design == .classic {
                    GeometryReader { geometry in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geometry.size.height))
                            path.addLine(to: .zero); path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                        }.stroke(.white, lineWidth: 3)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                        }.stroke(Color.black.opacity(0.7), lineWidth: 3)
                    }
                } else {
                    if !opaque {
                        RoundedRectangle(cornerRadius: design.radius)
                            .fill(LinearGradient(colors: [design.violet.opacity(0.12), .clear, design.accent.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    RoundedRectangle(cornerRadius: design.radius).strokeBorder(
                        LinearGradient(colors: [design.violet.opacity(contrast == .increased ? 0.7 : 0.3), design.accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: contrast == .increased ? 1.5 : 0.5)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ThemeSettingsView: View {
    @AppStorage(StudyTheme.storageKey) private var selected = StudyTheme.aurora.rawValue
    @AppStorage(StudyAppearance.storageKey) private var appearance = StudyAppearance.system.rawValue
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("表示モード").font(.subheadline.weight(.semibold))
                    Picker("表示モード", selection: $appearance) {
                        ForEach(StudyAppearance.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
                    }.pickerStyle(.segmented)
                    Text("プレビューは各テーマの標準色です。Windows 98はクラシックな明るい表示を使います。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).background { StudyTileSurface() }
                ForEach(StudyTheme.allCases) { theme in
                    Button { selected = theme.rawValue } label: {
                        ZStack {
                            StudyBackdrop()
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(theme.title).font(.headline)
                                    Spacer()
                                    if StudyTheme.restored(selected) == theme { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent) }
                                }
                                Text(theme.detail).font(.footnote)
                                HStack {
                                    Image(systemName: "books.vertical").foregroundStyle(theme.accent)
                                    Text("Learnleaf").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: "play.fill").foregroundStyle(theme.accent)
                                }.padding(14).background { StudyTileSurface() }
                            }.padding(20)
                        }.frame(minHeight: 170).clipShape(RoundedRectangle(cornerRadius: theme.radius))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    .environment(\.studyTheme, theme)
                    .environment(\.colorScheme, theme == .classic ? .light : .dark)
                    .accessibilityLabel(theme.title + "、" + theme.detail)
                    .accessibilityAddTraits(StudyTheme.restored(selected) == theme ? .isSelected : [])
                }
            }.padding(20)
        }.navigationTitle("テーマ").navigationBarTitleDisplayMode(.inline)
        .background { StudyBackdrop() }
    }
}
