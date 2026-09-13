import Foundation

/// Persistência das preferências. Sem sandbox, guardar caminhos crus basta —
/// não há necessidade de security-scoped bookmarks.
enum Defaults {
    private static let store = UserDefaults.standard

    enum Key {
        static let roots = "roots"
        static let enabledRules = "enabledRules"
        static let includeGlobalCaches = "includeGlobalCaches"
        static let mode = "mode"
        static let minimumSizeMB = "minimumSizeMB"
        static let discoverAppCaches = "discoverAppCaches"
        static let language = "language"
        static let fileRoots = "fileRoots"
        static let fileMinimumSizeMB = "fileMinimumSizeMB"
        static let filesFollowProjectRoots = "filesFollowProjectRoots"
    }

    static var roots: [URL] {
        get {
            let paths = store.stringArray(forKey: Key.roots) ?? []
            let urls = paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            return urls.isEmpty ? defaultRoots : urls
        }
        set { store.set(newValue.map(\.path), forKey: Key.roots) }
    }

    /// Chutes razoáveis para onde alguém guarda código.
    private static var defaultRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Projects", "Developer", "Code", "dev", "src", "repos", "workspace"]
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static var enabledRuleIDs: Set<String> {
        get {
            guard let stored = store.stringArray(forKey: Key.enabledRules) else {
                // Estreia: liga só as regras cujo alvo um comando reconstrói.
                return Set(Rule.catalog.filter(\.regenerable).map(\.id))
            }
            return Set(stored)
        }
        set { store.set(Array(newValue), forKey: Key.enabledRules) }
    }

    static var includeGlobalCaches: Bool {
        get { store.object(forKey: Key.includeGlobalCaches) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.includeGlobalCaches) }
    }

    static var discoverAppCaches: Bool {
        get { store.object(forKey: Key.discoverAppCaches) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.discoverAppCaches) }
    }

    /// Idioma escolhido. O padrão é inglês — não a preferência do sistema — para
    /// que a primeira impressão seja a mesma em qualquer máquina; quem quiser
    /// português troca no seletor.
    static var language: Language {
        get { Language(rawValue: store.string(forKey: Key.language) ?? "") ?? .en }
        set { store.set(newValue.rawValue, forKey: Key.language) }
    }

    /// Pastas extras para duplicados e entulho, além das de projetos.
    static var fileRoots: [URL] {
        get {
            let paths = store.stringArray(forKey: Key.fileRoots) ?? []
            let urls = paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            // Sem padrão: as pastas de projetos já vêm do app, e adivinhar
            // Downloads e Documentos faria a ferramenta varrer o que ninguém
            // pediu.
            return urls
        }
        set { store.set(newValue.map(\.path), forKey: Key.fileRoots) }
    }

    static var filesFollowProjectRoots: Bool {
        get { store.object(forKey: Key.filesFollowProjectRoots) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.filesFollowProjectRoots) }
    }

    static var fileMinimumSizeMB: Int {
        get { store.object(forKey: Key.fileMinimumSizeMB) as? Int ?? 1 }
        set { store.set(newValue, forKey: Key.fileMinimumSizeMB) }
    }

    static var mode: Cleaner.Mode {
        get { Cleaner.Mode(rawValue: store.string(forKey: Key.mode) ?? "") ?? .trash }
        set { store.set(newValue.rawValue, forKey: Key.mode) }
    }

    static var minimumSizeMB: Int {
        get { store.object(forKey: Key.minimumSizeMB) as? Int ?? 1 }
        set { store.set(newValue, forKey: Key.minimumSizeMB) }
    }
}
