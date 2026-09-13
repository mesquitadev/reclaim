import Foundation

/// Um aplicativo instalado, com o que é preciso para removê-lo por inteiro.
struct InstalledApp: Identifiable, Sendable, Hashable {
    let url: URL
    /// O identificador do bundle. É a âncora de tudo: quase todo resíduo que um
    /// app deixa é nomeado por ele, não pelo nome de exibição, que muda entre
    /// versões e traduções.
    let bundleID: String
    let name: String
    let version: String?
    /// Medido depois, em segundo plano: percorrer 84 bundles leva segundos, e
    /// a lista precisa aparecer imediatamente.
    var size: Int64
    /// Quando o app foi aberto pela última vez, se o sistema souber dizer.
    let lastUsed: Date?
    /// Um desinstalador que veio junto com o app.
    let bundledUninstaller: URL?

    var id: URL { url }

    /// `nil` enquanto ainda não foi medido — a linha mostra um traço em vez de
    /// um zero, que seria mentira.
    var isMeasured: Bool { size >= 0 }

    var formattedSize: String {
        isMeasured ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "—"
    }

    /// Há quanto tempo ninguém abre — a resposta para "posso tirar isso?".
    var idleDays: Int? {
        guard let lastUsed else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUsed, to: .now).day
    }

    /// Está fora do alcance? Apps da Apple e do sistema não se desinstalam, e
    /// oferecer isso só levaria a um erro de permissão ou a um estrago.
    var isProtected: Bool {
        bundleID.hasPrefix("com.apple.")
            || url.path.hasPrefix("/System/")
            || bundleID == Bundle.main.bundleIdentifier
    }

    /// Onde mora, para o usuário entender por que alguns pedem senha.
    var scope: Scope {
        url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) ? .user : .system
    }

    enum Scope: Sendable { case user, system }
}

/// Um rastro deixado por um app: preferências, cache, container, daemon.
struct Leftover: Identifiable, Sendable, Hashable {
    let url: URL
    /// Medido depois, em segundo plano: percorrer 84 bundles leva segundos, e
    /// a lista precisa aparecer imediatamente.
    var size: Int64
    let kind: Kind
    /// Por que este caminho foi atribuído a este app — mostrado ao usuário,
    /// porque apagar coisa em Library exige confiança no critério. Guardado
    /// como motivo, não como frase: traduzir é trabalho da tela.
    let reason: Reason

    /// Quão firme é a associação entre o resíduo e o app.
    enum Reason: String, Sendable {
        case isApp, exactBundleID, containsBundleID, namedAfterApp, vendorFolder

        var text: String {
            switch self {
            case .isApp: "The application itself"
            case .exactBundleID: "Matches the bundle identifier"
            case .containsBundleID: "Contains the bundle identifier"
            case .namedAfterApp: "Folder named after the app"
            case .vendorFolder: "Inside the vendor folder, named after the app"
            }
        }

        /// Casar por nome é palpite, não prova: um nome curto pode pertencer a
        /// outro app. Esses vêm desmarcados, para a remoção ser uma escolha.
        var isCertain: Bool { self != .namedAfterApp }
    }

    var id: URL { url }
    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Precisa de administrador? O que vive fora da pasta pessoal precisa.
    var needsAdmin: Bool {
        !url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path)
    }

    /// As famílias de resíduo, na ordem em que interessam a quem lê.
    enum Kind: String, CaseIterable, Sendable, Comparable {
        case app, support, container, preferences, cache, state, logs, launch, receipts, other

        var label: String {
            switch self {
            case .app: "Application"
            case .support: "Application support"
            case .container: "Container"
            case .preferences: "Preferences"
            case .cache: "Caches"
            case .state: "Saved state"
            case .logs: "Logs"
            case .launch: "Background items"
            case .receipts: "Install receipts"
            case .other: "Other"
            }
        }

        var symbol: String {
            switch self {
            case .app: "app.badge"
            case .support: "folder"
            case .container: "shippingbox"
            case .preferences: "slider.horizontal.3"
            case .cache: "clock.arrow.circlepath"
            case .state: "macwindow"
            case .logs: "doc.text"
            case .launch: "gearshape.2"
            case .receipts: "doc.badge.gearshape"
            case .other: "questionmark.folder"
            }
        }

        /// Itens que mantêm código rodando depois que o app some. São os que
        /// mais justificam a ferramenta: ninguém descobre sozinho que um daemon
        /// continuou ativo.
        var isRunningCode: Bool { self == .launch }

        private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
        static func < (a: Kind, b: Kind) -> Bool { a.order < b.order }
    }
}

/// Tudo o que será removido de um app, junto.
struct UninstallPlan: Sendable {
    let app: InstalledApp
    let leftovers: [Leftover]

    var totalSize: Int64 { leftovers.reduce(0) { $0 + $1.size } }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Itens fora da pasta pessoal, que o app não consegue remover sozinho.
    var privileged: [Leftover] { leftovers.filter(\.needsAdmin) }

    var byKind: [(Leftover.Kind, [Leftover])] {
        Dictionary(grouping: leftovers, by: \.kind)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.size > $1.size }) }
    }
}
