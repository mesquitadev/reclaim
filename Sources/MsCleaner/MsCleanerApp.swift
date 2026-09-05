import SwiftUI

@main
struct MsCleanerApp: App {
    @State private var model = AppModel()

    init() {
        HeadlessRun.runIfRequested()
    }

    var body: some Scene {
        Window("MsCleaner", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Escanear") { model.startScan() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}
