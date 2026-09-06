import SwiftUI

/// Rodando pelo Xcode ou por `swift run`, o executável do SwiftPM não tem bundle
/// nem Info.plist — sem isso o LaunchServices trata o processo como acessório e a
/// janela nunca vem para a frente. Promover a política de ativação no lançamento
/// resolve, e é inofensivo quando o app já está empacotado.
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MsCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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
