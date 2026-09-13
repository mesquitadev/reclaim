import Foundation

/// Um arquivo comum encontrado na varredura de pastas.
///
/// Guardamos os três carimbos de tempo separados porque eles respondem a
/// perguntas diferentes: `modified` diz quando o conteúdo mudou, `accessed`
/// quando alguém de fato abriu — e é o segundo que identifica o que foi
/// esquecido, não o primeiro.
struct FileEntry: Identifiable, Sendable, Hashable {
    let url: URL
    let size: Int64
    let modified: Date
    let accessed: Date
    let isPackage: Bool

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var parent: String { url.deletingLastPathComponent().path(percentEncoded: false) }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Há quanto tempo ninguém abre o arquivo.
    var idleDays: Int {
        Calendar.current.dateComponents([.day], from: accessed, to: .now).day ?? 0
    }
}

/// Um conjunto de arquivos com conteúdo idêntico.
struct DuplicateGroup: Identifiable, Sendable {
    let digest: String
    let files: [FileEntry]

    var id: String { digest }
    var size: Int64 { files.first?.size ?? 0 }

    /// O que dá para recuperar: tudo menos uma cópia.
    var reclaimable: Int64 { size * Int64(max(0, files.count - 1)) }

    /// A cópia sugerida para manter: a mais antiga, que normalmente é a
    /// original — as outras costumam ser cópias feitas depois.
    var suggestedKeep: FileEntry? {
        files.min { $0.modified < $1.modified }
    }

    var duplicates: [FileEntry] {
        guard let keep = suggestedKeep else { return files }
        return files.filter { $0.url != keep.url }
    }
}
