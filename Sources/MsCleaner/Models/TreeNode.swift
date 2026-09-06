import Foundation

/// Um nó da árvore exibida. Diretórios intermediários, projetos e categorias de
/// cache são todos nós; os achados são as folhas.
struct TreeNode: Identifiable, Sendable {
    enum Kind: Sendable {
        /// Pasta escaneada, no topo.
        case root(URL)
        /// Pasta que só existe no caminho até os projetos (`MaisTech`, `clientes/x`).
        case directory(URL)
        /// Raiz de um projeto — onde estão o `.git` ou o manifesto.
        case project(URL, Ecosystem?)
        case cacheCategory(CacheCategory)
    }

    let id: String
    let kind: Kind
    let name: String
    var children: [TreeNode]
    /// Achados pendurados diretamente neste nó.
    var leaves: [Finding]

    var url: URL? {
        switch kind {
        case .root(let url), .directory(let url), .project(let url, _): url
        case .cacheCategory: nil
        }
    }

    /// Todos os achados da subárvore — é o que o checkbox do nó controla.
    var allFindings: [Finding] {
        leaves + children.flatMap(\.allFindings)
    }

    var size: Int64 { allFindings.totalSize }

    var count: Int { allFindings.count }

    var symbol: String {
        switch kind {
        case .root: "folder.fill"
        case .directory: "folder"
        case .project(_, let eco): eco?.symbol ?? "shippingbox"
        case .cacheCategory(let category): category.symbol
        }
    }

    var isProject: Bool {
        if case .project = kind { return true }
        return false
    }
}
