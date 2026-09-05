import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle, scanning, cleaning
        case done(reclaimed: Int64, failures: Int)
    }

    // Configuração
    var roots: [URL] {
        didSet { Defaults.roots = roots }
    }
    var enabledRuleIDs: Set<String> {
        didSet { Defaults.enabledRuleIDs = enabledRuleIDs }
    }
    var includeGlobalCaches: Bool {
        didSet { Defaults.includeGlobalCaches = includeGlobalCaches }
    }
    var mode: Cleaner.Mode {
        didSet { Defaults.mode = mode }
    }
    /// Ignora achados abaixo desse tamanho — corta o ruído de milhares de `__pycache__`.
    var minimumSizeMB: Int {
        didSet { Defaults.minimumSizeMB = minimumSizeMB }
    }

    // Estado do scan
    private(set) var phase: Phase = .idle
    private(set) var findings: [Finding] = []
    private(set) var currentPath: String = ""
    private(set) var scannedDirs: Int = 0
    var selection: Set<URL> = []
    var search: String = ""
    var filter: Ecosystem?

    private var task: Task<Void, Never>?

    init() {
        roots = Defaults.roots
        enabledRuleIDs = Defaults.enabledRuleIDs
        includeGlobalCaches = Defaults.includeGlobalCaches
        mode = Defaults.mode
        minimumSizeMB = Defaults.minimumSizeMB
    }

    // MARK: - Derivados

    var isBusy: Bool { phase == .scanning || phase == .cleaning }

    var visibleFindings: [Finding] {
        findings
            .filter { finding in
                guard let filter else { return true }
                return finding.ecosystem == filter
            }
            .filter { finding in
                guard !search.isEmpty else { return true }
                let needle = search.lowercased()
                return finding.name.lowercased().contains(needle)
                    || (finding.projectName?.lowercased().contains(needle) ?? false)
                    || finding.url.path(percentEncoded: false).lowercased().contains(needle)
            }
            .sorted { $0.size > $1.size }
    }

    var selectedFindings: [Finding] {
        findings.filter { selection.contains($0.url) }
    }

    var totalFound: Int64 { findings.totalSize }

    /// Quanto cada ecossistema ocupa — alimenta a barra lateral.
    var sizeByEcosystem: [Ecosystem: Int64] {
        findings.reduce(into: [:]) { acc, finding in
            guard let eco = finding.ecosystem else { return }
            acc[eco, default: 0] += finding.size
        }
    }

    var globalCacheTotal: Int64 {
        findings.filter(\.isGlobalCache).totalSize
    }

    var freeSpace: Int64? {
        DiskUsage.availableCapacity(at: FileManager.default.homeDirectoryForCurrentUser)
    }

    // MARK: - Ações

    func toggleRule(_ id: String, on: Bool) {
        if on { enabledRuleIDs.insert(id) } else { enabledRuleIDs.remove(id) }
    }

    func addRoot(_ url: URL) {
        guard !roots.contains(url) else { return }
        roots.append(url)
    }

    func removeRoot(_ url: URL) {
        roots.removeAll { $0 == url }
    }

    func startScan() {
        task?.cancel()
        findings = []
        selection = []
        currentPath = ""
        scannedDirs = 0
        phase = .scanning

        let rules = Rule.catalog.filter { enabledRuleIDs.contains($0.id) }
        let scanner = Scanner(rules: rules, minimumSize: Int64(minimumSizeMB) * 1_048_576)
        let roots = roots
        let wantsCaches = includeGlobalCaches

        task = Task { [weak self] in
            guard let self else { return }
            let sink: @Sendable ([Finding]) -> Void = { batch in
                Task { @MainActor in self.absorb(batch) }
            }
            await scanner.scan(
                roots: roots,
                onProgress: { progress in
                    Task { @MainActor in
                        self.currentPath = progress.currentPath
                        self.scannedDirs = progress.scannedDirs
                    }
                },
                onBatch: sink
            )
            if wantsCaches, !Task.isCancelled {
                await CacheScanner().scan(onBatch: sink)
            }
            self.finishScan()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func absorb(_ batch: [Finding]) {
        findings.append(contentsOf: batch)
        // Pré-seleção só do que é reconstruível por um comando — o resto o usuário marca.
        for finding in batch where finding.regenerable {
            selection.insert(finding.url)
        }
    }

    private func finishScan() {
        currentPath = ""
        phase = .idle
    }

    func clean() {
        let targets = selectedFindings
        guard !targets.isEmpty else { return }
        phase = .cleaning
        let cleaner = Cleaner(mode: mode)

        task = Task { [weak self] in
            guard let self else { return }
            let outcome = await Task.detached(priority: .userInitiated) {
                cleaner.clean(targets) { finding in
                    Task { @MainActor in
                        self.currentPath = finding.url.path(percentEncoded: false)
                    }
                }
            }.value

            let removed = Set(outcome.removed.map(\.url))
            findings.removeAll { removed.contains($0.url) }
            selection.subtract(removed)
            currentPath = ""
            phase = .done(reclaimed: outcome.reclaimed, failures: outcome.failures.count)
        }
    }

    func dismissResult() {
        if case .done = phase { phase = .idle }
    }

    // MARK: - Seleção em massa

    func selectAllVisible() { selection.formUnion(visibleFindings.map(\.url)) }
    func deselectAll() { selection.removeAll() }
    func selectOnlyRegenerable() {
        selection = Set(findings.filter(\.regenerable).map(\.url))
    }
    /// Marca o que não é tocado há mais de `days` dias — o critério mais seguro na prática.
    func selectStale(days: Int) {
        let cutoff = TimeInterval(days) * 86_400
        selection = Set(findings.filter { $0.age > cutoff }.map(\.url))
    }
}
