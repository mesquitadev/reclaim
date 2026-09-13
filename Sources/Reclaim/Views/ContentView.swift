import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    @Environment(FileModel.self) private var files
    @Environment(AppsModel.self) private var apps

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ToolPicker()
                Divider()
                // A barra lateral de ecossistemas só faz sentido para projetos;
                // nas ferramentas de arquivos ela seria uma coluna vazia.
                if model.tool == .development {
                    SidebarView()
                } else if model.tool == .apps {
                    // A desinstalação lista os apps na própria tela; uma coluna
                    // de raízes aqui não teria o que mostrar.
                    AppsSummary()
                } else {
                    FileRootsList()
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            switch model.tool {
            case .development:
                // A barra de ação precisa ficar no mesmo nível da lista: aplicada
                // no NavigationSplitView, ela cobria a última linha em vez de
                // reservar espaço no fim da rolagem.
                FindingsView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { ActionBar() }
            case .duplicates, .large, .junk:
                FilesView(tool: model.tool)
            case .apps:
                AppsView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { UninstallBar() }
            }
        }
        .toolbar { toolbar }
        // Um `.searchable` por janela. Duas telas declarando o seu faziam o
        // AppKit receber dois itens com o mesmo identificador na toolbar ao
        // trocar de aba, e a exceção derruba o app inteiro.
        .searchable(text: searchBinding, placement: .toolbar, prompt: Text(searchPrompt))
        // As ferramentas de arquivos varrem, por padrão, as mesmas pastas em que
        // o app procura projetos — é onde o trabalho acontece.
        .onAppear { files.projectRoots = model.roots }
        .onChange(of: model.roots) { _, roots in files.projectRoots = roots }
        .sheet(isPresented: resultBinding) { ResultSheet() }
        .sheet(isPresented: .constant(model.phase == .cleaning)) { CleaningSheet() }
    }

    /// A busca escreve no modelo da aba ativa: projetos e arquivos filtram
    /// listas diferentes.
    private var searchBinding: Binding<String> {
        switch model.tool {
        case .development: Binding(get: { model.search }, set: { model.search = $0 })
        case .apps: Binding(get: { apps.search }, set: { apps.search = $0 })
        default: Binding(get: { files.search }, set: { files.search = $0 })
        }
    }

    private var searchPrompt: String {
        switch model.tool {
        case .development: L.t("Filter by project or path")
        case .apps: L.t("Filter by name or identifier")
        default: L.t("Filter by name or folder")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // A desinstalação lista apps, não achados de varredura: varrer,
        // agrupar por projeto e selecionar em massa não significam nada aqui.
        ToolbarItem(placement: .primaryAction) {
            if model.tool == .apps {
                Button(L.t("Rescan"), systemImage: "arrow.clockwise") { apps.scan() }
                    .disabled(apps.isScanning)
            } else if model.phase == .scanning {
                Button(L.t("Stop"), systemImage: "stop.fill") { model.cancel() }
            } else {
                Button(L.t("Scan"), systemImage: "magnifyingglass") { model.startScan() }
                    .disabled(model.isBusy || model.roots.isEmpty)
            }
        }
        if model.tool != .apps {
        ToolbarItem(placement: .primaryAction) {
            Picker(L.t("View"), selection: Binding(get: { model.grouped }, set: { model.grouped = $0 })) {
                Label(L.t("By project"), systemImage: "list.bullet.indent").tag(true)
                Label(L.t("Flat list"), systemImage: "list.bullet").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(L.t("Group by project, or list everything by size"))
        }
        ToolbarItem(placement: .primaryAction) {
            Menu(L.t("Selection"), systemImage: "checklist") {
                Button(L.t("Select all visible")) { model.selectAllVisible() }
                Button(L.t("Select only what a command rebuilds")) { model.selectOnlyRegenerable() }
                Divider()
                Button(L.t("Select untouched for 30 days")) { model.selectStale(days: 30) }
                Button(L.t("Select untouched for 90 days")) { model.selectStale(days: 90) }
                Divider()
                Button(L.t("Deselect all")) { model.deselectAll() }
                if model.grouped {
                    Divider()
                    Button(L.t("Expand all")) { model.expandAll() }
                    Button(L.t("Collapse all")) { model.collapseAll() }
                }
            }
            .disabled(model.findings.isEmpty)
        }
        }
    }

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { if case .done = model.phase { true } else { false } },
            set: { if !$0 { model.dismissResult() } }
        )
    }
}

/// Escolha da frente de trabalho. Fica no topo da barra lateral porque é a
/// decisão que muda tudo abaixo dela.
private struct ToolPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Tool.allCases) { tool in
                Button {
                    model.tool = tool
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tool.symbol)
                            .frame(width: 18)
                            .foregroundStyle(model.tool == tool ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L.t(tool.title))
                                .fontWeight(model.tool == tool ? .medium : .regular)
                            Text(L.t(tool.subtitle))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(model.tool == tool ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}

/// As pastas varridas pelas ferramentas de arquivos.
private struct FileRootsList: View {
    @Environment(FileModel.self) private var files
    @Environment(AppsModel.self) private var apps

    var body: some View {
        List {
            Section(L.t("Project folders")) {
                Toggle(L.t("Include project folders"), isOn: Binding(
                    get: { files.usesProjectRoots }, set: { files.usesProjectRoots = $0 }))
                    .toggleStyle(.checkbox)
                    .font(.callout)
                if files.usesProjectRoots {
                    ForEach(files.projectRoots, id: \.self) { root in
                        Label(root.lastPathComponent, systemImage: "folder.fill")
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.head)
                            .help(root.path(percentEncoded: false))
                    }
                }
            }

            Section(L.t("Other folders")) {
                ForEach(files.extraRoots, id: \.self) { root in
                    HStack {
                        Label(root.lastPathComponent, systemImage: "folder")
                            .lineLimit(1).truncationMode(.head)
                        Spacer()
                        Button(L.t("Remove"), systemImage: "minus.circle") { files.removeRoot(root) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    .help(root.path(percentEncoded: false))
                }
                Button(L.t("Add folder…"), systemImage: "plus") { pick() }
                    .buttonStyle(.borderless)
            }

            Section(L.t("Ignore smaller than")) {
                Picker("", selection: Binding(
                    get: { files.minimumSizeMB }, set: { files.minimumSizeMB = $0 })) {
                    Text("1 MB").tag(1)
                    Text("10 MB").tag(10)
                    Text("100 MB").tag(100)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .listStyle(.sidebar)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L.t("Add")
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { files.addRoot($0) }
    }
}
