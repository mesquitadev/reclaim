import Foundation

/// O que a barra lateral está filtrando. É um caso explícito em vez de um
/// `Ecosystem?` porque numa `List(selection:)` a tag `nil` significa "nada
/// selecionado" — a linha "Tudo" nunca podia ser escolhida.
enum Filter: Hashable, Sendable {
    case all
    case ecosystem(Ecosystem)
    case cache(CacheCategory)

    func matches(_ finding: Finding) -> Bool {
        switch self {
        case .all: true
        case .ecosystem(let eco): finding.ecosystem == eco
        case .cache(let category): finding.cacheCategory == category
        }
    }
}
