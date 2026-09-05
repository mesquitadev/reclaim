import Foundation

/// Algo que o scan encontrou e que pode ser removido.
struct Finding: Identifiable, Sendable, Hashable {
    enum Origin: Sendable, Hashable {
        /// Encontrado dentro de um projeto, por uma `Rule`.
        case project(ruleID: String, ecosystem: Ecosystem, projectName: String)
        /// Cache global de ferramenta.
        case globalCache(id: String)
    }

    let url: URL
    let origin: Origin
    let size: Int64
    let fileCount: Int
    let modified: Date
    let detail: String
    /// Regenerável com um comando conhecido — usado para a pré-seleção segura.
    let regenerable: Bool
    /// Remover só o conteúdo, preservando o diretório.
    let clearContentsOnly: Bool

    var id: URL { url }

    var name: String { url.lastPathComponent }

    var ecosystem: Ecosystem? {
        if case .project(_, let eco, _) = origin { return eco }
        return nil
    }

    var projectName: String? {
        if case .project(_, _, let name) = origin { return name }
        return nil
    }

    var isGlobalCache: Bool {
        if case .globalCache = origin { return true }
        return false
    }

    var age: TimeInterval { Date.now.timeIntervalSince(modified) }
}

extension Sequence where Element == Finding {
    var totalSize: Int64 { reduce(0) { $0 + $1.size } }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
