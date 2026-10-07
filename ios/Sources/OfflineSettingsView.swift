import SwiftUI

@MainActor struct OfflineSettingsView: View {
    @EnvironmentObject private var library: Library
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section("端末に保存") {
                Text("最新一覧の保存記事: \(library.offlineIDs.count) / \(library.articles.count)")
                Text(ByteCountFormatter.string(fromByteCount: library.offlineBytes, countStyle: .file))
                Text("開いた記事を自動保存します。保存済みの本文は通信なしで読めます。音声は従来どおり端末内に保存されています。").font(.caption)
                if library.downloading {
                    ProgressView("\(library.downloaded)記事確認 · 取得失敗\(library.downloadFailures)件")
                    Button("取得を取消") { library.cancelDownload() }
                } else {
                    Button("一覧の全記事を保存") { library.downloadAll() }.disabled(library.articles.isEmpty)
                    if library.downloaded > 0 { Text("\(library.downloaded)記事確認 · 取得失敗\(library.downloadFailures)件").font(.caption) }
                }
                if let message = library.offlineMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                if library.offlineCatalog { Text("保存した記事一覧を使用中です。最新状態は通信復帰後に更新してください。").font(.caption) }
            }
            Section {
                Button("保存記事を削除", role: .destructive) { confirmDelete = true }.disabled(library.downloading)
                Text("学習記録・お気に入り・コレクション・音声は保持されます。").font(.caption)
            }
        }.navigationTitle("オフライン記事")
            .scrollContentBackground(.hidden).background { StudyBackdrop() }
            .task { await library.updateOfflineSummary() }
            .confirmationDialog("保存記事を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("保存記事を削除", role: .destructive) { Task { await library.removeOffline() } }
            }
    }
}
