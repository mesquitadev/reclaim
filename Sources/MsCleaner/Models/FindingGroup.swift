import Foundation

/// Os achados de um mesmo projeto, reunidos sob o diretório que os contém.
/// Os caches globais formam um grupo à parte, sem projeto.
struct FindingGroup: Identifiable, Sendable {
    enum Kind: Sendable {
        /// Diretório do projeto (o pai dos achados).
        case project(URL)
        case cacheCategory(CacheCategory)
    }

    let kind: Kind
    let name: String
    /// Onde o projeto fica, relativo à pasta escaneada — desempata nomes repetidos
    /// como dois `src-tauri` de apps diferentes.
    let context: String?
    let findings: [Finding]

    var id: String {
        switch kind {
        case .project(let url): url.path(percentEncoded: false)
        case .cacheCategory(let category): "__cache__\(category.rawValue)"
        }
    }

    var url: URL? {
        if case .project(let url) = kind { return url }
        return nil
    }

    var size: Int64 { findings.totalSize }

    /// Ecossistemas presentes, para o ícone do cabeçalho quando há um só.
    var ecosystems: Set<Ecosystem> {
        Set(findings.compactMap(\.ecosystem))
    }

    var symbol: String {
        switch kind {
        case .cacheCategory(let category): return category.symbol
        case .project:
            let ecos = ecosystems
            return ecos.count == 1 ? ecos.first!.symbol : "folder"
        }
    }
}
