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
                if model.mode == .delete { confirming = true } else { model.clean() }
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
        .confirmationDialog("Apagar definitivamente \(model.selectedFindings.count) itens?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Apagar \(model.selectedFindings.totalSize.formattedBytes)", role: .destructive) {
                model.clean()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Isso não passa pela Lixeira e não pode ser desfeito.")
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

    private var summary: String {
        let selected = model.selectedFindings
        guard !selected.isEmpty else { return "Nada marcado" }
        return "\(selected.totalSize.formattedBytes) em \(selected.count) itens"
    }

    private var subtitle: String {
        let risky = model.selectedFindings.filter { !$0.regenerable }.count
        if risky > 0 {
            return "\(risky) item\(risky == 1 ? "" : "s") marcado\(risky == 1 ? "" : "s") não é recriado por um comando"
        }
        return "Tudo marcado é reconstruído automaticamente pelas ferramentas"
    }
}
