import Foundation

/// Monta a árvore de exibição a partir dos achados: pasta escaneada no topo, os
/// diretórios do caminho no meio, o projeto onde os manifestos estão, e os
/// achados como folhas.
struct TreeBuilder {
    let roots: [URL]

    /// Nó em construção. Classe porque a montagem é feita descendo e mutando.
    private final class Node {
        let url: URL
        let name: String
        var children: [String: Node] = [:]
        var leaves: [Finding] = []
        var isProject = false
        var ecosystem: Ecosystem?

        init(url: URL, name: String) {
            self.url = url
            self.name = name
        }
    }

    func build(from findings: [Finding]) -> [TreeNode] {
        var rootNodes: [String: Node] = [:]

        for finding in findings {
            guard let project = finding.projectRoot else { continue }
            let projectPath = project.path(percentEncoded: false)

            // A pasta escaneada mais específica que contém este projeto.
            let scanRoot = roots
                .filter { projectPath.hasPrefix($0.path(percentEncoded: false)) }
                .max { $0.path.count < $1.path.count }
                ?? project.deletingLastPathComponent()

            let rootPath = scanRoot.path(percentEncoded: false)
            let node = rootNodes[rootPath] ?? Node(url: scanRoot, name: scanRoot.lastPathComponent)
            rootNodes[rootPath] = node

            // Cada componente entre a raiz e o projeto vira um nível.
            let relative = String(projectPath.dropFirst(rootPath.count))
                .split(separator: "/")
                .map(String.init)

            var current = node
            var walked = scanRoot
            for component in relative {
                walked = walked.appending(path: component, directoryHint: .isDirectory)
                let child = current.children[component] ?? Node(url: walked, name: component)
                current.children[component] = child
                current = child
            }
            current.isProject = true
            current.ecosystem = current.ecosystem ?? finding.ecosystem
            current.leaves.append(finding)
        }

        var nodes = rootNodes.values
            .map { convert($0, isRoot: true) }
            .sorted { $0.size > $1.size }

        // Uma pasta escaneada só não merece um nível próprio: o que interessa
        // dela já está na barra lateral.
        if nodes.count == 1 {
            nodes = nodes[0].children + [nodes[0]].filter { !$0.leaves.isEmpty }
            nodes.sort { $0.size > $1.size }
        }

        nodes += cacheNodes(from: findings)
        return nodes
    }

    private func convert(_ node: Node, isRoot: Bool = false) -> TreeNode {
        var name = node.name
        var node = node

        // Cadeia de pastas sem bifurcação vira uma linha só (`clientes/acme`),
        // senão a árvore vira escada.
        while !node.isProject, node.leaves.isEmpty, node.children.count == 1,
              let only = node.children.values.first {
            name += "/" + only.name
            node = only
        }

        let kind: TreeNode.Kind = if node.isProject {
            .project(node.url, node.ecosystem)
        } else if isRoot {
            .root(node.url)
        } else {
            .directory(node.url)
        }

        return TreeNode(
            id: node.url.path(percentEncoded: false),
            kind: kind,
            name: name,
            children: node.children.values.map { convert($0) }.sorted { $0.size > $1.size },
            leaves: node.leaves.sorted { $0.size > $1.size }
        )
    }

    /// Caches não têm projeto: viram um nó por categoria, no fim da lista.
    private func cacheNodes(from findings: [Finding]) -> [TreeNode] {
        let byCategory = Dictionary(grouping: findings.filter { $0.cacheCategory != nil }) {
            $0.cacheCategory!
        }
        return CacheCategory.allCases.compactMap { category in
            guard let entries = byCategory[category], !entries.isEmpty else { return nil }
            return TreeNode(
                id: "cache:\(category.rawValue)",
                kind: .cacheCategory(category),
                name: category.label,
                children: [],
                leaves: entries.sorted { $0.size > $1.size }
            )
        }
    }
}
