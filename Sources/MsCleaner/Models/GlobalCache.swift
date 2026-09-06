import Foundation

/// Onde um cache vive e o quanto ele é "de desenvolvimento".
enum CacheCategory: String, CaseIterable, Sendable, Hashable {
    /// Gerenciadores de pacote e toolchains — sempre reconstruídos sob demanda.
    case packageManager
    /// Xcode, simuladores, Android SDK, Docker: pesados e reconstruíveis, mas custam
    /// tempo de download/rebuild.
    case buildTooling
    /// Caches de editores e IDEs.
    case editor
    /// Logs e relatórios de falha.
    case logs
    /// Caches de aplicativos descobertos no sistema, fora do catálogo curado.
    case discovered

    var label: String {
        switch self {
        case .packageManager: "Gerenciadores de pacote"
        case .buildTooling: "Ferramentas de build"
        case .editor: "Editores e IDEs"
        case .logs: "Logs e relatórios"
        case .discovered: "Outros caches de apps"
        }
    }

    var symbol: String {
        switch self {
        case .packageManager: "shippingbox"
        case .buildTooling: "hammer"
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .logs: "doc.text"
        case .discovered: "externaldrive"
        }
    }
}

/// Cache global — vive fora dos projetos, no home do usuário.
struct GlobalCache: Identifiable, Sendable {
    let id: String
    let name: String
    /// Caminho relativo ao home do usuário.
    let relativePath: String
    let detail: String
    let category: CacheCategory
    /// Quando true, o conteúdo é removido mas o diretório em si fica — algumas
    /// ferramentas quebram se a raiz do cache desaparecer.
    let clearContentsOnly: Bool
    /// Entra pré-marcado na limpeza. Falso para o que custa caro recriar
    /// (downloads grandes de SDK) ou para o que pode guardar estado útil.
    let safeByDefault: Bool

    init(_ id: String, _ name: String, _ relativePath: String, _ category: CacheCategory,
         detail: String, clearContentsOnly: Bool = true, safeByDefault: Bool = true) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.category = category    
        self.detail = detail
        self.clearContentsOnly = clearContentsOnly
        self.safeByDefault = safeByDefault
    }

    var url: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: relativePath, directoryHint: .isDirectory)
    }

    static let catalog: [GlobalCache] = [
        // MARK: Gerenciadores de pacote
        .init("npm-cache", "npm", ".npm/_cacache", .packageManager, detail: "Cache de pacotes do npm"),
        .init("yarn-cache", "Yarn", "Library/Caches/Yarn", .packageManager, detail: "Cache do Yarn Classic"),
        .init("yarn-berry", "Yarn Berry", ".yarn/berry/cache", .packageManager, detail: "Cache global do Yarn 2+"),
        .init("pnpm-store", "pnpm store", "Library/pnpm/store", .packageManager, detail: "Store de conteúdo do pnpm"),
        .init("bun-cache", "Bun", ".bun/install/cache", .packageManager, detail: "Cache de instalação do Bun"),
        .init("deno-cache", "Deno", "Library/Caches/deno", .packageManager, detail: "Módulos e deps do Deno"),
        .init("cargo-registry", "Cargo registry", ".cargo/registry", .packageManager, detail: "Crates baixados"),
        .init("go-modcache", "Go module cache", "go/pkg/mod/cache", .packageManager, detail: "Downloads de módulos Go"),
        .init("gradle-caches", "Gradle", ".gradle/caches", .packageManager, detail: "Dependências e build cache"),
        .init("maven-repo", "Maven (~/.m2)", ".m2/repository", .packageManager, detail: "Repositório local do Maven"),
        .init("pip-cache", "pip", "Library/Caches/pip", .packageManager, detail: "Wheels e downloads do pip"),
        .init("uv-cache", "uv", ".cache/uv", .packageManager, detail: "Cache do uv"),
        .init("poetry-cache", "Poetry", "Library/Caches/pypoetry", .packageManager, detail: "Cache do Poetry"),
        .init("conda-pkgs", "conda", ".conda/pkgs", .packageManager, detail: "Pacotes conda baixados"),
        .init("pods-cache", "CocoaPods", "Library/Caches/CocoaPods", .packageManager, detail: "Specs e pods em cache"),
        .init("carthage-cache", "Carthage", "Library/Caches/org.carthage.CarthageKit", .packageManager,
              detail: "Builds em cache do Carthage"),
        .init("swiftpm-cache", "SwiftPM", "Library/Caches/org.swift.swiftpm", .packageManager,
              detail: "Cache de dependências do SwiftPM"),
        .init("composer-cache", "Composer", ".composer/cache", .packageManager, detail: "Cache do Composer"),
        .init("nuget-cache", "NuGet", ".nuget/packages", .packageManager, detail: "Pacotes NuGet baixados"),
        .init("pub-cache", "Dart pub", ".pub-cache", .packageManager, detail: "Pacotes Dart/Flutter baixados"),
        .init("gem-cache", "RubyGems", ".gem", .packageManager, detail: "Gems em cache"),
        .init("bundler-cache", "Bundler", "Library/Caches/bundler", .packageManager, detail: "Cache do Bundler"),
        .init("homebrew", "Homebrew", "Library/Caches/Homebrew", .packageManager,
              detail: "Downloads e bottles — `brew cleanup` faz o mesmo"),
        .init("nix-cache", "Nix", ".cache/nix", .packageManager, detail: "Cache de avaliação do Nix"),

        // MARK: Ferramentas de build
        .init("xcode-derived", "Xcode DerivedData", "Library/Developer/Xcode/DerivedData", .buildTooling,
              detail: "Índices e builds intermediários do Xcode"),
        .init("xcode-archives", "Xcode Archives", "Library/Developer/Xcode/Archives", .buildTooling,
              detail: "Arquivos .xcarchive de builds antigos", safeByDefault: false),
        .init("xcode-devicesupport", "iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport", .buildTooling,
              detail: "Símbolos de dispositivos já conectados — rebaixados ao reconectar"),
        .init("simulators-caches", "Caches do CoreSimulator", "Library/Developer/CoreSimulator/Caches", .buildTooling,
              detail: "Caches de runtime dos simuladores"),
        .init("xcode-caches", "Cache do Xcode", "Library/Caches/com.apple.dt.Xcode", .buildTooling,
              detail: "Cache geral do Xcode"),
        .init("go-build", "Go build cache", "Library/Caches/go-build", .buildTooling, detail: "Cache de compilação do Go"),
        .init("ccache", "ccache", ".ccache", .buildTooling, detail: "Cache do compilador C/C++"),
        .init("sccache", "sccache", "Library/Caches/Mozilla.sccache", .buildTooling, detail: "Cache de compilação Rust/C++"),
        .init("bazel", "Bazel", ".cache/bazel", .buildTooling, detail: "Cache de build do Bazel"),
        .init("node-gyp", "node-gyp", "Library/Caches/node-gyp", .buildTooling, detail: "Headers do Node para módulos nativos"),
        .init("electron", "Electron", "Library/Caches/electron", .buildTooling, detail: "Binários do Electron baixados"),
        .init("electron-builder", "electron-builder", "Library/Caches/electron-builder", .buildTooling,
              detail: "Ferramentas de empacotamento baixadas"),
        .init("puppeteer", "Puppeteer / Chromium", ".cache/puppeteer", .buildTooling, detail: "Builds de Chromium baixados"),
        .init("playwright", "Playwright", "Library/Caches/ms-playwright", .buildTooling, detail: "Navegadores do Playwright"),
        .init("android-build-cache", "Android build cache", ".android/build-cache", .buildTooling,
              detail: "Cache de build do Android"),
        .init("android-avd", "Emuladores Android (AVD)", ".android/avd", .buildTooling,
              detail: "Imagens de disco dos emuladores", safeByDefault: false),
        .init("flutter-cache", "Flutter SDK cache", ".flutter/bin/cache", .buildTooling,
              detail: "Artefatos do SDK Flutter", safeByDefault: false),
        .init("nvm-cache", "nvm", ".nvm/.cache", .buildTooling, detail: "Downloads de versões do Node"),
        .init("terraform-plugins", "Terraform plugins", ".terraform.d/plugin-cache", .buildTooling,
              detail: "Cache de providers do Terraform"),
        .init("docker-cache", "Docker Desktop", "Library/Caches/com.docker.docker", .buildTooling,
              detail: "Cache do Docker Desktop (não inclui imagens)"),

        // MARK: Editores e IDEs
        .init("jetbrains-caches", "JetBrains", "Library/Caches/JetBrains", .editor,
              detail: "Índices de IntelliJ, WebStorm, PyCharm…"),
        .init("vscode-cache", "VS Code", "Library/Application Support/Code/Cache", .editor, detail: "Cache do VS Code"),
        .init("vscode-cacheddata", "VS Code (código compilado)", "Library/Application Support/Code/CachedData", .editor,
              detail: "Bytecode em cache do VS Code"),
        .init("cursor-cache", "Cursor", "Library/Application Support/Cursor/Cache", .editor, detail: "Cache do Cursor"),
        .init("zed-cache", "Zed", "Library/Caches/dev.zed.Zed", .editor, detail: "Cache do Zed"),
        .init("sourcetree", "SourceTree", "Library/Caches/com.torusknot.SourceTreeNotMAS", .editor,
              detail: "Cache do SourceTree"),

        // MARK: Logs
        .init("dev-logs", "Logs de desenvolvimento", "Library/Logs", .logs,
              detail: "Logs de apps e ferramentas", safeByDefault: false),
        .init("diagnostic-reports", "Relatórios de falha", "Library/Logs/DiagnosticReports", .logs,
              detail: "Crash reports antigos", safeByDefault: false),
        .init("coresimulator-logs", "Logs do CoreSimulator", "Library/Logs/CoreSimulator", .logs,
              detail: "Logs dos simuladores iOS"),
    ]

    /// Raízes onde procurar caches que não estão no catálogo curado.
    static let discoveryRoots = ["Library/Caches", ".cache"]

    /// Prefixos de caminho já cobertos pelo catálogo — evita listar duas vezes.
    static var curatedPaths: Set<String> {
        Set(catalog.map { $0.url.standardizedFileURL.path })
    }
}
