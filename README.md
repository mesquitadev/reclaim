<div align="center">

<img src="docs/icon.png" width="128" alt="Reclaim">

# Reclaim

**Get your disk space back.** A native macOS app that finds and removes build
artifacts, dependency folders and tool caches across a dozen languages.

[Português](#português) · [Install](#install) · [Safety](#safety)

</div>

---

Reclaim scans the folders where you keep code, groups what it finds by project,
and shows you the size of each thing before you touch it. It also measures the
global caches your tools scatter around `~/Library/Caches` and `~/.cache` —
usually several gigabytes that nothing tracks.

Nothing is pre-selected, nothing is removed without a confirmation, and the
default is the Trash rather than deletion.

## Install

```sh
brew install --cask mesquitadev/tap/reclaim
xattr -dr com.apple.quarantine /Applications/Reclaim.app
```

The second line is needed because the app is signed ad-hoc rather than notarized
by Apple — notarization requires a paid Apple Developer account. Without it macOS
refuses the first launch. Right-clicking the app in Finder → Open → Open does the
same thing, once.

Or build from source:

```sh
git clone https://github.com/mesquitadev/reclaim.git
cd reclaim
Scripts/bundle.sh          # builds dist/Reclaim.app (universal arm64 + x86_64)
open dist/Reclaim.app
```

In Xcode: `open Package.swift`, scheme **Reclaim**, destination **My Mac**.

Terminal mode, listing only — it never removes anything:

```sh
swift run Reclaim --scan ~/Projects
```

## What it finds

**Inside projects** (`Sources/Reclaim/Models/Rule.swift`) — `node_modules`,
`.next`, `.turbo`, Cargo and Maven `target`, Gradle `build`, `Pods`, SwiftPM
`.build`, `__pycache__`, `.venv`, `.tox`, `.dart_tool`, Composer `vendor`,
`CMakeFiles`, `.terraform` and others.

**Global caches** (`Models/GlobalCache.swift`) — 50+ catalogued entries in four
categories: package managers (npm, Yarn Berry, pnpm, bun, Cargo, Go, Gradle,
`~/.m2`, pip, uv, Poetry, conda, CocoaPods, NuGet, pub, Homebrew…), build tooling
(DerivedData, DeviceSupport, simulators, Playwright, Puppeteer, Electron,
node-gyp, Bazel, ccache, Android, nvm…), editors (JetBrains, VS Code, Cursor,
Zed) and logs.

**Everything else** — with *Discover other app caches* on, anything in
`~/Library/Caches` and `~/.cache` outside the catalogue shows up too, unselected
and tagged *check*.

## The tree

Findings are grouped along the real folder structure, with the total aggregated
at every level:

```
Projects                                     5.8 GB
  MaisTech                                  4.79 GB
    castlight                               3.56 GB
      target · apps/desktop/src-tauri/      3.56 GB
    smartobra360                           378.7 MB
      mdeng-sm360-web                      188.2 MB
```

Path folders are dimmed; the project — where the `.git` or the manifest lives —
is highlighted, and that is where recursion stops.

| Key | Action |
|---|---|
| ↑ ↓ | walk headers and items in screen order |
| → ← | expand / collapse; on an item, ← goes up to its parent |
| Space | select or deselect the row (on a node, its whole subtree) |
| Return | reveal in Finder |
| ⌘R | scan · ⌘↩ clean |

## Safety

- **Nothing arrives selected.** A list that comes pre-checked turns a distracted
  click into gigabytes of loss. Selecting is deliberate; the Selection menu has
  the shortcuts (only what a command rebuilds, untouched for 30/90 days).
- **Always confirms**, in both modes — the Trash also moves tens of gigabytes at
  once. The dialog names the items that no command restores.
- **One cleanup at a time**, behind a modal sheet showing the current item, how
  many of how many, and how much space came back. You can stop it: the item in
  flight finishes and the rest stays selected.
- **Sentinels.** `dist/`, `build/`, `vendor/`, `target/` only count as junk when
  the matching project file sits next to them (`package.json`, `Cargo.toml`,
  `pom.xml`…). A `docs/dist` full of real content is never touched.
- **Guarded paths** (`Core/PathGuard.swift`): the system root, `/Library`, your
  home itself, `~/Documents`, `~/.ssh`, iCloud Drive, Photos libraries. Opaque
  bundles (`.app`, `.xcodeproj`, `.framework`) are never walked into.
- **Nothing nested.** No finding lives inside another, so removing a parent never
  orphans children in the list nor counts the same space twice.
- Symlinks are never followed.

## Permissions

Reclaim is not sandboxed. To scan `~/Documents`, `~/Desktop` or
`~/Library/Developer`, grant **Full Disk Access** in System Settings › Privacy &
Security. Without it those folders are silently skipped.

## Language

English by default, with Portuguese (Brazil) in Settings › General. The
translation lives in `Sources/Reclaim/Localization/Translations.swift`: keys are
the English text, so a missing entry falls back to English rather than showing a
raw identifier. Pull requests with other languages are welcome.

---

<a name="português"></a>

## Português

**Recupere seu espaço em disco.** App nativo de macOS que encontra e remove
resíduos de build, pastas de dependência e caches de ferramentas de uma dúzia de
linguagens.

O Reclaim varre as pastas onde você guarda código, agrupa o que encontra por
projeto e mostra o tamanho de cada coisa antes de você tocar nela. Ele também
mede os caches globais que suas ferramentas espalham por `~/Library/Caches` e
`~/.cache` — normalmente vários gigabytes que nada acompanha.

Nada vem pré-selecionado, nada é removido sem confirmação, e o padrão é a
Lixeira em vez de apagar de vez.

```sh
brew install --cask mesquitadev/tap/reclaim
xattr -dr com.apple.quarantine /Applications/Reclaim.app
```

A segunda linha é necessária porque o app é assinado ad-hoc, não notarizado pela
Apple — notarizar exige conta paga de desenvolvedor. Sem ela o macOS recusa a
primeira abertura.

O app abre em inglês; para trocar, Ajustes › Geral › Idioma › Português (Brasil).

### Segurança

- **Nada vem marcado.** Marcar é decisão explícita.
- **Confirmação sempre**, nos dois modos, com os itens que nenhum comando recria
  nomeados no diálogo.
- **Uma limpeza por vez**, atrás de uma folha modal com progresso e parada.
- **Sentinelas.** `dist/`, `build/`, `vendor/` e `target/` só contam como lixo
  quando o arquivo de projeto correspondente está ao lado.
- **Caminhos protegidos** e bundles opacos nunca são percorridos; symlinks nunca
  são seguidos.

Para varrer `~/Documents`, `~/Desktop` ou `~/Library/Developer`, conceda
**Acesso Total ao Disco** em Ajustes do Sistema › Privacidade e Segurança.

## License

MIT
