import Foundation

/// Varre as raízes escolhidas procurando resíduos de build/dependência.
///
/// A varredura é feita à mão (em vez de `FileManager.enumerator`) porque precisamos
/// **podar** a árvore: quando um `node_modules` é encontrado, ele vira um resultado e
/// não é percorrido — descer nele custaria minutos e não acharia nada de novo.
struct Scanner: Sendable {
    struct Progress: Sendable {
        var currentPath: String
        var found: Int
        var scannedDirs: Int
    }

    let rules: [Rule]
    let minimumSize: Int64
    let maxDepth: Int

    init(rules: [Rule] = Rule.catalog, minimumSize: Int64 = 0, maxDepth: Int = 12) {
        self.rules = rules
        self.minimumSize = minimumSize
        self.maxDepth = maxDepth
    }

    /// Índices de regra por nome, para decidir em O(1) a cada entrada visitada.
    private var rulesByName: [String: [Rule]] {
        Dictionary(grouping: rules, by: \.name)
    }

    /// Varre as raízes e entrega os achados em lotes, para a UI ir preenchendo.
    func scan(
        roots: [URL],
        onProgress: @Sendable @escaping (Progress) -> Void,
        onBatch: @Sendable @escaping ([Finding]) -> Void
    ) async {
        let index = rulesByName
        var progress = Progress(currentPath: "", found: 0, scannedDirs: 0)
        var batch: [Finding] = []

        for root in roots {
            guard !Task.isCancelled else { break }
            await walk(root, depth: 0, project: nil, index: index, progress: &progress, batch: &batch,
                       onProgress: onProgress, onBatch: onBatch)
        }
        if !batch.isEmpty { onBatch(batch) }
        onProgress(progress)
    }

    private func walk(
        _ dir: URL,
        depth: Int,
        /// Raiz do projeto que engloba `dir`, se já cruzamos uma.
        project: URL?,
        index: [String: [Rule]],
        progress: inout Progress,
        batch: inout [Finding],
        onProgress: @Sendable @escaping (Progress) -> Void,
        onBatch: @Sendable @escaping ([Finding]) -> Void
    ) async {
        guard depth <= maxDepth, !Task.isCancelled else { return }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else { return }

        progress.scannedDirs += 1
        if progress.scannedDirs % 40 == 0 {
            progress.currentPath = dir.path(percentEncoded: false)
            onProgress(progress)
        }

        // Nomes presentes neste diretório: é o que valida os sentinelas das regras
        // (`dist/` só conta como lixo se houver um `package.json` aqui).
        let siblings = Set(entries.map(\.lastPathComponent))

        // Raiz do projeto para tudo abaixo daqui. `.git` sempre vence — é o limite do
        // repositório. Os demais marcadores só valem se ainda não temos raiz; senão um
        // `src-tauri/Cargo.toml` roubaria o grupo do app Tauri que o contém.
        let project: URL? = if siblings.contains(".git") {
            dir
        } else if project == nil, Self.projectMarkers.contains(where: siblings.contains) {
            dir
        } else {
            project
        }
        var subdirs: [URL] = []

        for entry in entries {
            guard !Task.isCancelled else { return }
            guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true else { continue }
            let isDir = values.isDirectory == true
            let name = entry.lastPathComponent

            if let matched = index[name]?.first(where: { $0.matches(isDirectory: isDir, siblings: siblings) }) {
                guard PathGuard.isRemovable(entry) else { continue }
                if let finding = await makeFinding(at: entry, rule: matched, isDirectory: isDir,
                                                   project: project ?? dir),
                   finding.size >= minimumSize {
                    batch.append(finding)
                    progress.found += 1
                    if batch.count >= 15 {
                        onBatch(batch)
                        batch.removeAll(keepingCapacity: true)
                    }
                }
                continue // poda: alvo encontrado, não descemos nele
            }

            if isDir, PathGuard.shouldDescend(into: entry) { subdirs.append(entry) }
        }

        for sub in subdirs {
            await walk(sub, depth: depth + 1, project: project, index: index, progress: &progress,
                       batch: &batch, onProgress: onProgress, onBatch: onBatch)
        }
    }

    private func makeFinding(at url: URL, rule: Rule, isDirectory: Bool, project: URL) async -> Finding? {
        let usage = isDirectory ? DiskUsage.measure(url) : DiskUsage.measureFile(url)
        guard usage.size > 0 || !isDirectory else { return nil }
        return Finding(
            url: url,
            origin: .project(ruleID: rule.id, ecosystem: rule.ecosystem, root: project),
            size: usage.size,
            fileCount: usage.files,
            modified: usage.modified,
            detail: rule.detail,
            title: nil,
            regenerable: rule.regenerable,
            clearContentsOnly: false
        )
    }

    /// Marcadores de raiz usados quando não há um `.git` acima — projetos soltos,
    /// fora de repositório.
    static let projectMarkers: Set<String> = [
        "package.json", "Cargo.toml", "go.mod", "pyproject.toml", "setup.py",
        "requirements.txt", "pom.xml", "build.gradle", "build.gradle.kts", "Package.swift",
        "Podfile", "composer.json", "Gemfile", "pubspec.yaml", "CMakeLists.txt", "Makefile",
    ]
}

private extension Rule {
    func matches(isDirectory: Bool, siblings: Set<String>) -> Bool {
        switch matcher {
        case .directory(_, let required):
            guard isDirectory else { return false }
            return required.isEmpty || required.contains(where: siblings.contains)
        case .file:
            return !isDirectory
        }
    }
}
