import AppKit
import CoreGraphics

/// Gera o iconset do Reclaim. O ícone é desenhado, não desenhado à mão em editor,
/// para que qualquer ajuste seja uma mudança de código revisável — e para que as
/// dez resoluções saiam sempre consistentes entre si.
///
/// A forma: um anel de disco com um setor aberto — o espaço que você recupera —
/// e uma seta subindo por dentro dessa abertura.
func drawIcon(size: CGFloat, context ctx: CGContext) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Margem que a Apple usa nos ícones de app: o desenho não encosta na borda.
    let inset = size * 0.086
    let plate = rect.insetBy(dx: inset, dy: inset)
    let radius = plate.width * 0.2237   // squircle do macOS Big Sur em diante

    let shape = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Fundo: azul profundo no topo para ciano embaixo, como um disco iluminado.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.145, green: 0.404, blue: 0.925, alpha: 1).cgColor,
        NSColor(srgbRed: 0.180, green: 0.671, blue: 0.949, alpha: 1).cgColor,
        NSColor(srgbRed: 0.259, green: 0.855, blue: 0.851, alpha: 1).cgColor,
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])

    // Brilho diagonal no topo, para o ícone não ficar chapado.
    ctx.setBlendMode(.softLight)
    ctx.setFillColor(NSColor(white: 1, alpha: 0.30).cgColor)
    ctx.move(to: CGPoint(x: plate.minX, y: plate.maxY))
    ctx.addLine(to: CGPoint(x: plate.maxX, y: plate.maxY))
    ctx.addLine(to: CGPoint(x: plate.minX, y: plate.midY))
    ctx.closePath()
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.restoreGState()

    let center = CGPoint(x: plate.midX, y: plate.midY)
    let ringRadius = plate.width * 0.295
    let ringWidth = plate.width * 0.135

    // O anel, aberto no topo: o setor que falta é o espaço liberado.
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(ringWidth)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.95).cgColor)
    // A abertura fica embaixo, e não em cima: um anel aberto no topo com uma
    // haste no meio é o símbolo universal de liga/desliga. Aberto embaixo, lê
    // como medidor — quanto do disco está ocupado.
    ctx.addArc(center: center, radius: ringRadius,
               startAngle: .pi * 1.667, endAngle: .pi * 1.333, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // A seta que sobe pela abertura: o espaço voltando para você.
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.cgColor)
    let stem = plate.width * 0.072
    // A seta agora vive dentro do anel, sem furá-lo.
    let arrowTop = center.y + ringRadius * 0.60
    let arrowBottom = center.y - ringRadius * 0.62
    let headWidth = plate.width * 0.190
    let headHeight = plate.width * 0.145

    // Haste com cantos arredondados.
    let stemRect = CGRect(x: center.x - stem / 2, y: arrowBottom,
                          width: stem, height: arrowTop - headHeight - arrowBottom + stem * 0.5)
    ctx.addPath(CGPath(roundedRect: stemRect, cornerWidth: stem / 2, cornerHeight: stem / 2, transform: nil))
    ctx.fillPath()

    // Ponta triangular, com o vértice levemente arredondado pelo join.
    ctx.setLineJoin(.round)
    ctx.setLineWidth(plate.width * 0.028)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.move(to: CGPoint(x: center.x - headWidth / 2, y: arrowTop - headHeight))
    ctx.addLine(to: CGPoint(x: center.x, y: arrowTop))
    ctx.addLine(to: CGPoint(x: center.x + headWidth / 2, y: arrowTop - headHeight))
    ctx.closePath()
    ctx.drawPath(using: .fillStroke)
    ctx.restoreGState()
}

func writePNG(size: Int, to url: URL) {
    let width = size, height = size
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawIcon(size: CGFloat(size), context: ctx)
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: width, height: height)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(filePath: CommandLine.arguments[1], directoryHint: .isDirectory)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
// Os dez tamanhos que o iconutil espera num .iconset.
for (size, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                     (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                     (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                     (1024, "icon_512x512@2x")] {
    writePNG(size: size, to: out.appending(path: "\(name).png"))
}
print("iconset em \(out.path)")
