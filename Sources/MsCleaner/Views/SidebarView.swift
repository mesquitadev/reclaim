import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: filterBinding) {
            Section("Resumo") {
                LabeledContent("Encontrado", value: model.totalFound.formattedBytes)
                LabeledContent("Marcado", value: model.selectedFindings.totalSize.formattedBytes)
                if let free = model.freeSpace {
                    LabeledContent("Livre no disco", value: free.formattedBytes)
                }
            }
            .font(.callout)

            Section("Ecossistemas") {
                Label("Tudo", systemImage: "tray.full")
                    .tag(Ecosystem?.none)
                ForEach(sortedEcosystems, id: \.0) { eco, size in
                    HStack {
                        Label(eco.label, systemImage: eco.symbol)
                        Spacer()
                        Text(size.formattedBytes)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(Ecosystem?.some(eco))
                }
            }

            if model.globalCacheTotal > 0 {
                Section("Caches globais") {
                    LabeledContent("Ferramentas", value: model.globalCacheTotal.formattedBytes)
                        .font(.callout)
                }
            }

            Section("Pastas escaneadas") {
                ForEach(model.roots, id: \.self) { root in
                    HStack {
                        Label(root.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                        Button("Remover", systemImage: "minus.circle") { model.removeRoot(root) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    .help(root.path(percentEncoded: false))
                }
                Button("Adicionar pasta…", systemImage: "plus") { pickFolder() }
                    .buttonStyle(.borderless)
            }
        }
        .listStyle(.sidebar)
    }

    private var sortedEcosystems: [(Ecosystem, Int64)] {
        model.sizeByEcosystem.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var filterBinding: Binding<Ecosystem?> {
        Binding(get: { model.filter }, set: { model.filter = $0 })
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Adicionar"
        panel.message = "Escolha as pastas onde seus projetos ficam"
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(model.addRoot)
    }
}
