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
struct ReclaimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow
    @State private var model = AppModel()

    init() {
        HeadlessRun.runIfRequested()
    }

    var body: some Scene {
        Window("Reclaim", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            // A janela padrão do AppKit só traz nome e versão; esta traz autoria,
            // repositório e licença.
            CommandGroup(replacing: .appInfo) {
                Button(L.t("About Reclaim")) {
                    openWindow(id: "about")
                }
            }
            CommandGroup(replacing: .help) {
                Link(L.t("Reclaim on GitHub"),
                     destination: URL(string: "https://github.com/mesquitadev/reclaim")!)
                Link(L.t("Report a problem"),
                     destination: URL(string: "https://github.com/mesquitadev/reclaim/issues")!)
            }
            CommandGroup(after: .newItem) {
                Button(L.t("Scan")) { model.startScan() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
        }

        Window(L.t("About Reclaim"), id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView().environment(model)
        }
    }
}
