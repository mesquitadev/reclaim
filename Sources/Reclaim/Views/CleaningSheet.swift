import SwiftUI

/// Folha modal durante a limpeza. Além de mostrar o andamento, ela é a trava:
/// enquanto está na tela não dá para marcar, escanear ou disparar outra limpeza.
struct CleaningSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: model.mode == .trash ? "trash" : "flame")
                    .font(.title2)
                    .foregroundStyle(model.mode == .trash ? Color.accentColor : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L.t(model.mode == .trash ? "Moving to Trash" : "Deleting"))
                        .font(.headline)
                    Text(L.t("%@ of %@ · %@ so far", "\(progress.done)", "\(progress.total)", progress.reclaimed.formattedBytes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
            }

            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
                .animation(.default, value: progress.fraction)

            // O caminho é longo e muda rápido; truncar pela frente mantém à vista
            // a parte que identifica o item.
            Text(progress.current)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30, alignment: .top)

            HStack {
                Text(L.t("Large trees take a few seconds each."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L.t("Stop")) { model.stopCleaning() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .interactiveDismissDisabled()
    }

    private var progress: AppModel.CleanProgress { model.cleanProgress }
}
