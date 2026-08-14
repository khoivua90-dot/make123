import SwiftUI

struct OnlinePatchLibraryView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore

    @State private var items: [RemotePatchSummary] = []
    @State private var isLoading = true
    @State private var downloadingID: String?
    @State private var errorMessageKey: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessageKey {
                    Section {
                        Label(language.text(errorMessageKey), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if items.isEmpty {
                    Section {
                        Text(language.text("patch.online_empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                }
            }
            .navigationTitle(language.text("patch.online_library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || downloadingID != nil)
                }
            }
            .task { await load() }
        }
    }

    private func row(_ item: RemotePatchSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if downloadingID == item.id {
                ProgressView()
            } else {
                Button {
                    Task { await download(item) }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(downloadingID != nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        errorMessageKey = nil
        do {
            items = try await PatchHubService.fetchPatches()
        } catch {
            errorMessageKey = "patch.online_load_failed"
        }
        isLoading = false
    }

    private func download(_ item: RemotePatchSummary) async {
        downloadingID = item.id
        errorMessageKey = nil
        do {
            let fileURL = try await PatchHubService.downloadPatch(item)
            store.importPackage(at: fileURL)
            dismiss()
        } catch {
            errorMessageKey = "patch.online_download_failed"
        }
        downloadingID = nil
    }
}
