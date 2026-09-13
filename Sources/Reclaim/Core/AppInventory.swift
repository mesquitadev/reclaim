import Foundation
import AppKit

/// Lista o que está instalado.
enum AppInventory {
    /// Onde apps moram no macOS. `~/Applications` existe para instalações que
    /// não pediram senha, e é justamente onde ficam muitos apps esquecidos.
    static var searchRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(filePath: "/Applications"),
            URL(filePath: "/Applications/Utilities"),
            home.appending(path: "Applications"),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Mede o tamanho de um app. Separado da listagem porque é a parte cara.
    static func measure(_ app: InstalledApp) -> Int64 {
        DiskUsage.measure(app.url).size
    }

    static func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seen: Set<String> = []

        for root in searchRoots {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { continue }

            for url in contents {
                if url.pathExtension == "app" {
                    add(url, to: &apps, seen: &seen)
                    continue
                }
                // Suítes instalam uma pasta com vários apps dentro
                // ("Adobe Acrobat DC/", "Epson Software/"). Ficar só no primeiro
                // nível deixaria de fora justamente os que mais espalham
                // resíduo pelo sistema.
                guard url.hasDirectoryPath else { continue }
                let inner = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles])) ?? []
                for child in inner where child.pathExtension == "app" {
                    add(child, to: &apps, seen: &seen)
                }
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func add(_ url: URL, to apps: inout [InstalledApp], seen: inout Set<String>) {
        guard let app = describe(url), !seen.contains(app.bundleID) else { return }
        seen.insert(app.bundleID)
        apps.append(app)
    }

    /// Lê o que o bundle declara sobre si.
    static func describe(_ url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }

        let info = bundle.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let values = try? url.resourceValues(forKeys: [
            .contentAccessDateKey, .contentModificationDateKey,
        ])

        return InstalledApp(
            url: url,
            bundleID: bundleID,
            name: name,
            version: info["CFBundleShortVersionString"] as? String,
            // -1 marca "ainda não medido"; quem mede é o modelo, em segundo plano.
            size: -1,
            // A data de último acesso é a melhor pista disponível sobre uso.
            // Não é exata — uma indexação do sistema também a toca —, por isso
            // aparece como indício, nunca como afirmação.
            lastUsed: values?.contentAccessDate ?? values?.contentModificationDate,
            bundledUninstaller: findUninstaller(near: url, name: name, bundleID: bundleID))
    }

    /// Procura um desinstalador que o app tenha trazido consigo.
    ///
    /// Vários instaladores — drivers, antivírus, suítes grandes — registram
    /// componentes que só o desinstalador deles sabe desfazer. Arrastar o app
    /// para o Lixo nesses casos deixa serviço rodando. Quando existe um, o certo
    /// é apontá-lo, não competir com ele.
    static func findUninstaller(near appURL: URL, name: String, bundleID: String) -> URL? {
        let manager = FileManager.default
        /// Cada candidato vem com a exigência de provar que é deste app.
        var candidates: [(url: URL, mustMentionApp: Bool)] = []

        // Dentro do próprio bundle: o dono é certo, o nome não precisa provar nada.
        for sub in ["Contents/Resources", "Contents/MacOS", "Contents/Helpers"] {
            let dir = appURL.appending(path: sub)
            let found = (try? manager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            candidates += found.map { ($0, false) }
        }

        // Ao lado do app. Numa pasta do fabricante ("Epson Software/") a
        // vizinhança já é prova de dono; solto em `/Applications`, onde todo
        // app é vizinho de todo app, só o nome decide — senão um único
        // desinstalador seria atribuído a todos.
        let parent = appURL.deletingLastPathComponent()
        let neighbours = (try? manager.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        candidates += neighbours.map { ($0, isAppRoot(parent)) }

        // E numa pasta com o nome do app.
        for root in searchRoots {
            let folder = root.appending(path: name)
            let found = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            candidates += found.map { ($0, false) }
        }

        return candidates.first { candidate in
            let url = candidate.url
            guard url != appURL else { return false }
            // Alguns desinstaladores vêm sem extensão, como "Acrobat Uninstaller".
            let isBundle = url.pathExtension == "app" || url.pathExtension == "pkg"
            guard isBundle || url.hasDirectoryPath else { return false }

            let bare = url.deletingPathExtension().lastPathComponent.lowercased()
            let saysUninstall = bare.contains("uninstall") || bare.contains("desinstal")
                || bare.hasPrefix("remove")
            guard saysUninstall else { return false }

            return candidate.mustMentionApp
                ? mentions(app: name, bundleID: bundleID, in: bare)
                : true
        }?.url
    }

    /// As pastas onde apps convivem sem relação entre si.
    private static func isAppRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return searchRoots.contains { $0.standardizedFileURL.path == path }
    }

    /// O nome do candidato menciona este app?
    private static func mentions(app name: String, bundleID: String, in candidate: String) -> Bool {
        func squeeze(_ text: String) -> String {
            text.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let target = squeeze(name)
        let vendor = bundleID.split(separator: ".").dropFirst().first.map { squeeze(String($0)) } ?? ""
        let bare = squeeze(candidate)
        // Nomes curtos casariam por acaso.
        if target.count >= 4, bare.contains(target) { return true }
        if vendor.count >= 4, bare.contains(vendor) { return true }
        return false
    }

    /// O app está aberto agora? Remover um app em execução deixa o processo
    /// vivo e os arquivos meio apagados.
    static func isRunning(_ app: InstalledApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == app.bundleID }
    }

    /// Pede para o app encerrar, com jeitinho — sem forçar, para não perder
    /// trabalho não salvo de quem estava usando.
    @discardableResult
    static func quit(_ app: InstalledApp) -> Bool {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == app.bundleID }
        guard !running.isEmpty else { return true }
        return running.allSatisfy { $0.terminate() }
    }
}
