import Foundation
import CryptoKit

/// Encontra arquivos com conteúdo idêntico.
///
/// Comparar por conteúdo, não por nome: dois arquivos com nomes diferentes e
/// bytes iguais são duplicados; dois com o mesmo nome e conteúdos diferentes
/// não são. Nome igual é coincidência, conteúdo igual é fato.
///
/// A busca tem três estágios, cada um descartando a maior parte do trabalho do
/// seguinte. Ler tudo de todos seria inviável: numa pasta de 20 GB, o hash
/// completo de cada arquivo significa ler 20 GB.
enum DuplicateFinder {
    struct Progress: Sendable {
        var stage: Stage
        var done: Int
        var total: Int

        enum Stage: Sendable {
            case grouping    // por tamanho, sem ler nada
            case sampling    // lendo só as pontas
            case hashing     // lendo por inteiro
        }
    }

    /// 64 KB do começo e do fim. Arquivos diferentes que comecem igual —
    /// cabeçalhos de vídeo, XML com o mesmo preâmbulo — quase sempre diferem no
    /// fim, então amostrar as duas pontas separa muito melhor que só o início.
    private static let sampleSize = 64 * 1024

    static func find(
        in files: [FileEntry],
        onProgress: @Sendable @escaping (Progress) -> Void
    ) -> [DuplicateGroup] {
        // Estágio 1: agrupar por tamanho. Dois arquivos de tamanhos diferentes
        // não podem ser idênticos, e isso não custa leitura nenhuma.
        let bySize = Dictionary(grouping: files, by: \.size)
            .filter { $0.value.count > 1 }
        guard !bySize.isEmpty else { return [] }

        onProgress(Progress(stage: .grouping, done: 0, total: bySize.count))

        // Estágio 2: amostra das pontas. Descarta quase tudo lendo 128 KB por
        // arquivo em vez do arquivo inteiro.
        var candidates: [String: [FileEntry]] = [:]
        var sampled = 0
        let toSample = bySize.values.reduce(0) { $0 + $1.count }

        for (size, group) in bySize {
            guard !Task.isCancelled else { return [] }
            for file in group {
                sampled += 1
                if sampled % 20 == 0 {
                    onProgress(Progress(stage: .sampling, done: sampled, total: toSample))
                }
                guard let sample = sampleDigest(of: file.url, size: size) else { continue }
                candidates["\(size):\(sample)", default: []].append(file)
            }
        }

        let survivors = candidates.filter { $0.value.count > 1 }
        guard !survivors.isEmpty else { return [] }

        // Estágio 3: hash completo, só para quem sobreviveu. Sem ele, dois
        // arquivos que coincidam nas pontas seriam declarados iguais — e apagar
        // por engano é exatamente o erro que não se pode cometer aqui.
        var groups: [String: [FileEntry]] = [:]
        var hashed = 0
        let toHash = survivors.values.reduce(0) { $0 + $1.count }

        for (_, group) in survivors {
            guard !Task.isCancelled else { return [] }
            for file in group {
                hashed += 1
                if hashed % 5 == 0 {
                    onProgress(Progress(stage: .hashing, done: hashed, total: toHash))
                }
                guard let digest = fullDigest(of: file.url) else { continue }
                groups[digest, default: []].append(file)
            }
        }

        return groups
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(digest: $0.key, files: $0.value.sorted { $0.modified < $1.modified }) }
            .sorted { $0.reclaimable > $1.reclaimable }
    }

    private static func sampleDigest(of url: URL, size: Int64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        guard let head = try? handle.read(upToCount: sampleSize) else { return nil }
        hasher.update(data: head)

        if size > Int64(sampleSize) * 2 {
            try? handle.seek(toOffset: UInt64(size) - UInt64(sampleSize))
            if let tail = try? handle.read(upToCount: sampleSize) { hasher.update(data: tail) }
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func fullDigest(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
