import SwiftUI

/// Janela "Sobre". Substitui a padrão do AppKit porque a padrão só mostra nome e
/// versão — aqui cabem autoria, repositório e licença, que é o que alguém procura
/// num app gratuito e de código aberto.
struct AboutView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reclaim")
                        .font(.title.weight(.semibold))
                    Text(L.t("Get your disk space back."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(L.t("Version %@", Self.version))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                Divider().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    LabeledLink(label: L.t("Developer"), text: "Paulo Victor Mesquita",
                                url: "https://github.com/mesquitadev")
                    LabeledLink(label: L.t("Source"), text: "github.com/mesquitadev/reclaim",
                                url: "https://github.com/mesquitadev/reclaim")
                    LabeledLink(label: L.t("Issues"), text: L.t("Report a problem"),
                                url: "https://github.com/mesquitadev/reclaim/issues")
                }

                Divider().padding(.vertical, 2)

                Text(L.t("Free and open source under the MIT license."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 460, alignment: .leading)
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

/// Uma linha `rótulo → link`, alinhada em coluna.
private struct LabeledLink: View {
    let label: String
    let text: String
    let url: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Link(text, destination: URL(string: url)!)
                .font(.callout)
        }
    }
}
