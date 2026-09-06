import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: filterBinding) {
            Section(L.t("Summary")) {
                LabeledContent(L.t("Found"), value: model.totalFound.formattedBytes)
                LabeledContent(L.t("Selected"), value: model.selectedFindings.totalSize.formattedBytes)
                if let free = model.freeSpace {
                    LabeledContent(L.t("Free on disk"), value: free.formattedBytes)
                }
            }
            .font(.callout)

            Section(L.t("Ecosystems")) {
                row(label: L.t("Everything"), symbol: "tray.full", size: model.totalFound, tag: .all)
                ForEach(sortedEcosystems, id: \.0) { eco, size in
                    row(label: L.t(eco.label), symbol: eco.symbol, size: size, tag: .ecosystem(eco))
                }
            }

            if model.globalCacheTotal > 0 {
                Section(L.t("Global caches")) {
                    ForEach(sortedCacheCategories, id: \.0) { category, size in
                        row(label: L.t(category.label), symbol: category.symbol,
                            size: size, tag: .cache(category))
                    }
                }
            }

            Section(L.t("Scanned folders")) {
                ForEach(model.roots, id: \.self) { root in
                    HStack {
                        Label(root.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                        Button(L.t("Remove"), systemImage: "minus.circle") { model.removeRoot(root) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    .help(root.path(percentEncoded: false))
                }
                Button(L.t("Add folder…"), systemImage: "plus") { pickFolder() }
                    .buttonStyle(.borderless)
            }
        }
        .listStyle(.sidebar)
    }

    /// Uma linha de filtro. Toda linha selecionável precisa de uma tag concreta.
    private func row(label: String, symbol: String, size: Int64, tag: Filter) -> some View {
        HStack {
            Label(label, systemImage: symbol)
            Spacer()
            Text(size.formattedBytes)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .tag(tag)
    }

    private var sortedEcosystems: [(Ecosystem, Int64)] {
        model.sizeByEcosystem.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var sortedCacheCategories: [(CacheCategory, Int64)] {
        model.sizeByCacheCategory.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    /// A `List` entrega `nil` ao clicar numa linha já selecionada; nesse caso
    /// mantemos o filtro em vez de cair num estado sem seleção.
    private var filterBinding: Binding<Filter?> {
        Binding(get: { model.filter }, set: { model.filter = $0 ?? .all })
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L.t("Add")
        panel.message = L.t("Choose the folders where your projects live")
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(model.addRoot)
    }
}
