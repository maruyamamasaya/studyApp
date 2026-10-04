import SwiftUI
import MarkdownUI

enum StudyDesign {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.76, blue: 0.91, alpha: 1)
            : UIColor(red: 0.19, green: 0.43, blue: 0.64, alpha: 1)
    })
    static let violet = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.64, blue: 0.95, alpha: 1)
            : UIColor(red: 0.48, green: 0.40, blue: 0.73, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let gradient = LinearGradient(colors: [Color(red: 0.19, green: 0.43, blue: 0.64), Color(red: 0.48, green: 0.40, blue: 0.73)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let reader = Theme.gitHub
        .text { ForegroundColor(.primary); BackgroundColor(nil); FontSize(16) }
        .link { ForegroundColor(StudyDesign.accent) }
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
                RoundedRectangle(cornerRadius: 2).fill(StudyDesign.gradient).frame(width: 38, height: 3)
            }.markdownMargin(top: 30, bottom: 16)
        }
        .blockquote { c in
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2).fill(StudyDesign.accent).frame(width: 3)
                c.label
            }.padding(16).background(StudyDesign.accent.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12)).markdownMargin(top: 8, bottom: 20)
        }
        .codeBlock { c in
            VStack(alignment: .leading, spacing: 0) {
                if let language = c.language { Text(language.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 12) }
                ScrollView(.horizontal) {
                    c.label.markdownTextStyle { FontFamilyVariant(.monospaced); FontSize(.em(0.85)) }
                        .relativeLineSpacing(.em(0.2)).padding(16)
                }
            }.background(Color(uiColor: .tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 14))
                .markdownMargin(top: 8, bottom: 20)
        }
        .table { c in
            ScrollView(.horizontal) {
                c.label.markdownTableBorderStyle(.init(color: .secondary.opacity(0.2)))
                    .markdownTableBackgroundStyle(.alternatingRows(StudyDesign.surface, StudyDesign.accent.opacity(0.05)))
            }.markdownMargin(top: 8, bottom: 20)
        }
}

struct TagPill: View {
    let text: String
    var selected = false
    var body: some View {
        Text(text).font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(selected ? Color.white : StudyDesign.accent)
            .background(selected ? StudyDesign.accent : StudyDesign.accent.opacity(0.09), in: Capsule())
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
