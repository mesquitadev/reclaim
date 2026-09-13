import Foundation

/// As frentes do Reclaim. A promessa é a mesma — recuperar espaço — mas as
/// perguntas são diferentes o bastante para merecerem telas próprias.
enum Tool: String, CaseIterable, Identifiable, Sendable {
    case development, duplicates, large, junk, apps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .development: "Development"
        case .duplicates: "Duplicates"
        case .large: "Large files"
        case .junk: "File clutter"
        case .apps: "Uninstall apps"
        }
    }

    var symbol: String {
        switch self {
        case .development: "hammer"
        case .duplicates: "doc.on.doc"
        case .large: "arrow.up.right.square"
        case .junk: "trash"
        case .apps: "trash.square"
        }
    }

    var subtitle: String {
        switch self {
        case .development: "Build output and tool caches"
        case .duplicates: "Same content, several places"
        case .large: "What takes the most room"
        case .junk: "Installers, leftovers, empty folders"
        case .apps: "Remove an app and everything it left"
        }
    }

    /// Varrem pastas de arquivos comuns, não projetos.
    var scansFiles: Bool { self != .development && self != .apps }

    /// A desinstalação tem raízes próprias (as pastas de aplicativos) e um
    /// fluxo próprio, então não usa nem a barra lateral nem a busca das outras.
    var usesScanRoots: Bool { self != .apps }
}
