# MsCleaner

App nativo de macOS (SwiftUI, Swift 6) que encontra e remove resíduos de build e
dependências de projetos de várias linguagens.

## Rodando

```bash
Scripts/bundle.sh          # gera dist/MsCleaner.app (universal arm64 + x86_64)
open dist/MsCleaner.app
```

No Xcode: `open Package.swift`, escolha o scheme **MsCleaner** e o destino **My Mac**.

Rodando pelo Xcode ou por `swift run`, o binário do SwiftPM não tem bundle nem
`Info.plist` — sem isso o LaunchServices trataria o processo como acessório e a
janela nunca viria para a frente. O `AppDelegate` promove a política de ativação
no lançamento, então os dois modos funcionam. O que só o `.app` empacotado tem é
a identidade estável de bundle, e é dela que dependem as permissões de disco: o
macOS lembra o acesso concedido a `dev.mesquita.MsCleaner`, não a um executável
avulso em `.build/`. Para testar as pastas protegidas, use o `.app`.

Modo terminal, só listagem (não remove nada):

```bash
swift run MsCleaner --scan ~/Projects
```

## Navegação

A listagem é uma árvore que segue a estrutura de pastas, com o total agregado em
cada nível:

```
Dizevolv                                    21,36 GB
  k7cabines                                 20,95 GB
    target  src-tauri                       20,35 GB
    node_modules                            599,8 MB
MaisTech                                     6,84 GB
  smartobra360                               1,19 GB
    mdeng-sm360-mobile                      719,1 MB
      node_modules                          719,1 MB
```

As pastas do caminho ficam em cinza; o projeto — onde estão o `.git` ou o
manifesto — vem destacado, e é onde a recursão para. Cadeias de pasta sem
bifurcação viram uma linha só (`clientes/acme`) para a árvore não virar escada.
Os caches globais entram no fim, em nós por categoria.

| Tecla | Ação |
|---|---|
| ↑ ↓ | percorre cabeçalhos e itens na ordem da tela |
| → ← | expande / recolhe o grupo; sobre um item, ← sobe para o cabeçalho |
| Espaço | marca ou desmarca a linha (num cabeçalho, o grupo inteiro) |
| Return | revela no Finder |
| ⌘R | escanear · ⌘↩ limpar |

O checkbox no topo marca tudo que está visível (respeita busca e filtro), e cada
cabeçalho tem seu próprio checkbox tri-estado.

## O que ele encontra

**Dentro dos projetos** (`Sources/MsCleaner/Models/Rule.swift`) — `node_modules`,
`.next`, `.turbo`, `target` do Cargo/Maven, `build` do Gradle, `Pods`, `.build` do
SwiftPM, `__pycache__`, `.venv`, `.tox`, `.dart_tool`, `vendor` do Composer,
`CMakeFiles`, `.terraform` e outros.

**Caches globais** (`Models/GlobalCache.swift`) — 50+ entradas catalogadas em
quatro categorias: gerenciadores de pacote (npm, Yarn Berry, pnpm, bun, Cargo,
Go, Gradle, `~/.m2`, pip, uv, Poetry, conda, CocoaPods, NuGet, pub, Homebrew…),
ferramentas de build (DerivedData, DeviceSupport, simuladores, Playwright,
Puppeteer, Electron, node-gyp, Bazel, ccache, Android, nvm…), editores
(JetBrains, VS Code, Cursor, Zed) e logs.

**Todo o resto** — com "Descobrir caches de outros apps" ligado, tudo que houver em
`~/Library/Caches` e `~/.cache` fora do catálogo entra na lista, desmarcado e com
selo *verifique*. É o que fecha a conta: numa varredura real aqui, 6 GB estavam
justamente aí.

## Segurança

- **Lixeira por padrão.** Apagar de vez exige trocar o modo e confirmar num diálogo.
- **Sentinelas.** `dist/`, `build/`, `vendor/`, `target/` só contam como lixo quando
  há o arquivo de projeto correspondente ao lado (`package.json`, `Cargo.toml`,
  `pom.xml`…). Um `docs/dist` de conteúdo real não é tocado.
- **Caminhos protegidos** (`Core/PathGuard.swift`): raiz do sistema, `/Library`, o
  home em si, `~/Documents`, `~/.ssh`, iCloud Drive, bibliotecas de Fotos. Bundles
  opacos (`.app`, `.xcodeproj`, `.framework`) não são percorridos.
- **Nada vem marcado.** O scan termina com a lista inteira desmarcada: um clique
  distraído num app que já veio com 30 GB selecionados custa caro. Marcar é
  decisão explícita, e o menu Seleção dá os atalhos (só o reconstruível, sem uso
  há 30/90 dias).
- **Uma limpeza por vez.** Enquanto ela roda, uma folha modal mostra o andamento
  (item atual, quantos de quantos, espaço já liberado) e bloqueia escanear, marcar
  ou disparar outra remoção — duas em paralelo removeriam a mesma árvore duas
  vezes. Dá para parar: o item em curso termina e o resto continua marcado.
- **Confirmação sempre**, nos dois modos — a Lixeira também move dezenas de
  gigabytes de uma vez. O diálogo diz quantos itens, quanto espaço, e nomeia os
  que não são recriados por um comando.
- **Selo *verifique*.** `.venv`, `.idea`, `xcuserdata`, caches de apps
  descobertos e afins são marcados como não reconstruíveis por comando.
- **Nada aninhado.** Nenhum achado vive dentro de outro: a poda do scanner para na
  primeira pasta que casa uma regra, e uma passada final descarta o que escapar —
  remover o pai nunca deixa filhos órfãos na lista, nem conta o mesmo espaço duas
  vezes. Pastas renomeadas pelo macOS ao restaurar da Lixeira
  (`node_modules 21-30-17-375`) são reconhecidas como o original.
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
