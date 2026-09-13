import SwiftUI

/// A barra de desinstalação.
///
/// Diferente da limpeza comum, aqui não há escolha entre Lixeira e remoção
/// definitiva: desinstalar é a operação com maior risco de levar junto a pasta
/// de outro app, e a Lixeira é a rede que torna esse risco aceitável.
struct UninstallBar: View {
    @Environment(AppModel.self) private var model
    @Environment(AppsModel.self) private var apps
    @State private var confirming = false

    private var count: Int {
        apps.plan?.leftovers.filter { apps.chosen.contains($0.url) && !$0.needsAdmin }.count ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(L.t("%@ items · %@", "\(count)", apps.chosenSize.formattedBytes))
                    .font(.callout.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if apps.plan != nil {
                Button(L.t("Select all")) { apps.chooseAll(true) }
                    .buttonStyle(.link)
                Button(L.t("Select none")) { apps.chooseAll(false) }
                    .buttonStyle(.link)
            }

            Button {
                confirming = true
            } label: {
                Label(L.t("Move to Trash"), systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(count == 0 || model.isBusy)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .confirmationDialog(title, isPresented: $confirming, titleVisibility: .visible) {
            Button(L.t("Move to Trash")) { uninstall() }
            Button(L.t("Cancel"), role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var subtitle: String {
        guard let app = apps.selectedApp else { return L.t("Nothing selected") }
        let locked = apps.chosenPrivileged.count
        if locked > 0 {
            return L.t("%@ more need an administrator and stay", "\(locked)")
        }
        return app.name
    }

    private var title: String {
        L.t("Move %@ items (%@) to the Trash?", "\(count)", apps.chosenSize.formattedBytes)
    }

    private var message: String {
        var text = L.t("You can put them back from the Trash if something was wrong.")
        if let app = apps.selectedApp, apps.isRunning(app) {
            text += " " + L.t("The app is still running — quit it first.")
        }
        return text
    }

    private func uninstall() {
        // A desinstalação força a Lixeira mesmo que a preferência global esteja
        // em remoção definitiva: a escolha do usuário vale para caches que se
        // regeneram, não para arquivos de um app que ele talvez queira de volta.
        let previous = model.mode
        model.mode = .trash
        let targets = apps.findingsToRemove
        model.cleanFiles(targets) {
            model.mode = previous
            apps.scan()
            if let app = apps.selectedApp { apps.inspect(app) }
        }
    }
}

/// O resumo na barra lateral, enquanto a desinstalação está ativa.
struct AppsSummary: View {
    @Environment(AppsModel.self) private var apps

    var body: some View {
        List {
            Section(L.t("Summary")) {
                LabeledContent(L.t("Apps"), value: "\(apps.visibleApps.count)")
                LabeledContent(L.t("Installed"), value: apps.totalInstalled.formattedBytes)
                if let plan = apps.plan {
                    LabeledContent(L.t("Leftovers found"), value: plan.formattedSize)
                }
                if apps.isMeasuring {
                    LabeledContent(L.t("Measuring"), value: "\(apps.measured)/\(apps.apps.count)")
                }
            }
            .font(.callout)

            Section(L.t("Sort")) {
                // A busca vive na toolbar, como nas outras ferramentas; um
                // segundo campo aqui só faria duvidar de qual dos dois vale.
                Picker(L.t("Sort"), selection: Binding(
                    get: { apps.sortBySize }, set: { apps.sortBySize = $0 })) {
                    Text(L.t("By size")).tag(true)
                    Text(L.t("By name")).tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                Text(L.t("Reclaim never lists Apple's own apps: they belong to the system and can't be removed this way."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
