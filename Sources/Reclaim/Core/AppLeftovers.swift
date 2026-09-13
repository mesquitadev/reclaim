import Foundation

/// Encontra o que um app deixa para trás.
///
/// Arrastar o app para o Lixo tira só o bundle. Preferências, containers,
/// caches e — o que mais importa — agentes que continuam subindo no login
/// ficam onde estão, invisíveis, às vezes por anos.
enum AppLeftovers {
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    /// Uma pasta onde procurar, e a família a que o achado pertence.
    private struct Place {
        let url: URL
        let kind: Leftover.Kind
        /// Se verdadeiro, casa também por nome do app, não só por bundle ID.
        /// Vale onde os apps historicamente usam o nome de exibição.
        let matchesName: Bool
    }

    private static var places: [Place] {
        let library = home.appending(path: "Library")
        let system = URL(filePath: "/Library")
        return [
            Place(url: library.appending(path: "Application Support"), kind: .support, matchesName: true),
            Place(url: library.appending(path: "Containers"), kind: .container, matchesName: false),
            Place(url: library.appending(path: "Group Containers"), kind: .container, matchesName: false),
            Place(url: library.appending(path: "Caches"), kind: .cache, matchesName: true),
            Place(url: library.appending(path: "HTTPStorages"), kind: .cache, matchesName: false),
            Place(url: library.appending(path: "WebKit"), kind: .cache, matchesName: false),
            Place(url: library.appending(path: "Preferences"), kind: .preferences, matchesName: false),
            Place(url: library.appending(path: "Preferences/ByHost"), kind: .preferences, matchesName: false),
            Place(url: library.appending(path: "Saved Application State"), kind: .state, matchesName: false),
            Place(url: library.appending(path: "Logs"), kind: .logs, matchesName: true),
            Place(url: library.appending(path: "Cookies"), kind: .other, matchesName: false),
            Place(url: library.appending(path: "LaunchAgents"), kind: .launch, matchesName: false),
            // Fora da pasta pessoal: exigem administrador, e é onde vivem os
            // daemons que sobrevivem à remoção do app.
            Place(url: system.appending(path: "Application Support"), kind: .support, matchesName: true),
            Place(url: system.appending(path: "LaunchAgents"), kind: .launch, matchesName: false),
            Place(url: system.appending(path: "LaunchDaemons"), kind: .launch, matchesName: false),
            Place(url: system.appending(path: "PrivilegedHelperTools"), kind: .launch, matchesName: false),
            Place(url: URL(filePath: "/private/var/db/receipts"), kind: .receipts, matchesName: false),
        ]
    }

    /// Normaliza para comparar nomes que o mesmo fabricante escreve de formas
    /// diferentes: "IntelliJ IDEA" vira a pasta "IntelliJIdea2026.1".
    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Procura dentro da pasta do fabricante.
    ///
    /// Os resíduos que realmente pesam raramente ficam na raiz de
    /// `Application Support`: vão para uma pasta do fabricante e, dentro dela,
    /// uma por versão — `JetBrains/Rider2026.2`. Sem descer esse nível a
    /// ferramenta encontra um plist de 4 KB e ignora dezenas de gigabytes.
    private static func vendorMatches(in place: Place, app: InstalledApp) -> [Leftover] {
        // O fabricante é o segundo componente do identificador: com.VENDOR.app.
        let parts = app.bundleID.split(separator: ".")
        guard parts.count >= 2 else { return [] }
        let vendor = normalized(String(parts[1]))
        guard vendor.count >= 3 else { return [] }

        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: place.url, includingPropertiesForKeys: nil) else { return [] }

        let target = normalized(app.name)
        let suffix = normalized(String(parts.last ?? ""))
        guard target.count >= 3 else { return [] }

        var found: [Leftover] = []
        for folder in folders where normalized(folder.lastPathComponent) == vendor {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil) else { continue }
            for child in children {
                let name = normalized(child.lastPathComponent)
                // Prefixo, para casar "Rider2026.2" com "Rider" — é assim que
                // as pastas por versão são nomeadas.
                guard name.hasPrefix(target) || (suffix.count >= 3 && name.hasPrefix(suffix)),
                      PathGuard.isRemovable(child) else { continue }
                let size = child.hasDirectoryPath
                    ? DiskUsage.measure(child).size
                    : DiskUsage.measureFile(child).size
                found.append(Leftover(url: child, size: size, kind: place.kind,
                                      reason: .vendorFolder))
            }
        }
        return found
    }

    /// Monta o plano de remoção completo do app.
    static func plan(for app: InstalledApp) -> UninstallPlan {
        var found: [Leftover] = [
            Leftover(url: app.url, size: app.size, kind: .app,
                     reason: .isApp),
        ]
        var seen: Set<URL> = [app.url]

        for place in places {
            for item in matches(in: place, app: app) + vendorMatches(in: place, app: app)
            where !seen.contains(item.url) {
                seen.insert(item.url)
                found.append(item)
            }
        }
        return UninstallPlan(app: app, leftovers: found)
    }

    private static func matches(in place: Place, app: InstalledApp) -> [Leftover] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: place.url, includingPropertiesForKeys: nil) else { return [] }

        let bundleID = app.bundleID.lowercased()
        // O sufixo do identificador ("Bar" em com.foo.Bar) e o nome do app
        // cobrem as pastas que não usam o identificador inteiro.
        let suffix = (app.bundleID.split(separator: ".").last.map(String.init) ?? "").lowercased()
        let name = app.name.lowercased()

        return contents.compactMap { url in
            let item = url.lastPathComponent.lowercased()
            let bare = url.deletingPathExtension().lastPathComponent.lowercased()

            let reason: Leftover.Reason
            if bare == bundleID || item.hasPrefix(bundleID + ".") || bare.hasPrefix(bundleID + ".") {
                reason = .exactBundleID
            } else if item.contains(bundleID) {
                reason = .containsBundleID
            } else if place.matchesName, bare == name || bare == suffix,
                      // Nomes curtos e genéricos casariam com pastas de outros
                      // apps; exigir alguma extensão evita apagar por engano.
                      name.count >= 4 || suffix.count >= 4 {
                reason = .namedAfterApp
            } else {
                return nil
            }

            guard PathGuard.isRemovable(url) else { return nil }
            let size = url.hasDirectoryPath
                ? DiskUsage.measure(url).size
                : DiskUsage.measureFile(url).size
            return Leftover(url: url, size: size, kind: place.kind, reason: reason)
        }
    }
}
