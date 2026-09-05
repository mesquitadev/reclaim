import Foundation

/// Mede os caches globais de ferramentas de desenvolvimento no home do usuário.
struct CacheScanner: Sendable {
    let caches: [GlobalCache]

    init(caches: [GlobalCache] = GlobalCache.catalog) {
        self.caches = caches
    }

    func scan(onBatch: @Sendable ([Finding]) -> Void) async {
        var batch: [Finding] = []
        for cache in caches {
            guard !Task.isCancelled else { break }
            let url = cache.url
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let usage = DiskUsage.measure(url)
            guard usage.size > 0 else { continue }
            batch.append(Finding(
                url: url,
                origin: .globalCache(id: cache.id),
                size: usage.size,
                fileCount: usage.files,
                modified: usage.modified,
                detail: cache.detail,
                regenerable: true,
                clearContentsOnly: cache.clearContentsOnly
            ))
            if batch.count >= 4 {
                onBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty { onBatch(batch) }
    }
}
