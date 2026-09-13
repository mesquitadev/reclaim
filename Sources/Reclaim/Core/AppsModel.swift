import Foundation
import Observation
import AppKit

/// O estado da tela de desinstalação.
@MainActor
@Observable
final class AppsModel {
    private(set) var apps: [InstalledApp] = []
    private(set) var isScanning = false
    /// Quantos apps já tiveram o tamanho medido, para mostrar o progresso sem
    /// travar a lista.
    private(set) var measured = 0
    private(set) var plan: UninstallPlan?
    private(set) var isBuildingPlan = false

    var selectedApp: InstalledApp?
    var search = ""
    /// O que sai junto. Começa marcado só no que é certo — casar por nome é
    /// palpite, e palpite não deve vir pré-aprovado.
    var chosen: Set<URL> = []

    /// Começa por nome porque, no primeiro instante, nenhum tamanho foi medido
    /// ainda — ordenar por um número que não existe embaralharia a lista à
    /// medida que as medidas chegassem.
    var sortBySize = false

    var visibleApps: [InstalledApp] {
        let base = apps.filter { !$0.isProtected }
        let filtered = search.isEmpty ? base : base.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleID.localizedCaseInsensitiveContains(search)
        }
        return sortBySize
            // Os ainda não medidos (-1) vão para o fim, e não para o topo.
            ? filtered.sorted { ($0.isMeasured ? $0.size : -1) > ($1.isMeasured ? $1.size : -1) }
            : filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var totalInstalled: Int64 {
        apps.filter { !$0.isProtected && $0.isMeasured }.reduce(0) { $0 + $1.size }
    }

    var isMeasuring: Bool { !apps.isEmpty && measured < apps.count }

    /// Quanto será recuperado com a seleção atual.
    var chosenSize: Int64 {
        guard let plan else { return 0 }
        return plan.leftovers.filter { chosen.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    /// Itens escolhidos que o app não consegue remover sem administrador.
    var chosenPrivileged: [Leftover] {
        guard let plan else { return [] }
        return plan.leftovers.filter { chosen.contains($0.url) && $0.needsAdmin }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        measured = 0

        Task {
            let found = await Task.detached(priority: .userInitiated) {
                AppInventory.scan()
            }.value
            apps = found
            isScanning = false
            measureSizes()
        }
    }

    /// Mede os tamanhos um a um, devolvendo cada resultado à lista assim que
    /// sai. A lista já está na tela; os números aparecem conforme chegam, em vez
    /// de todos juntos depois de quinze segundos de espera.
    private func measureSizes() {
        let snapshot = apps
        Task {
            for app in snapshot {
                let size = await Task.detached(priority: .utility) {
                    AppInventory.measure(app)
                }.value
                guard let index = apps.firstIndex(where: { $0.url == app.url }) else { continue }
                apps[index].size = size
                measured += 1
            }
        }
    }

    /// Monta o plano do app escolhido.
    func inspect(_ app: InstalledApp) {
        selectedApp = app
        plan = nil
        chosen = []
        isBuildingPlan = true

        Task {
            let built = await Task.detached(priority: .userInitiated) {
                AppLeftovers.plan(for: app)
            }.value
            guard selectedApp == app else { return }
            plan = built
            chosen = Set(built.leftovers.filter { $0.reason.isCertain }.map(\.url))
            isBuildingPlan = false
        }
    }

    func toggle(_ leftover: Leftover) {
        if chosen.contains(leftover.url) {
            chosen.remove(leftover.url)
        } else {
            chosen.insert(leftover.url)
        }
    }

    func chooseAll(_ on: Bool) {
        chosen = on ? Set(plan?.leftovers.map(\.url) ?? []) : []
    }

    /// Os itens escolhidos, prontos para o `Cleaner` que o app já usa.
    var findingsToRemove: [Finding] {
        guard let plan else { return [] }
        return plan.leftovers
            .filter { chosen.contains($0.url) && !$0.needsAdmin }
            .map { leftover in
                Finding(
                    url: leftover.url,
                    origin: .appLeftover(bundleID: plan.app.bundleID, kind: leftover.kind),
                    size: leftover.size,
                    fileCount: 0,
                    modified: .distantPast,
                    detail: leftover.kind.label,
                    title: leftover.name,
                    // Nada aqui volta sozinho: isto é desinstalação, não limpeza
                    // de cache. A remoção vai para a Lixeira, que é a rede.
                    regenerable: false,
                    clearContentsOnly: false)
            }
    }

    func isRunning(_ app: InstalledApp) -> Bool { AppInventory.isRunning(app) }

    func quit(_ app: InstalledApp) { AppInventory.quit(app) }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Abre o desinstalador que veio com o app.
    ///
    /// Quando ele existe, é o caminho certo: só ele sabe desfazer registros que
    /// o instalador fez fora do alcance de uma remoção de arquivos.
    func openUninstaller(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
