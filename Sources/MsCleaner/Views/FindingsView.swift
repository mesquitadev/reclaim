import SwiftUI

struct FindingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.findings.isEmpty {
                EmptyStateView()
            } else {
                List {
                    ForEach(model.visibleFindings) { finding in
                        FindingRow(finding: finding, isOn: binding(for: finding))
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
            }
        }
        .overlay(alignment: .top) { if model.phase == .scanning { ScanBanner() } }
    }

    private func binding(for finding: Finding) -> Binding<Bool> {
        Binding(
            get: { model.selection.contains(finding.url) },
            set: { on in
                if on { model.selection.insert(finding.url) }
                else { model.selection.remove(finding.url) }
            }
        )
    }
}

private struct FindingRow: View {
    let finding: Finding
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Marcar \(finding.name)", isOn: $isOn)
                .labelsHidden()

            Image(systemName: finding.isGlobalCache ? "externaldrive" : (finding.ecosystem?.symbol ?? "shippingbox"))
                .foregroundStyle(finding.regenerable ? Color.accentColor : .orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(finding.name).fontWeight(.medium)
                    if let project = finding.projectName {
                        Text("em \(project)").foregroundStyle(.secondary)
                    }
                    if !finding.regenerable {
                        Text("verifique")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                .lineLimit(1)

                Text(finding.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(finding.size.formattedBytes)
                    .font(.body.monospacedDigit().weight(.medium))
                Text("\(finding.fileCount) arquivos · \(finding.modified.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .help(finding.url.path(percentEncoded: false))
        .contextMenu {
            Button("Revelar no Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([finding.url])
            }
            Button("Copiar caminho", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(finding.url.path(percentEncoded: false), forType: .string)
            }
        }
    }
}

private struct ScanBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(model.currentPath.isEmpty ? "Escaneando…" : model.currentPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
            Text("\(model.scannedDirs) pastas")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label(model.phase == .scanning ? "Escaneando" : "Nada escaneado ainda",
                  systemImage: model.phase == .scanning ? "hourglass" : "sparkles")
        } description: {
            if model.roots.isEmpty {
                Text("Adicione ao menos uma pasta de projetos na barra lateral.")
            } else if model.phase == .scanning {
                Text(model.currentPath).lineLimit(2).truncationMode(.head)
            } else {
                Text(model.roots.count == 1
                    ? "Escaneie a pasta configurada para ver o que pode ser liberado."
                    : "Escaneie as \(model.roots.count) pastas configuradas para ver o que pode ser liberado.")
            }
        } actions: {
            if model.phase != .scanning, !model.roots.isEmpty {
                Button("Escanear agora") { model.startScan() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
