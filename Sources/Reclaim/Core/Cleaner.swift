import Foundation

/// Remove os achados. Por padrão manda para a Lixeira — reversível — e só apaga
/// definitivamente se o usuário pedir.
struct Cleaner: Sendable {
    enum Mode: String, CaseIterable, Sendable {
        case trash, delete

        var label: String {
            switch self {
            case .trash: "Move to Trash"
            case .delete: "Delete permanently"
            }
        }
    }

    struct Outcome: Sendable {
        var removed: [Finding] = []
        var failures: [(finding: Finding, message: String)] = []
        /// O usuário parou no meio; o que já saiu, saiu.
        var cancelled = false
        var reclaimed: Int64 { removed.totalSize }
    }

    /// Sinal de parada compartilhado com a UI. A remoção roda fora do MainActor e
    /// não herda o cancelamento da `Task`, então o pedido chega por aqui.
    final class CancelFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var stopped = false

        var isCancelled: Bool { lock.withLock { stopped } }
        func cancel() { lock.withLock { stopped = true } }
    }

    let mode: Mode

    /// `onProgress` é chamado antes de cada remoção, com quantos já saíram e
    /// quanto espaço isso somou.
    func clean(
        _ findings: [Finding],
        cancelFlag: CancelFlag,
        onProgress: @Sendable (Int, Finding, Int64) -> Void
    ) -> Outcome {
        var outcome = Outcome()
        for (index, finding) in findings.enumerated() {
            guard !cancelFlag.isCancelled else {
                outcome.cancelled = true
                break
            }
            guard PathGuard.isRemovable(finding.url) else {
                outcome.failures.append((finding, "Caminho protegido"))
                continue
            }
            onProgress(index, finding, outcome.reclaimed)
            do {
                if finding.clearContentsOnly {
                    try clearContents(of: finding.url)
                } else {
                    try remove(finding.url)
                }
                outcome.removed.append(finding)
            } catch {
                outcome.failures.append((finding, error.localizedDescription))
            }
        }
        return outcome
    }

    private func remove(_ url: URL) throws {
        switch mode {
        case .trash:
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        case .delete:
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Esvazia um diretório mantendo-o: caches globais em que a ferramenta espera
    /// que a raiz exista (o Xcode, por exemplo, com DerivedData).
    private func clearContents(of url: URL) throws {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        var firstError: Error?
        for entry in entries {
            do { try remove(entry) } catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
    }
}
