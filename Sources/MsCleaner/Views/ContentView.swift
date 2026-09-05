import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            FindingsView()
        }
        .toolbar { toolbar }
        .searchable(text: Binding(get: { model.search }, set: { model.search = $0 }),
                    placement: .toolbar, prompt: "Filtrar por projeto ou caminho")
        .safeAreaInset(edge: .bottom) { ActionBar() }
        .sheet(isPresented: resultBinding) { ResultSheet() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if model.phase == .scanning {
                Button("Parar", systemImage: "stop.fill") { model.cancel() }
            } else {
                Button("Escanear", systemImage: "magnifyingglass") { model.startScan() }
                    .disabled(model.isBusy || model.roots.isEmpty)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu("Seleção", systemImage: "checklist") {
                Button("Marcar tudo visível") { model.selectAllVisible() }
                Button("Marcar só o reconstruível") { model.selectOnlyRegenerable() }
                Divider()
                Button("Marcar sem uso há 30 dias") { model.selectStale(days: 30) }
                Button("Marcar sem uso há 90 dias") { model.selectStale(days: 90) }
                Divider()
                Button("Desmarcar tudo") { model.deselectAll() }
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
