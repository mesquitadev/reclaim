# MsCleaner

App nativo de macOS (SwiftUI, Swift 6) que encontra e remove resíduos de build e
dependências de projetos de várias linguagens.

## Rodando

```bash
Scripts/bundle.sh          # gera dist/MsCleaner.app (universal arm64 + x86_64)
open dist/MsCleaner.app
```

Ou, no Xcode: `open Package.swift`.

Modo terminal, só listagem (não remove nada):

```bash
swift run MsCleaner --scan ~/Projects
```

## O que ele encontra

**Dentro dos projetos** (`Sources/MsCleaner/Models/Rule.swift`) — `node_modules`,
`.next`, `.turbo`, `target` do Cargo/Maven, `build` do Gradle, `Pods`, `.build` do
SwiftPM, `__pycache__`, `.venv`, `.tox`, `.dart_tool`, `vendor` do Composer,
`CMakeFiles`, `.terraform` e outros.

**Caches globais** (`Models/GlobalCache.swift`) — DerivedData, iOS DeviceSupport,
npm/yarn/pnpm/bun, Cargo registry, Go module cache, Gradle, `~/.m2`, pip, uv,
CocoaPods, NuGet, pub-cache, Puppeteer, ccache.

## Segurança

- **Lixeira por padrão.** Apagar de vez exige trocar o modo e confirmar num diálogo.
- **Sentinelas.** `dist/`, `build/`, `vendor/`, `target/` só contam como lixo quando
  há o arquivo de projeto correspondente ao lado (`package.json`, `Cargo.toml`,
  `pom.xml`…). Um `docs/dist` de conteúdo real não é tocado.
- **Caminhos protegidos** (`Core/PathGuard.swift`): raiz do sistema, `/Library`, o
  home em si, `~/Documents`, `~/.ssh`, iCloud Drive, bibliotecas de Fotos. Bundles
  opacos (`.app`, `.xcodeproj`, `.framework`) não são percorridos.
- **Pré-seleção conservadora.** Só vem marcado o que um comando reconstrói
  (`npm install`, `cargo build`). `.venv`, `.idea`, `xcuserdata` e afins aparecem
  com o selo *verifique* e desmarcados.
- Symlinks nunca são seguidos.

## Permissões

O app não é sandboxed. Para varrer `~/Documents`, `~/Desktop` ou
`~/Library/Developer`, conceda **Acesso Total ao Disco** em Ajustes do Sistema ›
Privacidade e Segurança. Sem isso, essas pastas são silenciosamente puladas.

## Estrutura

```
Sources/MsCleaner/
  Models/    Rule (catálogo por ecossistema), GlobalCache, Finding
  Core/      Scanner (varredura com poda), CacheScanner, DiskUsage,
             Cleaner (lixeira/apagar), PathGuard, AppModel, Defaults, HeadlessRun
  Views/     ContentView, SidebarView, FindingsView, ActionBar, ResultSheet, SettingsView
```
