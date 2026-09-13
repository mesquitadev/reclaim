import Foundation

/// Percorre pastas comuns coletando arquivos e seus metadados.
///
/// Uma varredura só alimenta as quatro visões — duplicados, grandes, lixo e
/// esquecidos. Percorrer o disco quatro vezes seria quatro vezes o custo para
/// obter exatamente a mesma lista.
struct FileScanner: Sendable {
    struct Progress: Sendable {
        var scanned: Int
        var currentPath: String
    }

    /// Abaixo disso nada compensa: um duplicado de 4 KB não recupera espaço, e
    /// listá-lo só afoga o que importa.
    let minimumSize: Int64
    let maxDepth: Int

    init(minimumSize: Int64 = 1_048_576, maxDepth: Int = 12) {
        self.minimumSize = minimumSize
        self.maxDepth = maxDepth
    }

    func scan(
        roots: [URL],
        onProgress: @Sendable @escaping (Progress) -> Void
    ) async -> [FileEntry] {
        var files: [FileEntry] = []
        var scanned = 0

        for root in roots {
            guard !Task.isCancelled else { break }
            walk(root, depth: 0, into: &files, scanned: &scanned, onProgress: onProgress)
        }
        return files
    }

    private func walk(
        _ directory: URL,
        depth: Int,
        into files: inout [FileEntry],
        scanned: inout Int,
        onProgress: @Sendable (Progress) -> Void
    ) {
        guard depth <= maxDepth, !Task.isCancelled else { return }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
                                      .fileSizeKey, .totalFileAllocatedSizeKey,
                                      .contentModificationDateKey, .contentAccessDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [])
        else { return }

        for entry in entries {
            guard !Task.isCancelled else { return }
            guard let values = try? entry.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true
            else { continue }

            // Um .app ou .photoslibrary é um diretório, mas para o usuário é uma
            // coisa só: entrar nele produziria "duplicados" que são apenas
            // recursos internos de dois programas parecidos.
            if values.isDirectory == true, values.isPackage != true {
                guard PathGuard.shouldDescend(into: entry) else { continue }
                walk(entry, depth: depth + 1, into: &files, scanned: &scanned, onProgress: onProgress)
                continue
            }

            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            scanned += 1
            if scanned % 200 == 0 {
                onProgress(Progress(scanned: scanned, currentPath: entry.path(percentEncoded: false)))
            }
            guard size >= minimumSize else { continue }

            files.append(FileEntry(
                url: entry,
                size: size,
                modified: values.contentModificationDate ?? .distantPast,
                accessed: values.contentAccessDate ?? values.contentModificationDate ?? .distantPast,
                isPackage: values.isPackage == true
            ))
        }
    }
}
