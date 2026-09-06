import SwiftUI

struct ActionBar: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(summary).font(.callout.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Ao limpar", selection: Binding(get: { model.mode }, set: { model.mode = $0 })) {
                ForEach(Cleaner.Mode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Button {
                confirming = true
            } label: {
                Label("Limpar \(model.selectedFindings.count)", systemImage: model.mode == .trash ? "trash" : "flame")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selection.isEmpty || model.isBusy)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        // A confirmação vale para os dois modos: mesmo a Lixeira, com tudo marcado,
        // move dezenas de gigabytes de uma vez.
        .confirmationDialog(title, isPresented: $confirming, titleVisibility: .visible) {
            Button(confirmLabel, role: model.mode == .delete ? .destructive : nil) {
                model.clean()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .overlay(alignment: .leading) {
            if model.phase == .cleaning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Limpando…").font(.caption)
                }
                .padding(.leading, 16)
                .background(.bar)
            }
        }
    }

    private var title: String {
        let count = model.selectedFindings.count
        let size = model.selectedFindings.totalSize.formattedBytes
        return model.mode == .delete
            ? "Apagar definitivamente \(count) \(count == 1 ? "item" : "itens") (\(size))?"
            : "Mover \(count) \(count == 1 ? "item" : "itens") (\(size)) para a Lixeira?"
    }

    private var confirmLabel: String {
        model.mode == .delete ? "Apagar" : "Mover para a Lixeira"
    }

    private var confirmMessage: String {
        let risky = model.selectedFindings.filter { !$0.regenerable }
        var parts: [String] = []
        if !risky.isEmpty {
            let names = risky.prefix(3).map(\.name).joined(separator: ", ")
            parts.append("\(risky.count) \(risky.count == 1 ? "item marcado não é recriado" : "itens marcados não são recriados") por um comando: \(names)\(risky.count > 3 ? "…" : "").")
        }
        parts.append(model.mode == .delete
            ? "Isso não passa pela Lixeira e não pode ser desfeito."
            : "Os itens vão para a Lixeira; o espaço só é liberado ao esvaziá-la.")
        return parts.joined(separator: " ")
    }

    private var summary: String {
        let selected = model.selectedFindings
        guard !selected.isEmpty else { return "Nada marcado" }
        return "\(selected.totalSize.formattedBytes) em \(selected.count) itens"
    }

    private var subtitle: String {
        guard !model.selection.isEmpty else {
            return "Marque o que quer remover — ou use Seleção ▸ Marcar só o reconstruível"
        }
        let risky = model.selectedFindings.filter { !$0.regenerable }.count
        if risky > 0 {
            return "\(risky) item\(risky == 1 ? "" : "s") marcado\(risky == 1 ? "" : "s") não é recriado por um comando"
        }
        return "Tudo marcado é reconstruído automaticamente pelas ferramentas"
    }
}
