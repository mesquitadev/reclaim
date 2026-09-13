import SwiftUI

/// As três telas de arquivos: duplicados, grandes e entulho.
struct FilesView: View {
    @Environment(AppModel.self) private var model
    @Environment(FileModel.self) private var files
    let tool: Tool

    var body: some View {
        VStack(spacing: 0) {
            FileScanBar(tool: tool)
            Divider()

            Group {
                switch tool {
                case .duplicates: DuplicatesList()
                case .large: LargeFilesList()
                case .junk: JunkList()
                case .development, .apps: EmptyView()
                }
            }

            Divider()
            FileStatusBar(tool: tool)
        }
    }
}

private struct FileScanBar: View {
    @Environment(FileModel.self) private var files
    let tool: Tool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text(files.roots.isEmpty
                 ? L.t("No folders to scan")
                 : files.roots.map { $0.lastPathComponent }.joined(separator: ", "))
                .font(.callout)
                .foregroundStyle(files.roots.isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            if tool == .large {
                Picker(L.t("Idle for"), selection: Binding(
                    get: { files.idleDaysThreshold }, set: { files.idleDaysThreshold = $0 })) {
                    Text(L.t("any time")).tag(0)
                    Text(L.t("90 days")).tag(90)
                    Text(L.t("180 days")).tag(180)
                    Text(L.t("1 year")).tag(365)
                }
                .frame(maxWidth: 180)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

/// Duplicados agrupados: um cabeçalho por conteúdo, com as cópias embaixo.
private struct DuplicatesList: View {
    @Environment(FileModel.self) private var files

    var body: some View {
        if files.visibleDuplicates.isEmpty {
            ContentUnavailableView(
                L.t("No duplicates found"), systemImage: "doc.on.doc",
                description: Text(L.t("Scan the chosen folders to compare file contents."))
            )
        } else {
            List {
                ForEach(files.visibleDuplicates) { group in
                    Section {
                        ForEach(group.files) { file in
                            let isKeeper = file.url == group.suggestedKeep?.url
                            HStack(spacing: 10) {
                                Toggle("", isOn: binding(for: file))
                                    .labelsHidden()
                                    // O sugerido para manter não some da lista —
                                    // quem decide é o usuário —, mas fica claro
                                    // que apagar todas as cópias é perder o arquivo.
                                    .disabled(isKeeper && group.files.count == 2)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 6) {
                                        Text(file.name).fontWeight(isKeeper ? .medium : .regular)
                                        if isKeeper {
                                            Text(L.t("keep")).font(.caption2)
                                                .padding(.horizontal, 5).padding(.vertical, 1)
                                                .background(.green.opacity(0.18), in: Capsule())
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    Text(file.parent).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.head)
                                }
                                Spacer()
                                Text(file.modified.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                            .contextMenu { RevealButton(url: file.url) }
                        }
                    } header: {
                        HStack {
                            Text(group.files.first?.formattedSize ?? "")
                                .font(.callout.monospacedDigit().weight(.medium))
                            Text(String(format: L.t("%@ copies"), "\(group.files.count)"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: L.t("recovers %@"),
                                        ByteCountFormatter.string(fromByteCount: group.reclaimable, countStyle: .file)))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func binding(for file: FileEntry) -> Binding<Bool> {
        Binding(
            get: { files.selection.contains(file.url) },
            set: { on in
                if on { files.selection.insert(file.url) } else { files.selection.remove(file.url) }
            }
        )
    }
}

private struct LargeFilesList: View {
    @Environment(FileModel.self) private var files

    private var entries: [FileEntry] {
        files.idleDaysThreshold > 0 ? files.forgotten : files.largeFiles
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(L.t("Nothing scanned yet"), systemImage: "arrow.up.right.square",
                                   description: Text(L.t("Scan to see what takes the most room.")))
        } else {
            Table(entries) {
                TableColumn(L.t("Select")) { file in
                    Toggle("", isOn: binding(for: file)).labelsHidden()
                }
                .width(40)
                TableColumn(L.t("Name")) { file in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.name).lineLimit(1)
                        Text(file.parent).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.head)
                    }
                }
                TableColumn(L.t("Size")) { file in
                    Text(file.formattedSize).font(.callout.monospacedDigit())
                }
                .width(100)
                TableColumn(L.t("Last opened")) { file in
                    // A data de acesso é a que interessa: modificado diz quando
                    // o conteúdo mudou, aberto diz se alguém ainda usa.
                    Text(file.accessed.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(file.idleDays > 365 ? .orange : .secondary)
                }
                .width(140)
            }
        }
    }

    private func binding(for file: FileEntry) -> Binding<Bool> {
        Binding(
            get: { files.selection.contains(file.url) },
            set: { on in
                if on { files.selection.insert(file.url) } else { files.selection.remove(file.url) }
            }
        )
    }
}

private struct JunkList: View {
    @Environment(FileModel.self) private var files

    var body: some View {
        if files.junk.isEmpty && files.emptyFolders.isEmpty {
            ContentUnavailableView(L.t("No clutter found"), systemImage: "trash",
                                   description: Text(L.t("Scan to look for installers, leftovers and empty folders.")))
        } else {
            List {
                if !files.junk.isEmpty {
                    Section(L.t("Files")) {
                        ForEach(files.junk, id: \.file.id) { entry in
                            HStack(spacing: 10) {
                                Toggle("", isOn: binding(for: entry.file)).labelsHidden()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.file.name).lineLimit(1)
                                    Text(L.t(entry.rule.detail)).font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.file.formattedSize).font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .contextMenu { RevealButton(url: entry.file.url) }
                        }
                    }
                }
                if !files.emptyFolders.isEmpty {
                    Section(L.t("Empty folders")) {
                        ForEach(files.emptyFolders, id: \.self) { folder in
                            HStack {
                                Image(systemName: "folder").foregroundStyle(.tertiary)
                                Text(folder.path(percentEncoded: false))
                                    .font(.callout).lineLimit(1).truncationMode(.head)
                                Spacer()
                            }
                            .contextMenu { RevealButton(url: folder) }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func binding(for file: FileEntry) -> Binding<Bool> {
        Binding(
            get: { files.selection.contains(file.url) },
            set: { on in
                if on { files.selection.insert(file.url) } else { files.selection.remove(file.url) }
            }
        )
    }
}

private struct RevealButton: View {
    let url: URL

    var body: some View {
        Button(L.t("Reveal in Finder"), systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

private struct FileStatusBar: View {
    @Environment(AppModel.self) private var model
    @Environment(FileModel.self) private var files
    let tool: Tool

    var body: some View {
        HStack(spacing: 12) {
            switch files.phase {
            case .scanning(let path):
                ProgressView().controlSize(.small)
                Text(path.isEmpty ? L.t("Scanning…") : path)
                    .font(.caption).lineLimit(1).truncationMode(.head)
            case .analysing(let detail):
                ProgressView().controlSize(.small)
                Text(L.t("Comparing contents") + (detail.isEmpty ? "" : " · \(detail)"))
                    .font(.caption)
            case .finished(let count, let duration):
                Text(String(format: L.t("%@ files in %@"), "\(count)",
                            String(format: "%.1fs", duration)))
                    .font(.callout)
            case .idle:
                EmptyView()
            }

            Spacer()

            if tool == .duplicates, !files.duplicates.isEmpty {
                Button(L.t("Select all but one of each")) { files.selectDuplicatesKeepingOne() }
                    .buttonStyle(.link)
            }
            if tool == .junk, !files.junk.isEmpty {
                Button(L.t("Select all clutter")) { files.selectAllJunk() }
                    .buttonStyle(.link)
            }

            if !files.selection.isEmpty {
                Text(ByteCountFormatter.string(fromByteCount: files.selectedSize, countStyle: .file))
                    .font(.callout.monospacedDigit().weight(.medium))
                Button(L.t("Clean %@").replacingOccurrences(of: "%@", with: "\(files.selection.count)")) {
                    model.cleanFiles(files.selectedFindings) { files.selection.removeAll() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
