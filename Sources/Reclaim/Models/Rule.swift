import Foundation

/// Como a regra identifica um alvo dentro de um projeto.
enum Matcher: Sendable {
    /// Diretório com esse nome, e — quando `requiring` não está vazio — só se um dos
    /// arquivos-sentinela existir ao lado. Evita apagar um `build/` ou `dist/` que na
    /// verdade é código-fonte.
    case directory(String, requiring: [String])
    /// Arquivo com esse nome exato (ex: `.DS_Store`).
    case file(String)

    /// Açúcar para o caso comum: nome de diretório que dispensa sentinela.
    static func directory(_ name: String) -> Matcher { .directory(name, requiring: []) }
}

enum Ecosystem: String, CaseIterable, Identifiable, Sendable {
    case node, swift, python, rust, go, java, dotnet, php, ruby, flutter, cpp, misc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .node: "Node / JS"
        case .swift: "Swift / Xcode"
        case .python: "Python"
        case .rust: "Rust"
        case .go: "Go"
        case .java: "Java / Kotlin"
        case .dotnet: ".NET"
        case .php: "PHP"
        case .ruby: "Ruby"
        case .flutter: "Flutter / Dart"
        case .cpp: "C / C++"
        case .misc: "Misc"
        }
    }

    var symbol: String {
        switch self {
        case .node: "hexagon"
        case .swift: "swift"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .rust: "gearshape.2"
        case .go: "bolt"
        case .java: "cup.and.saucer"
        case .dotnet: "square.grid.2x2"
        case .php: "curlybraces"
        case .ruby: "diamond"
        case .flutter: "bird"
        case .cpp: "c.square"
        case .misc: "shippingbox"
        }
    }
}

/// Uma regra de limpeza aplicada dentro das pastas de projeto escaneadas.
struct Rule: Identifiable, Sendable {
    let id: String
    let ecosystem: Ecosystem
    let matcher: Matcher
    let detail: String
    /// Regeneráveis com um comando (`npm install`, `cargo build`...). Só essas vêm
    /// pré-marcadas; o resto exige escolha explícita do usuário.
    let regenerable: Bool

    init(id: String, _ ecosystem: Ecosystem, _ matcher: Matcher, detail: String, regenerable: Bool = true) {
        self.id = id
        self.ecosystem = ecosystem
        self.matcher = matcher
        self.detail = detail
        self.regenerable = regenerable
    }

    var name: String {
        switch matcher {
        case .directory(let n, _), .file(let n): n
        }
    }
}

extension Rule {
    /// Catálogo de resíduos de build/dependência por ecossistema.
    static let catalog: [Rule] = [
        // Node / JS
        .init(id: "node_modules", .node, .directory("node_modules"), detail: "Dependencies — `npm install` restores them"),
        .init(id: "next", .node, .directory(".next"), detail: "Next.js build cache"),
        .init(id: "nuxt", .node, .directory(".nuxt"), detail: "Nuxt build cache"),
        .init(id: "svelte-kit", .node, .directory(".svelte-kit"), detail: "SvelteKit build cache"),
        .init(id: "turbo", .node, .directory(".turbo"), detail: "Turborepo local cache"),
        .init(id: "parcel-cache", .node, .directory(".parcel-cache"), detail: "Parcel cache"),
        .init(id: "vite-deps", .node, .directory(".vite"), detail: "Vite dependency pre-bundle"),
        .init(id: "angular-cache", .node, .directory(".angular"), detail: "Angular CLI cache"),
        .init(id: "expo", .node, .directory(".expo"), detail: "Expo local cache"),
        .init(id: "node-dist", .node, .directory("dist", requiring: ["package.json"]), detail: "Build output (next to package.json)"),
        .init(id: "node-build", .node, .directory("build", requiring: ["package.json"]), detail: "Build output (next to package.json)"),
        .init(id: "node-coverage", .node, .directory("coverage", requiring: ["package.json"]), detail: "Test coverage report"),
        .init(id: "nyc", .node, .directory(".nyc_output"), detail: "Raw coverage data (nyc)"),

        // Swift / Xcode
        .init(id: "swift-build", .swift, .directory(".build", requiring: ["Package.swift"]), detail: "SwiftPM artifacts"),
        .init(id: "swiftpm", .swift, .directory(".swiftpm"), detail: "SwiftPM local state"),
        .init(id: "pods", .swift, .directory("Pods", requiring: ["Podfile"]), detail: "CocoaPods — `pod install` restores them"),
        .init(id: "carthage-build", .swift, .directory("Build", requiring: ["Cartfile"]), detail: "Carthage artifacts"),
        .init(id: "xcuserdata", .swift, .directory("xcuserdata"), detail: "Local Xcode preferences", regenerable: false),

        // Python
        .init(id: "pycache", .python, .directory("__pycache__"), detail: "Compiled bytecode"),
        .init(id: "venv", .python, .directory(".venv"), detail: "Virtualenv — rebuildable, but slow", regenerable: false),
        .init(id: "pytest", .python, .directory(".pytest_cache"), detail: "pytest cache"),
        .init(id: "mypy", .python, .directory(".mypy_cache"), detail: "mypy cache"),
        .init(id: "ruff", .python, .directory(".ruff_cache"), detail: "Ruff cache"),
        .init(id: "tox", .python, .directory(".tox"), detail: "tox environments"),
        .init(id: "eggs", .python, .directory(".eggs"), detail: "Eggs downloaded by setuptools"),
        .init(id: "py-build", .python, .directory("build", requiring: ["setup.py", "pyproject.toml"]), detail: "Build output"),

        // Rust
        .init(id: "cargo-target", .rust, .directory("target", requiring: ["Cargo.toml"]), detail: "Cargo artifacts — usually the biggest offender"),

        // Go
        .init(id: "go-vendor", .go, .directory("vendor", requiring: ["go.mod"]), detail: "Vendored deps — `go mod vendor` restores them", regenerable: false),

        // Java / Kotlin
        .init(id: "gradle-local", .java, .directory(".gradle"), detail: "Gradle local state"),
        .init(id: "gradle-build", .java, .directory("build", requiring: ["build.gradle", "build.gradle.kts"]), detail: "Gradle build output"),
        .init(id: "maven-target", .java, .directory("target", requiring: ["pom.xml"]), detail: "Maven build output"),
        .init(id: "idea", .java, .directory(".idea"), detail: "IntelliJ local config", regenerable: false),
        .init(id: "kotlin", .java, .directory(".kotlin"), detail: "Kotlin compiler state"),

        // .NET
        .init(id: "dotnet-bin", .dotnet, .directory("bin", requiring: ["Directory.Build.props"]), detail: "Compiled binaries"),
        .init(id: "dotnet-obj", .dotnet, .directory("obj", requiring: ["Directory.Build.props"]), detail: "Intermediate objects"),
        .init(id: "vs", .dotnet, .directory(".vs"), detail: "Visual Studio state", regenerable: false),

        // PHP
        .init(id: "composer-vendor", .php, .directory("vendor", requiring: ["composer.json"]), detail: "Deps — `composer install` restores them"),

        // Ruby
        .init(id: "bundle", .ruby, .directory(".bundle"), detail: "Bundler local config", regenerable: false),
        .init(id: "ruby-vendor", .ruby, .directory("vendor", requiring: ["Gemfile"]), detail: "Vendored gems"),

        // Flutter / Dart
        .init(id: "dart-tool", .flutter, .directory(".dart_tool"), detail: "Dart tooling cache"),
        .init(id: "flutter-plugins", .flutter, .file(".flutter-plugins-dependencies"), detail: "Generated plugin manifest"),

        // C / C++
        .init(id: "cmake-files", .cpp, .directory("CMakeFiles"), detail: "CMake intermediates"),
        .init(id: "cmake-build", .cpp, .directory("build", requiring: ["CMakeLists.txt"]), detail: "CMake build directory"),

        // Diversos
        .init(id: "ds-store", .misc, .file(".DS_Store"), detail: "Finder metadata"),
        .init(id: "terraform", .misc, .directory(".terraform"), detail: "Terraform providers and modules"),
    ]
}
