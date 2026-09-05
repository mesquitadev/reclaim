import Foundation

/// Cache global de ferramenta de desenvolvimento — vive fora dos projetos, no home
/// do usuário. Sempre reconstruído sob demanda pela própria ferramenta.
struct GlobalCache: Identifiable, Sendable {
    let id: String
    let name: String
    /// Caminho relativo ao home do usuário.
    let relativePath: String
    let detail: String
    /// Quando true, o conteúdo do diretório é removido mas o diretório em si fica.
    /// Algumas ferramentas quebram se o diretório-raiz desaparecer.
    let clearContentsOnly: Bool

    init(_ id: String, _ name: String, _ relativePath: String, detail: String, clearContentsOnly: Bool = false) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.detail = detail
        self.clearContentsOnly = clearContentsOnly
    }

    var url: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: relativePath, directoryHint: .isDirectory)
    }

    static let catalog: [GlobalCache] = [
        .init("xcode-derived", "Xcode DerivedData", "Library/Developer/Xcode/DerivedData",
              detail: "Índices e builds intermediários do Xcode", clearContentsOnly: true),
        .init("xcode-archives", "Xcode Archives", "Library/Developer/Xcode/Archives",
              detail: "Arquivos .xcarchive de builds antigos", clearContentsOnly: true),
        .init("xcode-devicesupport", "iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport",
              detail: "Símbolos de dispositivos já conectados", clearContentsOnly: true),
        .init("simulators-caches", "Caches do CoreSimulator", "Library/Developer/CoreSimulator/Caches",
              detail: "Caches de runtime dos simuladores", clearContentsOnly: true),
        .init("npm-cache", "npm", ".npm/_cacache", detail: "Cache de pacotes do npm", clearContentsOnly: true),
        .init("yarn-cache", "Yarn", "Library/Caches/Yarn", detail: "Cache de pacotes do Yarn", clearContentsOnly: true),
        .init("pnpm-store", "pnpm store", "Library/pnpm/store", detail: "Store de conteúdo do pnpm", clearContentsOnly: true),
        .init("bun-cache", "Bun", ".bun/install/cache", detail: "Cache de instalação do Bun", clearContentsOnly: true),
        .init("cargo-registry", "Cargo registry", ".cargo/registry", detail: "Crates baixados", clearContentsOnly: true),
        .init("go-modcache", "Go module cache", "go/pkg/mod", detail: "Módulos Go baixados", clearContentsOnly: true),
        .init("go-build", "Go build cache", "Library/Caches/go-build", detail: "Cache de compilação do Go", clearContentsOnly: true),
        .init("gradle-caches", "Gradle", ".gradle/caches", detail: "Dependências e build cache do Gradle", clearContentsOnly: true),
        .init("maven-repo", "Maven (~/.m2)", ".m2/repository", detail: "Repositório local do Maven", clearContentsOnly: true),
        .init("pip-cache", "pip", "Library/Caches/pip", detail: "Wheels e downloads do pip", clearContentsOnly: true),
        .init("uv-cache", "uv", ".cache/uv", detail: "Cache do uv", clearContentsOnly: true),
        .init("pods-cache", "CocoaPods", "Library/Caches/CocoaPods", detail: "Especificações e pods em cache", clearContentsOnly: true),
        .init("carthage-cache", "Carthage", "Library/Caches/org.carthage.CarthageKit",
              detail: "Builds em cache do Carthage", clearContentsOnly: true),
        .init("swiftpm-cache", "SwiftPM", "Library/Caches/org.swift.swiftpm",
              detail: "Cache de dependências do SwiftPM", clearContentsOnly: true),
        .init("composer-cache", "Composer", ".composer/cache", detail: "Cache de pacotes do Composer", clearContentsOnly: true),
        .init("nuget-cache", "NuGet", ".nuget/packages", detail: "Pacotes NuGet baixados", clearContentsOnly: true),
        .init("pub-cache", "Dart pub", ".pub-cache", detail: "Pacotes Dart/Flutter baixados", clearContentsOnly: true),
        .init("gem-cache", "RubyGems", ".gem", detail: "Gems em cache", clearContentsOnly: true),
        .init("puppeteer", "Puppeteer / Chromium", ".cache/puppeteer",
              detail: "Builds de Chromium baixados", clearContentsOnly: true),
        .init("electron", "Electron", "Library/Caches/electron", detail: "Binários do Electron", clearContentsOnly: true),
        .init("ccache", "ccache", ".ccache", detail: "Cache do compilador C/C++", clearContentsOnly: true),
    ]
}
