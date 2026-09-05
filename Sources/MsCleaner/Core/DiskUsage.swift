import Foundation

/// Mede tamanho em disco de arquivos e árvores.
enum DiskUsage {
    struct Result: Sendable {
        var size: Int64 = 0
        var files: Int = 0
        var modified: Date = .distantPast
    }

    /// Soma o espaço realmente alocado da subárvore. Usa `totalFileAllocatedSize` — é o
    /// número que o Finder mostra e o que você recupera de fato ao apagar.
    static func measure(_ url: URL) -> Result {
        var result = Result()
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey,
                                      .isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [] // inclui arquivos ocultos: eles contam para o tamanho
        ) else { return measureFile(url) }

        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isRegularFile == true {
                result.size += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                result.files += 1
            }
            if let date = values.contentModificationDate, date > result.modified {
                result.modified = date
            }
        }
        if result.modified == .distantPast {
            result.modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .now
        }
        return result
    }

    static func measureFile(_ url: URL) -> Result {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey,
                                                       .contentModificationDateKey])
        return Result(
            size: Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0),
            files: 1,
            modified: values?.contentModificationDate ?? .now
        )
    }

    /// Espaço livre no volume que contém `url`, para mostrar o antes/depois.
    static func availableCapacity(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
