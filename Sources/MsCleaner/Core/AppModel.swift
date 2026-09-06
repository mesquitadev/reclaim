import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum ToggleState { case off, mixed, on }

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
    /// Além do catálogo curado, varrer tudo que houver em ~/Library/Caches e ~/.cache.
    var discoverAppCaches: Bool {
        didSet { Defaults.discoverAppCaches = discoverAppCaches }
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
    /// Agrupado por projeto (padrão) ou lista corrida ordenada por tamanho.
    var grouped: Bool = true
    var collapsedGroups: Set<String> = []

    private var task: Task<Void, Never>?

    init() {
        roots = Defaults.roots
        enabledRuleIDs = Defaults.enabledRuleIDs
        includeGlobalCaches = Defaults.includeGlobalCaches
        discoverAppCaches = Defaults.discoverAppCaches
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

    /// A árvore visível: pastas escaneadas, os diretórios do caminho, os projetos
    /// e — no fim — as categorias de cache.
    var tree: [TreeNode] {
        TreeBuilder(roots: roots).build(from: visibleFindings)
    }

    /// A árvore achatada na ordem em que aparece na tela: um nó, depois sua
    /// subárvore se estiver aberto. É essa sequência que as setas percorrem — por
    /// isso ela vive no modelo, e não na view.
    var flatRows: [FlatRow] {
        flatten(tree, depth: 0)
    }

    private func flatten(_ nodes: [TreeNode], depth: Int) -> [FlatRow] {
        nodes.flatMap { node -> [FlatRow] in
            let row = FlatRow.node(node, depth: depth)
            guard isExpanded(node) else { return [row] }
            return [row]
                + flatten(node.children, depth: depth + 1)
                + node.leaves.map { .leaf($0, depth: depth + 1, parentID: node.id) }
        }
    }

    /// Todos os nós, em qualquer profundidade — para achar o que está sob o cursor.
    var allNodes: [TreeNode] {
        func collect(_ nodes: [TreeNode]) -> [TreeNode] {
            nodes.flatMap { [$0] + collect($0.children) }
        }
        return collect(tree)
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

    var sizeByCacheCategory: [CacheCategory: Int64] {
        findings.reduce(into: [:]) { acc, finding in
            guard let category = finding.cacheCategory else { return }
            acc[category, default: 0] += finding.size
        }
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
        let cacheScanner = CacheScanner(discoverUnknown: discoverAppCaches,
                                        minimumSize: Int64(minimumSizeMB) * 1_048_576)

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
                await cacheScanner.scan(onBatch: sink)
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
        // Nada entra marcado. Um scan que já vem com tudo selecionado transforma
        // um clique distraído em perda de gigabytes; marcar é decisão do usuário,
        // e o menu Seleção dá os atalhos (reconstruível, sem uso há 30/90 dias).
        findings.append(contentsOf: batch)
    }

    private func finishScan() {
        let deduplicated = findings.withoutNested
        if deduplicated.count != findings.count {
            let kept = Set(deduplicated.map(\.url))
            selection.formIntersection(kept)
            findings = deduplicated
        }
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

    /// Estado do checkbox mestre, considerando só o que está visível.
    var masterSelectionState: ToggleState {
        let visible = visibleFindings
        guard !visible.isEmpty else { return .off }
        let marked = visible.count { selection.contains($0.url) }
        if marked == 0 { return .off }
        return marked == visible.count ? .on : .mixed
    }

    func setMasterSelection(_ on: Bool) {
        let urls = visibleFindings.map(\.url)
        if on { selection.formUnion(urls) } else { selection.subtract(urls) }
    }

    /// Estado do checkbox de um nó, considerando a subárvore inteira.
    func selectionState(of node: TreeNode) -> ToggleState {
        let all = node.allFindings
        guard !all.isEmpty else { return .off }
        let marked = all.count { selection.contains($0.url) }
        if marked == 0 { return .off }
        return marked == all.count ? .on : .mixed
    }

    func setSelection(of node: TreeNode, on: Bool) {
        let urls = node.allFindings.map(\.url)
        if on { selection.formUnion(urls) } else { selection.subtract(urls) }
    }

    func isExpanded(_ node: TreeNode) -> Bool { !collapsedGroups.contains(node.id) }

    func setExpanded(_ node: TreeNode, _ expanded: Bool) {
        if expanded { collapsedGroups.remove(node.id) } else { collapsedGroups.insert(node.id) }
    }

    func expandAll() { collapsedGroups.removeAll() }

    func collapseAll() { collapsedGroups = Set(allNodes.map(\.id)) }
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
