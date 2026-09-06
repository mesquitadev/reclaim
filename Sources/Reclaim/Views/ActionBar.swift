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

            Picker(L.t("When cleaning"), selection: Binding(get: { model.mode }, set: { model.mode = $0 })) {
                ForEach(Cleaner.Mode.allCases, id: \.self) { Text(L.t($0.label)).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Button {
                confirming = true
            } label: {
                Label(L.t("Clean %@", "\(model.selectedFindings.count)"), systemImage: model.mode == .trash ? "trash" : "flame")
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
            Button(L.t(confirmLabel), role: model.mode == .delete ? .destructive : nil) {
                model.clean()
            }
            Button(L.t("Cancel"), role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var title: String {
        let count = model.selectedFindings.count
        let size = model.selectedFindings.totalSize.formattedBytes
        return model.mode == .delete
            ? L.t("Delete %@ items (%@) permanently?", "\(count)", size)
            : L.t("Move %@ items (%@) to the Trash?", "\(count)", size)
    }

    private var confirmLabel: String {
        model.mode == .delete ? "Delete" : "Move to Trash"
    }

    private var confirmMessage: String {
        let risky = model.selectedFindings.filter { !$0.regenerable }
        var parts: [String] = []
        if !risky.isEmpty {
            let names = risky.prefix(3).map(\.name).joined(separator: ", ")
            parts.append(L.t("%@ of the selected items are not restored by a command: %@.",
                             "\(risky.count)", names + (risky.count > 3 ? "…" : "")))
        }
        parts.append(L.t(model.mode == .delete
            ? "This skips the Trash and cannot be undone."
            : "The items go to the Trash; the space is only freed when you empty it."))
        return parts.joined(separator: " ")
    }

    private var summary: String {
        let selected = model.selectedFindings
        guard !selected.isEmpty else { return L.t("Nothing selected") }
        return L.t("%@ across %@ items", selected.totalSize.formattedBytes, "\(selected.count)")
    }

    private var subtitle: String {
        guard !model.selection.isEmpty else {
            return L.t("Select what you want removed — or use Selection ▸ Select only what a command rebuilds")
        }
        let risky = model.selectedFindings.filter { !$0.regenerable }.count
        if risky > 0 {
            return L.t(risky == 1 ? "%@ selected item is not restored by a command"
                                  : "%@ selected items are not restored by a command", "\(risky)")
        }
        return L.t("Everything selected is rebuilt automatically by your tools")
    }
}
