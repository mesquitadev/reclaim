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
        case .packageManager: "Package managers"
        case .buildTooling: "Build tooling"
        case .editor: "Editors and IDEs"
        case .logs: "Logs and reports"
        case .discovered: "Other app caches"
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
        .init("npm-cache", "npm", ".npm/_cacache", .packageManager, detail: "npm package cache"),
        .init("yarn-cache", "Yarn", "Library/Caches/Yarn", .packageManager, detail: "Yarn Classic cache"),
        .init("yarn-berry", "Yarn Berry", ".yarn/berry/cache", .packageManager, detail: "Yarn 2+ global cache"),
        .init("pnpm-store", "pnpm store", "Library/pnpm/store", .packageManager, detail: "pnpm content store"),
        .init("bun-cache", "Bun", ".bun/install/cache", .packageManager, detail: "Bun install cache"),
        .init("deno-cache", "Deno", "Library/Caches/deno", .packageManager, detail: "Deno modules and deps"),
        .init("cargo-registry", "Cargo registry", ".cargo/registry", .packageManager, detail: "Downloaded crates"),
        .init("go-modcache", "Go module cache", "go/pkg/mod/cache", .packageManager, detail: "Go module downloads"),
        .init("gradle-caches", "Gradle", ".gradle/caches", .packageManager, detail: "Dependencies and build cache"),
        .init("maven-repo", "Maven (~/.m2)", ".m2/repository", .packageManager, detail: "Maven local repository"),
        .init("pip-cache", "pip", "Library/Caches/pip", .packageManager, detail: "pip wheels and downloads"),
        .init("uv-cache", "uv", ".cache/uv", .packageManager, detail: "uv cache"),
        .init("poetry-cache", "Poetry", "Library/Caches/pypoetry", .packageManager, detail: "Poetry cache"),
        .init("conda-pkgs", "conda", ".conda/pkgs", .packageManager, detail: "Downloaded conda packages"),
        .init("pods-cache", "CocoaPods", "Library/Caches/CocoaPods", .packageManager, detail: "Cached specs and pods"),
        .init("carthage-cache", "Carthage", "Library/Caches/org.carthage.CarthageKit", .packageManager,
              detail: "Cached Carthage builds"),
        .init("swiftpm-cache", "SwiftPM", "Library/Caches/org.swift.swiftpm", .packageManager,
              detail: "SwiftPM dependency cache"),
        .init("composer-cache", "Composer", ".composer/cache", .packageManager, detail: "Composer cache"),
        .init("nuget-cache", "NuGet", ".nuget/packages", .packageManager, detail: "Downloaded NuGet packages"),
        .init("pub-cache", "Dart pub", ".pub-cache", .packageManager, detail: "Downloaded Dart/Flutter packages"),
        .init("gem-cache", "RubyGems", ".gem", .packageManager, detail: "Cached gems"),
        .init("bundler-cache", "Bundler", "Library/Caches/bundler", .packageManager, detail: "Bundler cache"),
        .init("homebrew", "Homebrew", "Library/Caches/Homebrew", .packageManager,
              detail: "Downloads and bottles — `brew cleanup` does the same"),
        .init("nix-cache", "Nix", ".cache/nix", .packageManager, detail: "Nix evaluation cache"),

        // MARK: Ferramentas de build
        .init("xcode-derived", "Xcode DerivedData", "Library/Developer/Xcode/DerivedData", .buildTooling,
              detail: "Xcode indexes and intermediate builds"),
        .init("xcode-archives", "Xcode Archives", "Library/Developer/Xcode/Archives", .buildTooling,
              detail: "Old .xcarchive builds", safeByDefault: false),
        .init("xcode-devicesupport", "iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport", .buildTooling,
              detail: "Symbols from devices you connected — re-downloaded on reconnect"),
        .init("simulators-caches", "CoreSimulator caches", "Library/Developer/CoreSimulator/Caches", .buildTooling,
              detail: "Simulator runtime caches"),
        .init("xcode-caches", "Xcode cache", "Library/Caches/com.apple.dt.Xcode", .buildTooling,
              detail: "General Xcode cache"),
        .init("go-build", "Go build cache", "Library/Caches/go-build", .buildTooling, detail: "Go compilation cache"),
        .init("ccache", "ccache", ".ccache", .buildTooling, detail: "C/C++ compiler cache"),
        .init("sccache", "sccache", "Library/Caches/Mozilla.sccache", .buildTooling, detail: "Rust/C++ compilation cache"),
        .init("bazel", "Bazel", ".cache/bazel", .buildTooling, detail: "Bazel build cache"),
        .init("node-gyp", "node-gyp", "Library/Caches/node-gyp", .buildTooling, detail: "Node headers for native modules"),
        .init("electron", "Electron", "Library/Caches/electron", .buildTooling, detail: "Downloaded Electron binaries"),
        .init("electron-builder", "electron-builder", "Library/Caches/electron-builder", .buildTooling,
              detail: "Downloaded packaging tools"),
        .init("puppeteer", "Puppeteer / Chromium", ".cache/puppeteer", .buildTooling, detail: "Downloaded Chromium builds"),
        .init("playwright", "Playwright", "Library/Caches/ms-playwright", .buildTooling, detail: "Playwright browsers"),
        .init("android-build-cache", "Android build cache", ".android/build-cache", .buildTooling,
              detail: "Android build cache"),
        .init("android-avd", "Android emulators (AVD)", ".android/avd", .buildTooling,
              detail: "Emulator disk images", safeByDefault: false),
        .init("flutter-cache", "Flutter SDK cache", ".flutter/bin/cache", .buildTooling,
              detail: "Flutter SDK artifacts", safeByDefault: false),
        .init("nvm-cache", "nvm", ".nvm/.cache", .buildTooling, detail: "Downloaded Node versions"),
        .init("terraform-plugins", "Terraform plugins", ".terraform.d/plugin-cache", .buildTooling,
              detail: "Terraform provider cache"),
        .init("docker-cache", "Docker Desktop", "Library/Caches/com.docker.docker", .buildTooling,
              detail: "Docker Desktop cache (not images)"),

        // MARK: Editores e IDEs
        .init("jetbrains-caches", "JetBrains", "Library/Caches/JetBrains", .editor,
              detail: "IntelliJ, WebStorm, PyCharm indexes"),
        .init("vscode-cache", "VS Code", "Library/Application Support/Code/Cache", .editor, detail: "VS Code cache"),
        .init("vscode-cacheddata", "VS Code (código compilado)", "Library/Application Support/Code/CachedData", .editor,
              detail: "VS Code cached bytecode"),
        .init("cursor-cache", "Cursor", "Library/Application Support/Cursor/Cache", .editor, detail: "Cursor cache"),
        .init("zed-cache", "Zed", "Library/Caches/dev.zed.Zed", .editor, detail: "Zed cache"),
        .init("sourcetree", "SourceTree", "Library/Caches/com.torusknot.SourceTreeNotMAS", .editor,
              detail: "SourceTree cache"),

        // MARK: Logs
        .init("dev-logs", "Development logs", "Library/Logs", .logs,
              detail: "App and tooling logs", safeByDefault: false),
        .init("diagnostic-reports", "Crash reports", "Library/Logs/DiagnosticReports", .logs,
              detail: "Old crash reports", safeByDefault: false),
        .init("coresimulator-logs", "CoreSimulator logs", "Library/Logs/CoreSimulator", .logs,
              detail: "iOS simulator logs"),
    ]

    /// Raízes onde procurar caches que não estão no catálogo curado.
    static let discoveryRoots = ["Library/Caches", ".cache"]

    /// Prefixos de caminho já cobertos pelo catálogo — evita listar duas vezes.
    static var curatedPaths: Set<String> {
        Set(catalog.map { $0.url.standardizedFileURL.path })
    }
}
