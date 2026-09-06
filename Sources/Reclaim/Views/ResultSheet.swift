import SwiftUI

struct ResultSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 42))
                .foregroundStyle(failures > 0 || cancelled ? .orange : .green)

            Text(L.t("%@ reclaimed", reclaimed.formattedBytes))
                .font(.title2.weight(.semibold))

            if cancelled {
                Text(L.t("You stopped the cleanup; what already went is gone, and the rest stays selected."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if failures > 0 {
                Text(L.t("%@ items could not be removed — likely in use or missing permission.", "\(failures)"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if model.mode == .trash {
                Text(L.t("The items are in the Trash; empty it to actually free the space."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                if model.mode == .trash {
                    Button(L.t("Open Trash")) {
                        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash"))
                    }
                }
                Button(L.t("Done")) { model.dismissResult() }
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
