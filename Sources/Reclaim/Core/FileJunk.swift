import Foundation

/// Entulho de arquivos comuns — o que se acumula fora dos projetos.
enum FileJunk {
    struct Rule: Sendable {
        let id: String
        let detail: String
        let matches: @Sendable (FileEntry) -> Bool
    }

    /// Instaladores já usados são o caso mais rendoso: um .dmg de 2 GB que
    /// serviu uma vez e ficou. Só contam os antigos, porque um baixado hoje
    /// pode ainda não ter sido instalado.
    static let rules: [Rule] = [
        Rule(id: "installer", detail: "Installer kept after use") { file in
            ["dmg", "pkg", "iso", "msi"].contains(file.url.pathExtension.lowercased())
                && file.idleDays > 30
        },
        Rule(id: "partial", detail: "Interrupted download") { file in
            ["crdownload", "part", "download", "partial", "!ut"]
                .contains(file.url.pathExtension.lowercased())
        },
        Rule(id: "archive", detail: "Archive already extracted") { file in
            ["zip", "tar", "gz", "rar", "7z"].contains(file.url.pathExtension.lowercased())
                && file.idleDays > 90
                && FileManager.default.fileExists(
                    atPath: file.url.deletingPathExtension().path)
        },
        Rule(id: "metadata", detail: "Finder and system metadata") { file in
            [".DS_Store", "Thumbs.db", "desktop.ini", ".localized"].contains(file.name)
        },
        Rule(id: "backup", detail: "Editor backup file") { file in
            file.name.hasSuffix("~") || file.url.pathExtension.lowercased() == "bak"
        },
    ]

    static func classify(_ file: FileEntry) -> Rule? {
        rules.first { $0.matches(file) }
    }

    /// Pastas sem nenhum arquivo dentro, em nenhum nível. Ficam para trás
    /// quando algo é movido e ninguém repara.
    static func emptyDirectories(under roots: [URL], maxDepth: Int = 8) -> [URL] {
        var empties: [URL] = []

        func isEmpty(_ url: URL, depth: Int) -> Bool {
            guard depth <= maxDepth,
                  let entries = try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            else { return false }

            // Uma pasta que só tem .DS_Store está vazia para quem olha.
            let meaningful = entries.filter { $0.lastPathComponent != ".DS_Store" }
            if meaningful.isEmpty { return true }

            var allEmpty = true
            for entry in meaningful {
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                if isDirectory, isEmpty(entry, depth: depth + 1) {
                    empties.append(entry)
                } else {
                    allEmpty = false
                }
            }
            return allEmpty
        }

        for root in roots where PathGuard.isRemovable(root) {
            _ = isEmpty(root, depth: 0)
        }
        return empties
    }
}
