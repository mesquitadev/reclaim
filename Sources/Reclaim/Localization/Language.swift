import Foundation

/// Idiomas que o app fala. Inglês é o padrão; a preferência do sistema só é
/// seguida quando o usuário não escolheu explicitamente.
enum Language: String, CaseIterable, Identifiable, Sendable {
    case system, en, ptBR = "pt-BR"

    var id: String { rawValue }

    /// Nome no próprio idioma — é assim que um seletor de idioma deve se ler.
    var label: String {
        switch self {
        case .system: "System"
        case .en: "English"
        case .ptBR: "Português (Brasil)"
        }
    }

    /// O idioma efetivo: `.system` resolve pela preferência do macOS, caindo em
    /// inglês para qualquer idioma que não falamos.
    var resolved: Language {
        guard self == .system else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pt") ? .ptBR : .en
    }
}

/// Tradução. Uma tabela em Swift, e não `.lproj` + `NSLocalizedString`, por dois
/// motivos: o executável do SwiftPM não carrega bundles de recurso quando rodado
/// fora do `.app`, e trocar de idioma sem reiniciar exigiria recarregar o bundle
/// à mão. Aqui a troca é só uma mudança de estado observada pela UI.
@MainActor
enum L {
    /// Idioma corrente, já resolvido. Alterado por `AppModel`.
    static var current: Language = Defaults.language.resolved

    /// Traduz uma chave. Chaves são o texto em inglês, então uma chave sem
    /// tradução aparece em inglês em vez de aparecer como identificador cru.
    static func t(_ key: String) -> String {
        guard current == .ptBR, let translated = ptBR[key] else { return key }
        return translated
    }

    /// Interpolação posicional: `L.t("%@ of %@", "12", "90")`.
    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }
}
