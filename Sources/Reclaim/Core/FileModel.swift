import Foundation
import Observation

/// Estado das ferramentas de arquivos: duplicados, grandes e entulho.
///
/// Separado do `AppModel` porque é outro domínio — o de projetos raciocina em
/// regras por ecossistema, este em arquivos e conteúdo. Compartilham só as
/// pastas escaneadas e a remoção.
@MainActor
@Observable
final class FileModel {
    enum Phase: Equatable {
        case idle
        case scanning(String)
        case analysing(String)
        case finished(files: Int, duration: TimeInterval)
    }

    private(set) var phase: Phase = .idle
    private(set) var files: [FileEntry] = []
    private(set) var duplicates: [DuplicateGroup] = []
    private(set) var emptyFolders: [URL] = []

    /// Pastas extras, além das que o app já varre em busca de projetos.
    var extraRoots: [URL] {
        didSet { Defaults.fileRoots = extraRoots }
    }
    /// Ligado por padrão: a promessa do app é limpar onde o trabalho acontece,
    /// e as pastas de projetos já estão configuradas. Duplicados dentro delas —
    /// a mesma imagem em três projetos, o mesmo PDF baixado duas vezes — são
    /// tão espaço desperdiçado quanto os de Downloads.
    var usesProjectRoots: Bool {
        didSet { Defaults.filesFollowProjectRoots = usesProjectRoots }
    }
    /// As pastas dos projetos, mantidas em dia pelo `AppModel`.
    var projectRoots: [URL] = []

    var roots: [URL] {
        (usesProjectRoots ? projectRoots : []) + extraRoots
    }
    /// Abaixo disso não vale a pena listar: um duplicado de 100 KB não recupera
    /// espaço e afoga o que importa.
    var minimumSizeMB: Int {
        didSet { Defaults.fileMinimumSizeMB = minimumSizeMB }
    }
    var idleDaysThreshold = 180
    var selection: Set<URL> = []
    var search = ""

    private var task: Task<Void, Never>?

    init() {
        extraRoots = Defaults.fileRoots
        usesProjectRoots = Defaults.filesFollowProjectRoots
        minimumSizeMB = Defaults.fileMinimumSizeMB
    }

    var isBusy: Bool {
        switch phase {
        case .idle, .finished: false
        default: true
        }
    }

    // MARK: - Visões

    var largeFiles: [FileEntry] {
        filtered(files).sorted { $0.size > $1.size }
    }

    /// Grandes e esquecidos ao mesmo tempo: um vídeo de 4 GB que ninguém abre
    /// desde 2023 é candidato muito melhor do que um de 4 GB de ontem.
    var forgotten: [FileEntry] {
        filtered(files)
            .filter { $0.idleDays >= idleDaysThreshold }
            .sorted { $0.size > $1.size }
    }

    var junk: [(file: FileEntry, rule: FileJunk.Rule)] {
        filtered(files).compactMap { file in
            guard let rule = FileJunk.classify(file) else { return nil }
            return (file, rule)
        }
        .sorted { $0.file.size > $1.file.size }
    }

    var visibleDuplicates: [DuplicateGroup] {
        guard !search.isEmpty else { return duplicates }
        let needle = search.lowercased()
        return duplicates.filter { group in
            group.files.contains { $0.name.lowercased().contains(needle)
                || $0.parent.lowercased().contains(needle) }
        }
    }

    private func filtered(_ entries: [FileEntry]) -> [FileEntry] {
        guard !search.isEmpty else { return entries }
        let needle = search.lowercased()
        return entries.filter {
            $0.name.lowercased().contains(needle) || $0.parent.lowercased().contains(needle)
        }
    }

    var selectedSize: Int64 {
        files.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    // MARK: - Ações

    func addRoot(_ url: URL) {
        guard !roots.contains(url) else { return }
        extraRoots.append(url)
    }

    func removeRoot(_ url: URL) {
        extraRoots.removeAll { $0 == url }
    }

    /// Repete a última varredura com as mesmas opções.
    func rescan() {
        scan(findDuplicates: lastFindDuplicates)
    }

    private var lastFindDuplicates = false

    func scan(findDuplicates: Bool) {
        guard !isBusy, !roots.isEmpty else { return }
        lastFindDuplicates = findDuplicates
        files = []
        duplicates = []
        emptyFolders = []
        selection = []
        let started = Date()
        phase = .scanning("")

        let scanner = FileScanner(minimumSize: Int64(minimumSizeMB) * 1_048_576)
        let roots = roots

        task = Task { [weak self] in
            guard let self else { return }
            let found = await scanner.scan(roots: roots) { progress in
                Task { @MainActor in self.phase = .scanning(progress.currentPath) }
            }
            guard !Task.isCancelled else { phase = .idle; return }
            files = found

            if findDuplicates {
                phase = .analysing("")
                let groups = await Task.detached(priority: .userInitiated) {
                    DuplicateFinder.find(in: found) { progress in
                        let label = switch progress.stage {
                        case .grouping: "grouping by size"
                        case .sampling: "sampling \(progress.done)/\(progress.total)"
                        case .hashing: "verifying \(progress.done)/\(progress.total)"
                        }
                        Task { @MainActor in self.phase = .analysing(label) }
                    }
                }.value
                duplicates = groups
            }

            emptyFolders = await Task.detached { FileJunk.emptyDirectories(under: roots) }.value
            phase = .finished(files: found.count, duration: Date().timeIntervalSince(started))
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    /// Marca todas as cópias menos a sugerida para manter. Nunca marca um grupo
    /// inteiro: apagar todas as cópias de um arquivo é perder o arquivo.
    func selectDuplicatesKeepingOne() {
        selection = Set(duplicates.flatMap { $0.duplicates.map(\.url) })
    }

    func selectAllJunk() {
        selection = Set(junk.map(\.file.url))
    }

    /// Os achados marcados, no formato que o `Cleaner` já sabe remover.
    var selectedFindings: [Finding] {
        files.filter { selection.contains($0.url) }.map { file in
            Finding(
                url: file.url,
                origin: .project(ruleID: "file", ecosystem: .misc, root: file.url.deletingLastPathComponent()),
                size: file.size,
                fileCount: 1,
                modified: file.modified,
                detail: file.parent,
                title: nil,
                regenerable: false,
                clearContentsOnly: false
            )
        }
    }
}
