import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            // A barra de ação precisa ficar no mesmo nível da lista: aplicada no
            // NavigationSplitView, ela cobria a última linha em vez de reservar
            // espaço no fim da rolagem.
            FindingsView()
                .safeAreaInset(edge: .bottom, spacing: 0) { ActionBar() }
        }
        .toolbar { toolbar }
        .searchable(text: Binding(get: { model.search }, set: { model.search = $0 }),
                    placement: .toolbar, prompt: Text(L.t("Filter by project or path")))
        .sheet(isPresented: resultBinding) { ResultSheet() }
        .sheet(isPresented: .constant(model.phase == .cleaning)) { CleaningSheet() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if model.phase == .scanning {
                Button(L.t("Stop"), systemImage: "stop.fill") { model.cancel() }
            } else {
                Button(L.t("Scan"), systemImage: "magnifyingglass") { model.startScan() }
                    .disabled(model.isBusy || model.roots.isEmpty)
            }
        }
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

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { if case .done = model.phase { true } else { false } },
            set: { if !$0 { model.dismissResult() } }
        )
    }
}
