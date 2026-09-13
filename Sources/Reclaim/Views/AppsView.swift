import SwiftUI
import AppKit

/// Desinstalar um app por inteiro: o bundle e tudo o que ele espalhou.
struct AppsView: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        HSplitView {
            appList
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 460)
                .frame(maxHeight: .infinity)
            detail
                .frame(minWidth: 380, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if model.apps.isEmpty { model.scan() } }
    }

    // MARK: Lista de apps

    private var appList: some View {
        VStack(spacing: 0) {
            if model.isScanning && model.apps.isEmpty {
                ProgressView(L.t("Reading installed apps…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.visibleApps, selection: Binding(
                    get: { model.selectedApp },
                    set: { if let app = $0 { model.inspect(app) } })) { app in
                    AppRow(app: app).tag(app)
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: Detalhe

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            UninstallDetail(app: app)
        } else {
            ContentUnavailableView(
                L.t("Choose an app"),
                systemImage: "trash.square",
                description: Text(L.t("Reclaim finds the preferences, caches, containers and background items it left behind.")))
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).lineLimit(1)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(app.formattedSize)
                    .font(.callout.monospacedDigit())
                // Tempo sem abrir é o melhor argumento para desinstalar, e a
                // única informação aqui que o Finder não dá.
                if let days = app.idleDays, days > 30 {
                    Text(L.t("idle %@ days").replacingOccurrences(of: "%@", with: "\(days)"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// O plano de remoção de um app.
private struct UninstallDetail: View {
    @Environment(AppsModel.self) private var model
    let app: InstalledApp

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if model.isBuildingPlan {
                ProgressView(L.t("Looking for leftovers…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan = model.plan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let uninstaller = app.bundledUninstaller {
                            bundledUninstallerNotice(uninstaller)
                        }
                        if model.isRunning(app) { runningNotice }
                        if !model.chosenPrivileged.isEmpty { privilegedNotice }

                        ForEach(plan.byKind, id: \.0) { kind, items in
                            KindSection(kind: kind, items: items)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable().frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    if let version = app.version { Text(version) }
                    Text(app.bundleID).truncationMode(.middle).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(model.chosenSize.formattedBytes)
                    .font(.title3.monospacedDigit().weight(.medium))
                Text(L.t("selected to remove"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    /// Quando o app traz desinstalador próprio, ele vem antes de tudo.
    private func bundledUninstallerNotice(_ uninstaller: URL) -> some View {
        Notice(symbol: "exclamationmark.triangle.fill", tone: .orange,
               title: L.t("This app ships its own uninstaller"),
               message: L.t("Installers like this one register components that only their own uninstaller can undo. Use it first, then come back to clear what it leaves behind.")) {
            Button(L.t("Open uninstaller")) { model.openUninstaller(uninstaller) }
            Button(L.t("Show in Finder")) { model.reveal(uninstaller) }
        }
    }

    private var runningNotice: some View {
        Notice(symbol: "play.circle.fill", tone: .blue,
               title: L.t("The app is running"),
               message: L.t("Quit it before removing, or files will be deleted while the app still holds them.")) {
            Button(L.t("Quit app")) { model.quit(app) }
        }
    }

    private var privilegedNotice: some View {
        Notice(symbol: "lock.fill", tone: .secondary,
               title: L.t("Some items need an administrator"),
               message: L.t("Items outside your home folder — background daemons and shared support files — can't be removed by Reclaim. They are listed so you know they exist; use Show in Finder to handle them.")) {
            EmptyView()
        }
    }
}

/// Um bloco de aviso, com ações.
private struct Notice<Actions: View>: View {
    let symbol: String
    let tone: Color
    let title: String
    let message: String
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tone)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(message).font(.caption).foregroundStyle(.secondary)
                HStack { actions }.controlSize(.small).padding(.top, 2)
            }
            Spacer()
        }
        .padding(11)
        .background(tone.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Os resíduos de uma família.
private struct KindSection: View {
    @Environment(AppsModel.self) private var model
    let kind: Leftover.Kind
    let items: [Leftover]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Label(L.t(kind.label), systemImage: kind.symbol)
                    .font(.callout.weight(.medium))
                if kind.isRunningCode {
                    // Esta família merece destaque: é a que continua executando
                    // depois que o app some, e a que ninguém encontra sozinho.
                    Text(L.t("keeps running after removal"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(items.reduce(0) { $0 + $1.size }.formattedBytes)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { item in
                LeftoverRow(item: item)
            }
        }
    }
}

private struct LeftoverRow: View {
    @Environment(AppsModel.self) private var model
    let item: Leftover

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { model.chosen.contains(item.url) },
                set: { _ in model.toggle(item) }))
                .labelsHidden()
                .disabled(item.needsAdmin)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 5) {
                    Text(L.t(item.reason.text))
                    if item.needsAdmin {
                        Image(systemName: "lock.fill")
                        Text(L.t("needs administrator"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(item.reason.isCertain ? .tertiary : .secondary)
            }

            Spacer()
            Text(item.formattedSize)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(L.t("Show in Finder"), systemImage: "magnifyingglass") { model.reveal(item.url) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .padding(.leading, 4)
        .help(item.url.path(percentEncoded: false))
    }
}
