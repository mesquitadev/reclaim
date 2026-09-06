import Foundation

/// Uma linha da árvore já achatada para exibição e para a navegação por teclado.
enum FlatRow: Identifiable, Sendable {
    case header(FindingGroup)
    case child(Finding, groupID: String)

    var id: String {
        switch self {
        case .header(let group): "h:\(group.id)"
        case .child(let finding, _): "c:\(finding.url.path(percentEncoded: false))"
        }
    }

    var group: FindingGroup? {
        if case .header(let group) = self { return group }
        return nil
    }

    var finding: Finding? {
        if case .child(let finding, _) = self { return finding }
        return nil
    }

    /// Id do grupo ao qual a linha pertence — o próprio, se for cabeçalho.
    var owningGroupID: String {
        switch self {
        case .header(let group): group.id
        case .child(_, let groupID): groupID
        }
    }
}
