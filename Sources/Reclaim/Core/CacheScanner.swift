import Foundation

/// Mede os caches globais: primeiro o catálogo curado, depois — se pedido — tudo
/// mais que estiver em `~/Library/Caches` e `~/.cache`, que é onde os apps do
/// sistema despejam cache sem pedir licença.
struct CacheScanner: Sendable {
    let caches: [GlobalCache]
    /// Varrer também os caches não catalogados.
    let discoverUnknown: Bool
    let minimumSize: Int64

    init(caches: [GlobalCache] = GlobalCache.catalog,
         discoverUnknown: Bool = true,
         minimumSize: Int64 = 0) {
        self.caches = caches
        self.discoverUnknown = discoverUnknown
        self.minimumSize = minimumSize
    }

    func scan(onBatch: @Sendable ([Finding]) -> Void) async {
        var batch: [Finding] = []

        for cache in caches {
            guard !Task.isCancelled else { break }
            guard let finding = measure(cache) else { continue }
            batch.append(finding)
            if batch.count >= 4 {
                onBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }

        if discoverUnknown {
            for finding in await discover() {
                guard !Task.isCancelled else { break }
                batch.append(finding)
                if batch.count >= 4 {
                    onBatch(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }
        }

        if !batch.isEmpty { onBatch(batch) }
    }

    private func measure(_ cache: GlobalCache) -> Finding? {
        let url = cache.url
        guard FileManager.default.fileExists(atPath: url.path), PathGuard.isRemovable(url) else { return nil }
        let usage = DiskUsage.measure(url)
        guard usage.size >= max(minimumSize, 1) else { return nil }
        return Finding(
            url: url,
            origin: .globalCache(id: cache.id, category: cache.category),
            size: usage.size,
            fileCount: usage.files,
            modified: usage.modified,
            detail: cache.detail,
            title: cache.name,
            regenerable: cache.safeByDefault,
            clearContentsOnly: cache.clearContentsOnly
        )
    }

    /// Cada subdiretório de primeiro nível das raízes de cache vira um achado.
    /// Não descemos mais fundo: o dono do cache é o app, e é nessa granularidade
    /// que faz sentido escolher.
    private func discover() async -> [Finding] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let curated = GlobalCache.curatedPaths
        var results: [Finding] = []

        for root in GlobalCache.discoveryRoots {
            let rootURL = home.appending(path: root, directoryHint: .isDirectory)
            guard let entries = try? fm.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            for entry in entries {
                guard !Task.isCancelled else { return results }
                guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isDirectory == true, values.isSymbolicLink != true else { continue }
                let path = entry.standardizedFileURL.path
                guard !curated.contains(path), PathGuard.isRemovable(entry) else { continue }

                let usage = DiskUsage.measure(entry)
                guard usage.size >= max(minimumSize, 1) else { continue }
                results.append(Finding(
                    url: entry,
                    origin: .globalCache(id: "discovered:\(path)", category: .discovered),
                    size: usage.size,
                    fileCount: usage.files,
                    modified: usage.modified,
                    detail: "Cache de app em ~/\(root)",
                    title: nil,
                    // Cache de app é reconstruível, mas não é dev-junk: exige escolha
                    // explícita em vez de vir marcado.
                    regenerable: false,
                    clearContentsOnly: true
                ))
            }
        }
        return results
    }
}
