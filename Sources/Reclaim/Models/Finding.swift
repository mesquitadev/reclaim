import Foundation

/// Algo que o scan encontrou e que pode ser removido.
struct Finding: Identifiable, Sendable, Hashable {
    enum Origin: Sendable, Hashable {
        /// Encontrado dentro de um projeto, por uma `Rule`. `root` é o diretório do
        /// projeto de verdade (o que tem `.git`, `package.json`, `Cargo.toml`…), não
        /// o pai imediato — é por ele que a listagem agrupa.
        case project(ruleID: String, ecosystem: Ecosystem, root: URL)
        /// Cache global de ferramenta ou de app.
        case globalCache(id: String, category: CacheCategory)
    }

    let url: URL
    let origin: Origin
    let size: Int64
    let fileCount: Int
    let modified: Date
    let detail: String
    /// Nome curado, quando o do diretório não identifica nada (`~/.nvm/.cache`
    /// mostrado como "nvm", não como ".cache").
    let title: String?
    /// Regenerável com um comando conhecido — usado para a pré-seleção segura.
    let regenerable: Bool
    /// Remover só o conteúdo, preservando o diretório.
    let clearContentsOnly: Bool

    var id: URL { url }

    var name: String { title ?? url.lastPathComponent }

    var ecosystem: Ecosystem? {
        if case .project(_, let eco, _) = origin { return eco }
        return nil
    }

    var projectRoot: URL? {
        if case .project(_, _, let root) = origin { return root }
        return nil
    }

    var projectName: String? { projectRoot?.lastPathComponent }

    /// Caminho do achado relativo à raiz do projeto — o que distingue dois
    /// `__pycache__` do mesmo projeto na listagem agrupada.
    var pathInProject: String? {
        guard let root = projectRoot else { return nil }
        let rootPath = root.path(percentEncoded: false)
        let full = url.deletingLastPathComponent().path(percentEncoded: false)
        guard full.hasPrefix(rootPath) else { return nil }
        let relative = String(full.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? nil : relative
    }

    var isGlobalCache: Bool { cacheCategory != nil }

    var cacheCategory: CacheCategory? {
        if case .globalCache(_, let category) = origin { return category }
        return nil
    }

    var age: TimeInterval { Date.now.timeIntervalSince(modified) }
}

extension Sequence where Element == Finding {
    var totalSize: Int64 { reduce(0) { $0 + $1.size } }

    /// Sem os achados que vivem dentro de outro achado. A poda do scanner já evita
    /// isso na maioria dos casos, mas ela depende de o nome do diretório casar uma
    /// regra; esta passada garante que remover o pai não deixa filhos órfãos na
    /// lista — nem o tamanho deles contado duas vezes.
    var withoutNested: [Finding] {
        let sorted = sorted { $0.url.path(percentEncoded: false) < $1.url.path(percentEncoded: false) }
        var kept: [Finding] = []
        var enclosing: String?

        for finding in sorted {
            let path = finding.url.path(percentEncoded: false)
            if let enclosing, path.hasPrefix(enclosing) { continue }
            kept.append(finding)
            enclosing = path.hasSuffix("/") ? path : path + "/"
        }
        return kept
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
