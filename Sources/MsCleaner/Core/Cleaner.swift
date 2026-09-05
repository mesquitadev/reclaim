import Foundation

/// Remove os achados. Por padrão manda para a Lixeira — reversível — e só apaga
/// definitivamente se o usuário pedir.
struct Cleaner: Sendable {
    enum Mode: String, CaseIterable, Sendable {
        case trash, delete

        var label: String {
            switch self {
            case .trash: "Mover para a Lixeira"
            case .delete: "Apagar definitivamente"
            }
        }
    }

    struct Outcome: Sendable {
        var removed: [Finding] = []
        var failures: [(finding: Finding, message: String)] = []
        var reclaimed: Int64 { removed.totalSize }
    }

    let mode: Mode

    func clean(_ findings: [Finding], onProgress: @Sendable (Finding) -> Void) -> Outcome {
        var outcome = Outcome()
        for finding in findings {
            guard PathGuard.isRemovable(finding.url) else {
                outcome.failures.append((finding, "Caminho protegido"))
                continue
            }
            onProgress(finding)
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
