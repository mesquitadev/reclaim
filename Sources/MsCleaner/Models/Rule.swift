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
        case .misc: "Diversos"
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
        .init(id: "node_modules", .node, .directory("node_modules"), detail: "Dependências — `npm install` recria"),
        .init(id: "next", .node, .directory(".next"), detail: "Cache de build do Next.js"),
        .init(id: "nuxt", .node, .directory(".nuxt"), detail: "Cache de build do Nuxt"),
        .init(id: "svelte-kit", .node, .directory(".svelte-kit"), detail: "Cache de build do SvelteKit"),
        .init(id: "turbo", .node, .directory(".turbo"), detail: "Cache local do Turborepo"),
        .init(id: "parcel-cache", .node, .directory(".parcel-cache"), detail: "Cache do Parcel"),
        .init(id: "vite-deps", .node, .directory(".vite"), detail: "Pré-bundle de deps do Vite"),
        .init(id: "angular-cache", .node, .directory(".angular"), detail: "Cache do Angular CLI"),
        .init(id: "expo", .node, .directory(".expo"), detail: "Cache local do Expo"),
        .init(id: "node-dist", .node, .directory("dist", requiring: ["package.json"]), detail: "Saída de build (ao lado de package.json)"),
        .init(id: "node-build", .node, .directory("build", requiring: ["package.json"]), detail: "Saída de build (ao lado de package.json)"),
        .init(id: "node-coverage", .node, .directory("coverage", requiring: ["package.json"]), detail: "Relatório de cobertura de testes"),
        .init(id: "nyc", .node, .directory(".nyc_output"), detail: "Dados brutos de cobertura (nyc)"),

        // Swift / Xcode
        .init(id: "swift-build", .swift, .directory(".build", requiring: ["Package.swift"]), detail: "Artefatos do SwiftPM"),
        .init(id: "swiftpm", .swift, .directory(".swiftpm"), detail: "Estado local do SwiftPM"),
        .init(id: "pods", .swift, .directory("Pods", requiring: ["Podfile"]), detail: "CocoaPods — `pod install` recria"),
        .init(id: "carthage-build", .swift, .directory("Build", requiring: ["Cartfile"]), detail: "Artefatos do Carthage"),
        .init(id: "xcuserdata", .swift, .directory("xcuserdata"), detail: "Preferências locais de Xcode", regenerable: false),

        // Python
        .init(id: "pycache", .python, .directory("__pycache__"), detail: "Bytecode compilado"),
        .init(id: "venv", .python, .directory(".venv"), detail: "Virtualenv — recriável, mas leva tempo", regenerable: false),
        .init(id: "pytest", .python, .directory(".pytest_cache"), detail: "Cache do pytest"),
        .init(id: "mypy", .python, .directory(".mypy_cache"), detail: "Cache do mypy"),
        .init(id: "ruff", .python, .directory(".ruff_cache"), detail: "Cache do Ruff"),
        .init(id: "tox", .python, .directory(".tox"), detail: "Ambientes do tox"),
        .init(id: "eggs", .python, .directory(".eggs"), detail: "Eggs baixados pelo setuptools"),
        .init(id: "py-build", .python, .directory("build", requiring: ["setup.py", "pyproject.toml"]), detail: "Saída de build"),

        // Rust
        .init(id: "cargo-target", .rust, .directory("target", requiring: ["Cargo.toml"]), detail: "Artefatos do Cargo — costuma ser o maior vilão"),

        // Go
        .init(id: "go-vendor", .go, .directory("vendor", requiring: ["go.mod"]), detail: "Deps vendorizadas — `go mod vendor` recria", regenerable: false),

        // Java / Kotlin
        .init(id: "gradle-local", .java, .directory(".gradle"), detail: "Estado local do Gradle"),
        .init(id: "gradle-build", .java, .directory("build", requiring: ["build.gradle", "build.gradle.kts"]), detail: "Saída de build do Gradle"),
        .init(id: "maven-target", .java, .directory("target", requiring: ["pom.xml"]), detail: "Saída de build do Maven"),
        .init(id: "idea", .java, .directory(".idea"), detail: "Config local do IntelliJ", regenerable: false),
        .init(id: "kotlin", .java, .directory(".kotlin"), detail: "Estado do compilador Kotlin"),

        // .NET
        .init(id: "dotnet-bin", .dotnet, .directory("bin", requiring: ["Directory.Build.props"]), detail: "Binários compilados"),
        .init(id: "dotnet-obj", .dotnet, .directory("obj", requiring: ["Directory.Build.props"]), detail: "Objetos intermediários"),
        .init(id: "vs", .dotnet, .directory(".vs"), detail: "Estado do Visual Studio", regenerable: false),

        // PHP
        .init(id: "composer-vendor", .php, .directory("vendor", requiring: ["composer.json"]), detail: "Deps — `composer install` recria"),

        // Ruby
        .init(id: "bundle", .ruby, .directory(".bundle"), detail: "Config local do Bundler", regenerable: false),
        .init(id: "ruby-vendor", .ruby, .directory("vendor", requiring: ["Gemfile"]), detail: "Gems vendorizadas"),

        // Flutter / Dart
        .init(id: "dart-tool", .flutter, .directory(".dart_tool"), detail: "Cache de ferramentas do Dart"),
        .init(id: "flutter-plugins", .flutter, .file(".flutter-plugins-dependencies"), detail: "Manifesto de plugins gerado"),

        // C / C++
        .init(id: "cmake-files", .cpp, .directory("CMakeFiles"), detail: "Intermediários do CMake"),
        .init(id: "cmake-build", .cpp, .directory("build", requiring: ["CMakeLists.txt"]), detail: "Diretório de build do CMake"),

        // Diversos
        .init(id: "ds-store", .misc, .file(".DS_Store"), detail: "Metadado do Finder"),
        .init(id: "terraform", .misc, .directory(".terraform"), detail: "Providers e módulos do Terraform"),
    ]
}
