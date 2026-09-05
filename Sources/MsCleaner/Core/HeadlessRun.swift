import Foundation

/// Modo terminal: `MsCleaner --scan <pasta>…` lista o que seria removido, sem tocar
/// em nada. Existe para conferir o comportamento do scanner sem abrir a janela.
enum HeadlessRun {
    static func runIfRequested() {
        var args = Array(CommandLine.arguments.dropFirst())
        guard let flag = args.first, flag == "--scan" else { return }
        args.removeFirst()

        let roots = args.isEmpty
            ? Defaults.roots
            : args.map { URL(filePath: $0, directoryHint: .isDirectory) }
        guard !roots.isEmpty else {
            FileHandle.standardError.write(Data("uso: MsCleaner --scan <pasta>…\n".utf8))
            exit(2)
        }

        let scanner = Scanner()
        let collected = Collector()

        let done = DispatchSemaphore(value: 0)
        Task {
            await scanner.scan(roots: roots, onProgress: { _ in }, onBatch: { collected.add($0) })
            await CacheScanner().scan(onBatch: { collected.add($0) })
            done.signal()
        }
        done.wait()

        let findings = collected.all.sorted { $0.size > $1.size }
        for finding in findings {
            let flag = finding.regenerable ? " " : "!"
            print("\(flag) \(finding.size.formattedBytes.padded(to: 10))  \(finding.url.path(percentEncoded: false))")
        }
        print("\n\(findings.count) itens · \(findings.totalSize.formattedBytes)")
        print("(nada foi removido; ! = não recriado por um comando)")
        exit(0)
    }

    /// Acumulador thread-safe para os lotes que o scanner emite.
    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [Finding] = []

        func add(_ batch: [Finding]) {
            lock.withLock { items.append(contentsOf: batch) }
        }

        var all: [Finding] { lock.withLock { items } }
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
