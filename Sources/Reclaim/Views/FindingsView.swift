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

/// Barra fixa acima da árvore: marca de uma vez tudo que está visível.
private struct MasterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            TriStateBox(state: model.masterSelectionState) { model.setMasterSelection($0) }

            Text(label).font(.callout)

            Spacer()

            if model.grouped {
                Button(L.t(allCollapsed ? "Expand all" : "Collapse all")) {
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
            ? L.t("Select all %@ items", "\(visible)")
            : L.t("%@ of %@ selected", "\(marked)", "\(visible)")
    }

    private var allCollapsed: Bool {
        let nodes = model.allNodes
        return !nodes.isEmpty && nodes.allSatisfy { !model.isExpanded($0) }
    }
}

/// A árvore. É uma `List` plana — nós e folhas na mesma lista, com recuo por
/// profundidade — para que as setas percorram tudo na ordem que se vê, o que
/// `DisclosureGroup` aninhado não garante.
private struct RowList: View {
    @Environment(AppModel.self) private var model
    @Binding var cursor: FlatRow.ID?
    @FocusState private var focused: Bool

    var body: some View {
        List(selection: $cursor) {
            ForEach(rows) { row in
                RowView(row: row)
                    .tag(row.id)
            }
        }
        .listStyle(.inset)
        .focused($focused)
        .onKeyPress(.space) { toggle() }
        .onKeyPress(.leftArrow) { move(expanded: false) }
        .onKeyPress(.rightArrow) { move(expanded: true) }
        .onKeyPress(.return) { reveal() }
    }

    /// No modo lista corrida, as folhas vêm sem hierarquia.
    private var rows: [FlatRow] {
        model.grouped
            ? model.flatRows
            : model.visibleFindings.map { .leaf($0, depth: 0, parentID: "") }
    }

    private var current: FlatRow? { rows.first { $0.id == cursor } }

    private func toggle() -> KeyPress.Result {
        guard let current else { return .ignored }
        if let node = current.node {
            model.setSelection(of: node, on: model.selectionState(of: node) != .on)
        } else if let finding = current.finding {
            if model.selection.contains(finding.url) { model.selection.remove(finding.url) }
            else { model.selection.insert(finding.url) }
        }
        return .handled
    }

    /// → abre o nó; ← fecha. Sobre uma folha, ← sobe para o nó pai — é o que se
    /// espera de uma árvore.
    private func move(expanded: Bool) -> KeyPress.Result {
        guard model.grouped, let current else { return .ignored }
        if let node = current.node {
            guard !node.children.isEmpty || !node.leaves.isEmpty else { return .ignored }
            model.setExpanded(node, expanded)
            return .handled
        }
        guard !expanded, let parentID = current.parentID else { return .ignored }
        cursor = "n:" + parentID
        return .handled
    }

    private func reveal() -> KeyPress.Result {
        guard let target = current?.finding?.url ?? current?.node?.url else { return .ignored }
        NSWorkspace.shared.activateFileViewerSelecting([target])
        return .handled
    }
}

private struct RowView: View {
    let row: FlatRow

    var body: some View {
        switch row {
        case .node(let node, let depth):
            NodeRow(node: node)
                .padding(.leading, CGFloat(depth) * 18)
        case .leaf(let finding, let depth, _):
            FindingRow(finding: finding, depth: depth)
                .padding(.leading, CGFloat(depth) * 18)
        }
    }
}

/// Uma pasta, um projeto ou uma categoria de cache.
private struct NodeRow: View {
    @Environment(AppModel.self) private var model
    let node: TreeNode

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.setExpanded(node, !model.isExpanded(node))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(model.isExpanded(node) ? 90 : 0))
                    .frame(width: 12)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L.t(model.isExpanded(node) ? "Collapse" : "Expand"))

            TriStateBox(state: model.selectionState(of: node)) { model.setSelection(of: node, on: $0) }

            Image(systemName: node.symbol)
                .foregroundStyle(node.isProject ? Color.accentColor : .secondary)
                .frame(width: 16)

            Text(node.name)
                // O projeto é o nível que interessa; as pastas do caminho são contexto.
                .fontWeight(node.isProject ? .semibold : .regular)
                .foregroundStyle(node.isProject ? .primary : .secondary)
                .lineLimit(1)

            Text("\(node.count)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: Capsule())

            Spacer(minLength: 8)

            Text(node.size.formattedBytes)
                .font(.body.monospacedDigit().weight(node.isProject ? .medium : .regular))
                .foregroundStyle(node.isProject ? .primary : .secondary)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture(count: 2) { model.setExpanded(node, !model.isExpanded(node)) }
        .help(node.url?.path(percentEncoded: false) ?? node.name)
        .contextMenu {
            if let url = node.url {
                Button(L.t("Reveal in Finder"), systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            Button(L.t("Select all")) { model.setSelection(of: node, on: true) }
            Button(L.t("Deselect all in group")) { model.setSelection(of: node, on: false) }
        }
    }
}

struct FindingRow: View {
    @Environment(AppModel.self) private var model
    let finding: Finding
    var depth: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: depth > 0 ? 12 : 0)

            Toggle(L.t("Select") + " " + finding.name, isOn: binding)
                .labelsHidden()

            Image(systemName: finding.isGlobalCache ? "externaldrive" : (finding.ecosystem?.symbol ?? "shippingbox"))
                .foregroundStyle(finding.regenerable ? Color.accentColor : .orange)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(L.t(finding.name)).fontWeight(.medium)
                    // Dentro da árvore o projeto já é o nó pai; aqui só o que resta
                    // do caminho, que distingue dois `__pycache__` do mesmo projeto.
                    // A barra final é o que separa o caminho do nome ao lado —
                    // sem ela, uma pasta chamada "node_modules 21-30" se confunde
                    // com um node_modules dentro de outro diretório.
                    if let path = finding.pathInProject, model.grouped {
                        Text("· " + path + "/")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if !model.grouped, let project = finding.projectName {
                        Text(L.t("in %@", project)).foregroundStyle(.secondary)
                    }
                    if !finding.regenerable {
                        Text(L.t("check"))
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
                Text(L.t("%@ files · %@", "\(finding.fileCount)", finding.modified.formatted(.relative(presentation: .named))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .help(finding.url.path(percentEncoded: false))
        .contextMenu {
            Button(L.t("Reveal in Finder"), systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([finding.url])
            }
            Button(L.t("Copy path"), systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(finding.url.path(percentEncoded: false), forType: .string)
            }
        }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { model.selection.contains(finding.url) },
            set: { on in
                if on { model.selection.insert(finding.url) } else { model.selection.remove(finding.url) }
            }
        )
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
        .accessibilityLabel(L.t("Select"))
    }

    private var symbol: String {
        switch state {
        case .off: "square"
        case .mixed: "minus.square.fill"
        case .on: "checkmark.square.fill"
        }
    }
}

private struct ScanBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(model.currentPath.isEmpty ? L.t("Scanning…") : model.currentPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
            Text(L.t("%@ folders", "\(model.scannedDirs)"))
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
            Label(L.t(model.phase == .scanning ? "Scanning" : "Nothing scanned yet"),
                  systemImage: model.phase == .scanning ? "hourglass" : "sparkles")
        } description: {
            if model.roots.isEmpty {
                Text(L.t("Add at least one project folder in the sidebar."))
            } else if model.phase == .scanning {
                Text(model.currentPath).lineLimit(2).truncationMode(.head)
            } else {
                Text(model.roots.count == 1
                    ? L.t("Scan the configured folder to see what can be freed.")
                    : L.t("Scan the %@ configured folders to see what can be freed.", "\(model.roots.count)"))
            }
        } actions: {
            if model.phase != .scanning, !model.roots.isEmpty {
                Button(L.t("Scan now")) { model.startScan() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
