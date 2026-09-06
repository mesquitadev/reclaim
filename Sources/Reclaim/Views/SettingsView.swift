import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            RulesTab().tabItem { Label(L.t("Rules"), systemImage: "list.bullet.rectangle") }
            GeneralTab().tabItem { Label(L.t("General"), systemImage: "gearshape") }
        }
        .frame(width: 560, height: 460)
    }
}

private struct GeneralTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Picker(L.t("Language"), selection: Binding(
                    get: { model.language }, set: { model.language = $0 })) {
                    ForEach(Language.allCases) { language in
                        // Cada idioma se nomeia no próprio idioma; "System" segue
                        // a preferência do macOS, caindo em inglês.
                        Text(language == .system ? L.t("System") : language.label)
                            .tag(language)
                    }
                }
            }

            Section {
                Toggle(L.t("Include global tool caches"), isOn: Binding(
                    get: { model.includeGlobalCaches }, set: { model.includeGlobalCaches = $0 }))
                Text(L.t("npm, Cargo, Gradle, DerivedData, Homebrew, Playwright, JetBrains and friends — all rebuilt on demand."))
                    .font(.caption).foregroundStyle(.secondary)

                Toggle(L.t("Discover other app caches"), isOn: Binding(
                    get: { model.discoverAppCaches }, set: { model.discoverAppCaches = $0 }))
                    .disabled(!model.includeGlobalCaches)
                Text(L.t("Scans everything in ~/Library/Caches and ~/.cache, including what is not catalogued. Those arrive unselected, tagged *check*."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker(L.t("Ignore items smaller than"), selection: Binding(
                    get: { model.minimumSizeMB }, set: { model.minimumSizeMB = $0 })) {
                    Text(L.t("Nothing (show everything)")).tag(0)
                    Text("1 MB").tag(1)
                    Text("10 MB").tag(10)
                    Text("100 MB").tag(100)
                }
                Text(L.t("Filters out the noise of thousands of tiny `__pycache__` and `.DS_Store`."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker(L.t("When cleaning"), selection: Binding(
                    get: { model.mode }, set: { model.mode = $0 })) {
                    ForEach(Cleaner.Mode.allCases, id: \.self) { Text(L.t($0.label)).tag($0) }
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
                        Label(L.t(eco.label), systemImage: eco.symbol)
                    }
                }
            }
        }
    }
}
