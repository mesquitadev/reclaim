import SwiftUI

struct ResultSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 42))
                .foregroundStyle(failures > 0 || cancelled ? .orange : .green)

            Text("\(reclaimed.formattedBytes) liberados")
                .font(.title2.weight(.semibold))

            if cancelled {
                Text("Você parou a limpeza; o que já saiu não volta, e o resto segue marcado.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if failures > 0 {
                Text("\(failures) item\(failures == 1 ? "" : "s") não pôde ser removido — provavelmente falta permissão ou está em uso.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if model.mode == .trash {
                Text("Os itens estão na Lixeira; esvazie-a para liberar o espaço de fato.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                if model.mode == .trash {
                    Button("Abrir Lixeira") {
                        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash"))
                    }
                }
                Button("Pronto") { model.dismissResult() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 360)
    }

    private var symbol: String {
        if failures > 0 { return "exclamationmark.triangle.fill" }
        return cancelled ? "hand.raised.fill" : "checkmark.circle.fill"
    }

    private var reclaimed: Int64 {
        if case .done(let value, _, _) = model.phase { return value }
        return 0
    }

    private var failures: Int {
        if case .done(_, let count, _) = model.phase { return count }
        return 0
    }

    private var cancelled: Bool {
        if case .done(_, _, let cancelled) = model.phase { return cancelled }
        return false
    }
}
