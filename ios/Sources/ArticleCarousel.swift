import SwiftUI

@MainActor struct ArticleCarousel: View {
    let articles: [Article]
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @State private var availableWidth: CGFloat = 350
    var body: some View {
        GeometryReader { proxy in
            let side = tileSide(for: proxy.size.width)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(articles) { article in
                        ArticleTile(article: article, side: side)
                    }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .onAppear { availableWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { _, width in availableWidth = width }
        }
        .frame(height: tileSide(for: availableWidth))
    }
    private func tileSide(for width: CGFloat) -> CGFloat {
        // Two complete tiles, two gaps and half of the third tile.
        let base = max(100, (width - 20) / 2.5)
        return min(max(100, width - 24), base * max(1, textScale))
    }
}

@MainActor private struct ArticleTile: View {
    @Environment(\.studyTheme) private var design
    let article: Article
    let side: CGFloat
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var audio: AudioLibraryModel
    @State private var showSave = false
    private var completed: Bool { store.data.progress[article.id]?.completed == true }
    var body: some View {
        NavigationLink { ArticleReader(article: article) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "doc.text")
                        .foregroundStyle(design.accent)
                    Text(article.folder.split(separator: "/").last.map(String.init) ?? article.folder)
                        .foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if store.isFavorite(article.id) {
                        Image(systemName: "bookmark.fill").foregroundStyle(design.violet)
                    }
                }.font(.caption2)
                Text(article.title).font(.footnote.weight(.bold)).foregroundStyle(.primary)
                    .lineLimit(4).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text(article.tags.first.map { "#" + $0 } ?? "").lineLimit(1)
                    Spacer(minLength: 0)
                    if audio.index.tracks.contains(where: { $0.manifest.articleID == article.id }) {
                        Image(systemName: "headphones").accessibilityLabel("音声あり")
                    }
                    if completed { Text("読了") }
                    else if store.data.progress[article.id]?.lastViewedAt != nil { Text("途中") }
                }.font(.caption2).foregroundStyle(design.accent)
            }.padding(10).frame(width: side, height: side, alignment: .topLeading)
                .background { StudyTileSurface() }
                .clipShape(RoundedRectangle(cornerRadius: design.radius))
                .contentShape(RoundedRectangle(cornerRadius: design.radius))
        }.buttonStyle(.plain)
            .contextMenu {
                Button(store.isFavorite(article.id) ? "お気に入りを解除" : "お気に入りに保存", systemImage: "bookmark") {
                    store.toggleFavorite(article.id)
                }
                Button("コレクションに保存", systemImage: "square.stack") { showSave = true }
            }
            .sheet(isPresented: $showSave) { SaveArticleView(article: article) }
    }
}
