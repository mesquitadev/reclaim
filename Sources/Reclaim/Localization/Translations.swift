import Foundation

/// Português do Brasil. A chave é o texto em inglês exibido pelo app, então uma
/// entrada que falte aqui aparece em inglês — nunca como identificador cru.
extension L {
    static let ptBR: [String: String] = [
        // MARK: Barra lateral
        "Summary": "Resumo",
        "Found": "Encontrado",
        "Selected": "Marcado",
        "Free on disk": "Livre no disco",
        "Ecosystems": "Ecossistemas",
        "Everything": "Tudo",
        "Global caches": "Caches globais",
        "Scanned folders": "Pastas escaneadas",
        "Remove": "Remover",
        "Add folder…": "Adicionar pasta…",
        "Add": "Adicionar",
        "Choose the folders where your projects live": "Escolha as pastas onde seus projetos ficam",

        // MARK: Barra de ferramentas
        "Scan": "Escanear",
        "Stop": "Parar",
        "View": "Exibição",
        "By project": "Por projeto",
        "Flat list": "Lista",
        "Group by project, or list everything by size": "Agrupar por projeto ou listar tudo por tamanho",
        "Filter by project or path": "Filtrar por projeto ou caminho",
        "Selection": "Seleção",
        "Select all visible": "Marcar tudo que está visível",
        "Select only what a command rebuilds": "Marcar só o reconstruível",
        "Select untouched for 30 days": "Marcar sem uso há 30 dias",
        "Select untouched for 90 days": "Marcar sem uso há 90 dias",
        "Deselect all": "Desmarcar tudo",
        "Expand all": "Expandir tudo",
        "Collapse all": "Recolher tudo",

        // MARK: Lista
        "Select all %@ items": "Marcar todos os %@ itens",
        "%@ of %@ selected": "%@ de %@ marcados",
        "Select": "Marcar",
        "Select all": "Marcar tudo",
        "Deselect all in group": "Desmarcar tudo do grupo",
        "Reveal in Finder": "Revelar no Finder",
        "Copy path": "Copiar caminho",
        "Expand": "Expandir",
        "Collapse": "Recolher",
        "check": "verifique",
        "in %@": "em %@",
        "%@ files · %@": "%@ arquivos · %@",
        "%@ folders": "%@ pastas",
        "Scanning…": "Escaneando…",
        "Scanning": "Escaneando",
        "Nothing scanned yet": "Nada escaneado ainda",
        "Add at least one project folder in the sidebar.": "Adicione ao menos uma pasta de projetos na barra lateral.",
        "Scan the configured folder to see what can be freed.": "Escaneie a pasta configurada para ver o que pode ser liberado.",
        "Scan the %@ configured folders to see what can be freed.": "Escaneie as %@ pastas configuradas para ver o que pode ser liberado.",
        "Scan now": "Escanear agora",

        // MARK: Barra de ação
        "Nothing selected": "Nada marcado",
        "%@ across %@ items": "%@ em %@ itens",
        "Select what you want removed — or use Selection ▸ Select only what a command rebuilds":
            "Marque o que quer remover — ou use Seleção ▸ Marcar só o reconstruível",
        "%@ selected item is not restored by a command": "%@ item marcado não é recriado por um comando",
        "%@ selected items are not restored by a command": "%@ itens marcados não são recriados por um comando",
        "Everything selected is rebuilt automatically by your tools":
            "Tudo marcado é reconstruído automaticamente pelas ferramentas",
        "Clean %@": "Limpar %@",
        "Move to Trash": "Mover para a Lixeira",
        "Delete permanently": "Apagar definitivamente",
        "Delete": "Apagar",
        "Cancel": "Cancelar",

        // MARK: Confirmação
        "Delete %@ items (%@) permanently?": "Apagar definitivamente %@ itens (%@)?",
        "Move %@ items (%@) to the Trash?": "Mover %@ itens (%@) para a Lixeira?",
        "%@ of the selected items are not restored by a command: %@.":
            "%@ dos itens marcados não são recriados por um comando: %@.",
        "This skips the Trash and cannot be undone.": "Isso não passa pela Lixeira e não pode ser desfeito.",
        "The items go to the Trash; the space is only freed when you empty it.":
            "Os itens vão para a Lixeira; o espaço só é liberado ao esvaziá-la.",

        // MARK: Limpeza e resultado
        "Moving to Trash": "Movendo para a Lixeira",
        "Deleting": "Apagando",
        "%@ of %@ · %@ so far": "%@ de %@ · %@ até agora",
        "Large trees take a few seconds each.": "Remover árvores grandes leva alguns segundos por item.",
        "%@ reclaimed": "%@ liberados",
        "You stopped the cleanup; what already went is gone, and the rest stays selected.":
            "Você parou a limpeza; o que já saiu não volta, e o resto segue marcado.",
        "%@ items could not be removed — likely in use or missing permission.":
            "%@ itens não puderam ser removidos — provavelmente em uso ou sem permissão.",
        "The items are in the Trash; empty it to actually free the space.":
            "Os itens estão na Lixeira; esvazie-a para liberar o espaço de fato.",
        "Open Trash": "Abrir Lixeira",
        "Done": "Pronto",

        // MARK: Ajustes
        "General": "Geral",
        "Rules": "Regras",
        "Language": "Idioma",
        "Include global tool caches": "Incluir caches globais de ferramentas",
        "npm, Cargo, Gradle, DerivedData, Homebrew, Playwright, JetBrains and friends — all rebuilt on demand.":
            "npm, Cargo, Gradle, DerivedData, Homebrew, Playwright, JetBrains e afins — todos reconstruídos sob demanda.",
        "Discover other app caches": "Descobrir caches de outros apps",
        "Scans everything in ~/Library/Caches and ~/.cache, including what is not catalogued. Those arrive unselected, tagged *check*.":
            "Varre tudo em ~/Library/Caches e ~/.cache, inclusive o que não está no catálogo. Esses vêm desmarcados, com o selo *verifique*.",
        "Ignore items smaller than": "Ignorar itens menores que",
        "Nothing (show everything)": "Nada (mostrar tudo)",
        "Filters out the noise of thousands of tiny `__pycache__` and `.DS_Store`.":
            "Filtra o ruído de milhares de `__pycache__` e `.DS_Store` minúsculos.",
        "When cleaning": "Ao limpar",
        "System": "Sistema",

        // MARK: Ecossistemas e categorias
        "Node / JS": "Node / JS",
        "Swift / Xcode": "Swift / Xcode",
        "Python": "Python",
        "Rust": "Rust",
        "Go": "Go",
        "Java / Kotlin": "Java / Kotlin",
        ".NET": ".NET",
        "PHP": "PHP",
        "Ruby": "Ruby",
        "Flutter / Dart": "Flutter / Dart",
        "C / C++": "C / C++",
        "Misc": "Diversos",
        "Package managers": "Gerenciadores de pacote",
        "Build tooling": "Ferramentas de build",
        "Editors and IDEs": "Editores e IDEs",
        "Logs and reports": "Logs e relatórios",
        "Other app caches": "Outros caches de apps",
        "Tool caches": "Caches de ferramentas",

        // MARK: Nomes de cache que não são nomes próprios
        "Xcode cache": "Cache do Xcode",
        "CoreSimulator caches": "Caches do CoreSimulator",
        "Android emulators (AVD)": "Emuladores Android (AVD)",
        "Development logs": "Logs de desenvolvimento",
        "CoreSimulator logs": "Logs do CoreSimulator",
        "Crash reports": "Relatórios de falha",
        "Maven local repository": "Repositório local do Maven",
    ]
}
