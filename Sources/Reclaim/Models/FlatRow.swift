import Foundation

/// Uma linha da árvore já achatada para exibição e para a navegação por teclado.
/// `depth` é só recuo visual; a ordem da sequência é a ordem das setas.
enum FlatRow: Identifiable, Sendable {
    case node(TreeNode, depth: Int)
    case leaf(Finding, depth: Int, parentID: String)

    var id: String {
        switch self {
        case .node(let node, _): "n:" + node.id
        case .leaf(let finding, _, _): "l:" + finding.url.path(percentEncoded: false)
        }
    }

    var depth: Int {
        switch self {
        case .node(_, let depth), .leaf(_, let depth, _): depth
        }
    }

    var node: TreeNode? {
        if case .node(let node, _) = self { return node }
        return nil
    }

    var finding: Finding? {
        if case .leaf(let finding, _, _) = self { return finding }
        return nil
    }

    /// Nó ao qual a linha pertence — o próprio, se for um nó.
    var parentID: String? {
        switch self {
        case .node(let node, _): node.id
        case .leaf(_, _, let parentID): parentID
        }
    }
}
