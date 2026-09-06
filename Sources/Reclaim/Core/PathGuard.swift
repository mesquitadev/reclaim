import Foundation

/// Barreira de segurança: decide o que nunca pode ser tocado, independentemente
/// do que as regras encontrarem.
enum PathGuard {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath()

    /// Diretórios cuja remoção seria catastrófica ou sem sentido.
    private static let forbiddenExact: Set<String> = {
        var paths: Set<String> = ["/", "/System", "/Library", "/Applications", "/usr", "/bin",
                                  "/sbin", "/etc", "/var", "/private", "/Volumes", "/opt", "/Users"]
        paths.insert(home.path)
        for sub in ["Desktop", "Documents", "Downloads", "Pictures", "Music", "Movies",
                    "Library", "Applications", ".ssh", ".gnupg", ".config", ".git"] {
            paths.insert(home.appending(path: sub).path)
        }
        return paths
    }()

    /// Componentes de caminho que abortam o scan inteiro daquela subárvore.
    private static let forbiddenComponents: Set<String> = [
        ".Trash", ".ssh", ".gnupg", "Library/Keychains", "iCloud Drive",
        "com.apple.CloudDocs", "Photos Library.photoslibrary", "Time Machine Backups",
    ]

    /// Um caminho pode ser removido?
    static func isRemovable(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        guard path.count > 1, !forbiddenExact.contains(path) else { return false }
        // Nada fora do home, exceto se o usuário apontou explicitamente para lá
        // (o scan já parte de raízes escolhidas por ele).
        guard !forbiddenComponents.contains(where: { path.contains("/\($0)") }) else { return false }
        return true
    }

    /// Vale a pena descer nesse diretório durante o scan?
    static func shouldDescend(into url: URL) -> Bool {
        let name = url.lastPathComponent
        // Bundles do macOS são opacos: um .app ou .framework não contém "lixo de projeto".
        if name.hasPrefix("."), !descendableDotDirs.contains(name) { return false }
        if opaqueExtensions.contains(url.pathExtension) { return false }
        return isRemovable(url)
    }

    /// Diretórios ocultos que ainda interessam (porque são eles mesmos alvos, ou contêm alvos).
    private static let descendableDotDirs: Set<String> = [
        ".next", ".nuxt", ".svelte-kit", ".build", ".gradle", ".dart_tool", ".terraform",
    ]

    private static let opaqueExtensions: Set<String> = [
        "app", "framework", "bundle", "xcodeproj", "xcworkspace", "playground",
        "photoslibrary", "photolibrary", "sparsebundle", "dSYM", "kext", "plugin",
    ]
}
