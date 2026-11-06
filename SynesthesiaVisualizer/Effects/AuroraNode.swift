import RealityKit
import UIKit

/// Northern lights: tall, folded curtains of light with fine vertical rays that drift and shimmer.
///
/// Like a real aurora, each curtain has a bright lower edge that fades upward, with a second,
/// fainter colour higher up. The lower colour follows the strongest note and the upper colour
/// the next strongest. The curtains billow with the music's tempo and brighten as it swells.
@MainActor
final class AuroraNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.aurora

    private static let columns = 160

    private let lower = FlowMesh(points: AuroraNode.columns)
    private let upper = FlowMesh(points: AuroraNode.columns)
    private let lowerTexture = AuroraTexture.makeLower()
    private let upperTexture = AuroraTexture.makeUpper()

    private var drift: Float = 0
    private var rays: Float = 0
    private var glow: Float = 0

    init() {
        if let upper { entity.addChild(upper.entity) }
        if let lower { entity.addChild(lower.entity) }
    }

    func update(_ c: LayerContext) {
        guard let lower, let upper else { return }
        let size = Float(c.layer.size)
        drift += c.deltaTime * 0.25 * c.speed
        rays += c.deltaTime * 0.06 * c.speed
        let target = min(1.2, c.drive)
        glow += (target - glow) * min(1, c.deltaTime * 3)

        let height = 1.1 * size * (0.85 + 0.3 * glow)
        let n = Self.columns
        var bottoms: [SIMD3<Float>] = []
        var tops: [SIMD3<Float>] = []
        var fringeTops: [SIMD3<Float>] = []
        var lowerU: [Float] = []
        var upperU: [Float] = []
        bottoms.reserveCapacity(n)

        for i in 0..<n {
            let a = Float(i) / Float(n - 1)
            let base: SIMD3<Float>
            switch c.layer.placement {
            case .surround:
                let angle = a * 2 * .pi
                let radius: Float = 2.4 + 0.3 * sin(3 * angle + drift * 1.3) + 0.15 * sin(7 * angle - drift * 2.1)
                base = [cos(angle) * radius, 0.9 + 0.08 * sin(5 * angle + drift), sin(angle) * radius]
            case .front, .above:
                let x = (a - 0.5) * 4.5 * size
                let baseHeight: Float = c.layer.placement == .above ? 0.1 : 0.7
                let z = 0.35 * sin(1.4 * x + drift * 1.2) + 0.15 * sin(3.3 * x - drift * 2.0) - 1.2
                base = [x, baseHeight + 0.08 * sin(2.1 * x + drift), z]
            }
            // The curtain leans and sways a little as it rises.
            let lean = SIMD3<Float>(0.12 * sin(drift + a * 6), height, 0.1 * cos(drift * 0.7 + a * 4))
            bottoms.append(base)
            tops.append(base + lean)
            fringeTops.append(base + lean * 1.45)
            lowerU.append(a * 5 + rays)
            upperU.append(a * 4 - rays * 0.6)
        }

        lower.setStrip(left: bottoms, right: tops, u: lowerU, normal: [0, 0, 1])
        upper.setStrip(left: bottoms, right: fringeTops, u: upperU, normal: [0, 0, 1])

        let (lowColor, highColor) = colors(c)
        let opacity = Float(c.layer.opacity) * (0.45 + 0.55 * min(1, glow))
        lower.entity.model?.materials = [texturedLight(lowColor, texture: lowerTexture, opacity: opacity)]
        upper.entity.model?.materials = [texturedLight(highColor, texture: upperTexture, opacity: opacity * 0.75)]
    }

    private func colors(_ c: LayerContext) -> (UIColor, UIColor) {
        switch c.layer.colorSource {
        case .notes:
            let order = c.features.chroma.indices.sorted { c.features.chroma[$0] > c.features.chroma[$1] }
            return (c.color(forPitchClass: order[0]), c.color(forPitchClass: order.count > 1 ? order[1] : order[0]))
        case .single:
            let base = c.layer.singleColor.uiColor
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let shifted = UIColor(hue: (h + 0.22).truncatingRemainder(dividingBy: 1), saturation: s, brightness: b, alpha: 1)
            return (base, shifted)
        }
    }
}

enum AuroraTexture {
    /// Fine vertical rays, seamless across the repeat.
    private static func rays(_ u: Float) -> Float {
        let r = 0.55
            + 0.20 * sin(2 * .pi * (9 * u))
            + 0.15 * sin(2 * .pi * (23 * u + 0.3))
            + 0.10 * sin(2 * .pi * (41 * u + 0.7))
        return max(0, min(1, r))
    }

    /// Bright lower edge that fades upward.
    @MainActor
    static func makeLower() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 512, height: 64, repeatsHorizontally: true) { u, v in
            let up = 1 - v                                   // texture rows run top to bottom
            let edge = min(1, up / 0.06)
            let fade = exp(-up * 2.6)
            return rays(u) * edge * fade
        }
    }

    /// A faint glow higher up the curtain.
    @MainActor
    static func makeUpper() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 512, height: 64, repeatsHorizontally: true) { u, v in
            let up = 1 - v
            let band = exp(-pow((up - 0.62) / 0.24, 2))
            return 0.8 * rays(u * 0.7 + 0.13) * band
        }
    }
}

/// An unlit, see-through material whose shape and brightness come from a greyscale texture.
@MainActor
func texturedLight(_ color: UIColor, texture: MaterialParameters.Texture?, opacity: Float) -> UnlitMaterial {
    var material = UnlitMaterial()
    let scale = min(1, max(0, opacity))
    if let texture {
        material.color = .init(tint: color, texture: texture)
        material.blending = .transparent(opacity: .init(scale: scale, texture: texture))
    } else {
        material.color = .init(tint: color)
        material.blending = .transparent(opacity: .init(scale: scale))
    }
    return material
}
