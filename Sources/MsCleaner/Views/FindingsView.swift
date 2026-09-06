import SwiftUI

struct FindingsView: View {
    @Environment(AppModel.self) private var model
    @State private var cursor: FlatRow.ID?

    var body: some View {
        Group {
            if model.findings.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 0) {
                    MasterBar()
                    Divider()
                    RowList(cursor: $cursor)
                }
            }
        }
        .overlay(alignment: .top) { if model.phase == .scanning { ScanBanner() } }
    }

}

private struct GroupHeader: View {
    @Environment(AppModel.self) private var model
    let group: FindingGroup

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.setExpanded(group, !model.isExpanded(group))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(model.isExpanded(group) ? 90 : 0))
                    .frame(width: 12)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(model.isExpanded(group) ? "Recolher grupo" : "Expandir grupo")

            TriStateBox(state: model.selectionState(of: group)) { on in
                model.setSelection(of: group, on: on)
            }

            Image(systemName: group.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(group.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let context = group.context {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Text("\(group.findings.count)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: Capsule())

            Spacer(minLength: 8)

            Text(group.size.formattedBytes)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture(count: 2) { model.setExpanded(group, !model.isExpanded(group)) }
        .help(group.url?.path(percentEncoded: false) ?? "Caches globais de ferramentas")
        .contextMenu {
            if let url = group.url {
                Button("Revelar no Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            Button("Marcar tudo do grupo") { model.setSelection(of: group, on: true) }
            Button("Desmarcar tudo do grupo") { model.setSelection(of: group, on: false) }
        }
    }
}

/// Checkbox de três estados — SwiftUI não traz um pronto no macOS.
struct TriStateBox: View {
    let state: AppModel.ToggleState
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(state != .on)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(state == .off ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Marcar grupo")
    }

    private var symbol: String {
        switch state {
        case .off: "square"
        case .mixed: "minus.square.fill"
        case .on: "checkmark.square.fill"
        }
    }
}

struct FindingRow: View {
    let finding: Finding
    @Binding var isOn: Bool
    /// No modo agrupado o projeto já está no cabeçalho; repeti-lo só polui.
    var showsProject: Bool = true

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
                    if showsProject, let project = finding.projectName {
                        Text("em \(project)").foregroundStyle(.secondary)
                    } else if let path = finding.pathInProject {
                        Text(path).foregroundStyle(.secondary)
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


/// Barra fixa acima da árvore: marca tudo que está visível de uma vez.
private struct MasterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            TriStateBox(state: model.masterSelectionState) { model.setMasterSelection($0) }

            Text(label)
                .font(.callout)

            Spacer()

            if model.grouped {
                Button(allCollapsed ? "Expandir tudo" : "Recolher tudo") {
                    if allCollapsed { model.expandAll() } else { model.collapseAll() }
                }
                .buttonStyle(.link)
                .font(.callout)
            }

            Text(model.visibleFindings.totalSize.formattedBytes)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.background.secondary)
    }

    private var label: String {
        let visible = model.visibleFindings.count
        let marked = model.visibleFindings.count { model.selection.contains($0.url) }
        return marked == 0
            ? "Marcar todos os \(visible) itens"
            : "\(marked) de \(visible) marcados"
    }

    private var allCollapsed: Bool {
        model.visibleGroups.allSatisfy { !model.isExpanded($0) }
    }
}

/// A árvore em si. É uma lista plana — cabeçalhos e filhos na mesma `List` — para
/// que as setas percorram tudo na ordem que se vê, o que um `DisclosureGroup`
/// aninhado não garante.
private struct RowList: View {
    @Environment(AppModel.self) private var model
    @Binding var cursor: FlatRow.ID?
    @FocusState private var focused: Bool

    var body: some View {
        List(selection: $cursor) {
            ForEach(rows) { row in
                switch row {
                case .header(let group):
                    GroupHeader(group: group).tag(row.id)
                case .child(let finding, _):
                    FindingRow(finding: finding, isOn: binding(for: finding),
                               showsProject: !model.grouped)
                        .padding(.leading, model.grouped ? 26 : 0)
                        .tag(row.id)
                }
            }
        }
        .listStyle(.inset)
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.space) { toggle() }
        .onKeyPress(.leftArrow) { move(expanded: false) }
        .onKeyPress(.rightArrow) { move(expanded: true) }
        .onKeyPress(.return) { reveal() }
    }

    /// No modo lista, um "grupo" único evita duplicar a renderização.
    private var rows: [FlatRow] {
        model.grouped
            ? model.flatRows
            : model.visibleFindings.map { .child($0, groupID: "__flat__") }
    }

    private var current: FlatRow? {
        rows.first { $0.id == cursor }
    }

    private func binding(for finding: Finding) -> Binding<Bool> {
        Binding(
            get: { model.selection.contains(finding.url) },
            set: { on in
                if on { model.selection.insert(finding.url) } else { model.selection.remove(finding.url) }
            }
        )
    }

    private func toggle() -> KeyPress.Result {
        guard let current else { return .ignored }
        if let group = current.group {
            model.setSelection(of: group, on: model.selectionState(of: group) != .on)
        } else if let finding = current.finding {
            if model.selection.contains(finding.url) { model.selection.remove(finding.url) }
            else { model.selection.insert(finding.url) }
        }
        return .handled
    }

    /// → abre o grupo; ← fecha. Sobre um filho, ← sobe para o cabeçalho — é o que
    /// se espera de uma árvore.
    private func move(expanded: Bool) -> KeyPress.Result {
        guard model.grouped, let current else { return .ignored }
        if let group = current.group {
            model.setExpanded(group, expanded)
            return .handled
        }
        guard !expanded,
              let group = model.visibleGroups.first(where: { $0.id == current.owningGroupID })
        else { return .ignored }
        cursor = FlatRow.header(group).id
        return .handled
    }

    private func reveal() -> KeyPress.Result {
        guard let target = current?.finding?.url ?? current?.group?.url else { return .ignored }
        NSWorkspace.shared.activateFileViewerSelecting([target])
        return .handled
    }
}
