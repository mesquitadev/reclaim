import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            RulesTab().tabItem { Label("Regras", systemImage: "list.bullet.rectangle") }
            GeneralTab().tabItem { Label("Geral", systemImage: "gearshape") }
        }
        .frame(width: 560, height: 460)
    }
}

private struct GeneralTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Toggle("Incluir caches globais de ferramentas", isOn: Binding(
                    get: { model.includeGlobalCaches }, set: { model.includeGlobalCaches = $0 }))
                Text("npm, Cargo, Gradle, DerivedData, pub-cache e afins — todos reconstruídos sob demanda.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("Ignorar itens menores que", selection: Binding(
                    get: { model.minimumSizeMB }, set: { model.minimumSizeMB = $0 })) {
                    Text("Nada (mostrar tudo)").tag(0)
                    Text("1 MB").tag(1)
                    Text("10 MB").tag(10)
                    Text("100 MB").tag(100)
                }
                Text("Filtra o ruído de milhares de `__pycache__` e `.DS_Store` minúsculos.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("Ao limpar", selection: Binding(
                    get: { model.mode }, set: { model.mode = $0 })) {
                    ForEach(Cleaner.Mode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct RulesTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            ForEach(Ecosystem.allCases) { eco in
                let rules = Rule.catalog.filter { $0.ecosystem == eco }
                if !rules.isEmpty {
                    Section {
                        ForEach(rules) { rule in
                            Toggle(isOn: Binding(
                                get: { model.enabledRuleIDs.contains(rule.id) },
                                set: { model.toggleRule(rule.id, on: $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(rule.name).font(.body.monospaced())
                                    Text(rule.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Label(eco.label, systemImage: eco.symbol)
                    }
                }
            }
        }
    }
}
