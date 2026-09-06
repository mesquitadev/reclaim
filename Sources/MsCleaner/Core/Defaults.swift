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

    static var mode: Cleaner.Mode {
        get { Cleaner.Mode(rawValue: store.string(forKey: Key.mode) ?? "") ?? .trash }
        set { store.set(newValue.rawValue, forKey: Key.mode) }
    }

    static var minimumSizeMB: Int {
        get { store.object(forKey: Key.minimumSizeMB) as? Int ?? 1 }
        set { store.set(newValue, forKey: Key.minimumSizeMB) }
    }
}
