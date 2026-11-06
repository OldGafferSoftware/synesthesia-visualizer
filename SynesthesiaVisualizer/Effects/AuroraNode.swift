import RealityKit
import UIKit

/// Northern lights: soft curtains of light that ripple and fold like slow waves.
///
/// Each curtain is a flexible sheet: gentle waves roll along it and travel up it, so the
/// top sways more than the bottom, as in a real aurora. It has a bright lower edge that
/// fades upward into a fainter fringe of a second colour. Three curtains at different
/// depths give it volume. Colours blend smoothly from note to note rather than jumping,
/// and the light swells and fades gradually with the music.
@MainActor
final class AuroraNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.aurora

    private struct Curtain {
        let lower: CurtainMesh
        let upper: CurtainMesh
        let depth: Float
        let phase: Float
        let heightScale: Float
        let brightness: Float
    }

    private static let columns = 120
    private static let rows = 14

    private var curtains: [Curtain] = []
    private let lowerTexture = AuroraTexture.makeLower()
    private let upperTexture = AuroraTexture.makeUpper()

    private var drift: Float = 0
    private var rayDrift: Float = 0
    private var glow: Float = 0.3
    private var lowColor = SIMD3<Float>(0.3, 1, 0.6)
    private var highColor = SIMD3<Float>(0.6, 0.3, 1)

    init() {
        let settings: [(depth: Float, phase: Float, height: Float, brightness: Float)] = [
            (0, 0, 1, 1),
            (-0.45, 1.9, 1.15, 0.65),
            (-0.9, 3.7, 0.9, 0.45),
        ]
        for s in settings.reversed() {   // farthest first, so nearer curtains draw over them
            guard let lower = CurtainMesh(columns: Self.columns, rows: Self.rows),
                  let upper = CurtainMesh(columns: Self.columns, rows: Self.rows) else { continue }
            entity.addChild(upper.entity)
            entity.addChild(lower.entity)
            curtains.append(Curtain(lower: lower, upper: upper, depth: s.depth, phase: s.phase,
                                    heightScale: s.height, brightness: s.brightness))
        }
    }

    func update(_ c: LayerContext) {
        let dt = c.deltaTime
        drift += dt * 0.16 * c.speed
        rayDrift += dt * 0.015 * c.speed

        // Swell and fade slowly, the way an aurora brightens.
        let target = min(1.1, c.drive)
        glow += (target - glow) * min(1, dt * 1.2)

        // Blend colours over about a second instead of jumping with every note.
        let (lowTarget, highTarget) = targetColors(c)
        let blend = min(1, dt * 1.0)
        lowColor += (lowTarget - lowColor) * blend
        highColor += (highTarget - highColor) * blend

        let size = Float(c.layer.size)
        let opacity = Float(c.layer.opacity) * (0.4 + 0.6 * min(1, glow))
        let lowUI = UIColor(red: CGFloat(lowColor.x), green: CGFloat(lowColor.y), blue: CGFloat(lowColor.z), alpha: 1)
        let highUI = UIColor(red: CGFloat(highColor.x), green: CGFloat(highColor.y), blue: CGFloat(highColor.z), alpha: 1)

        for curtain in curtains {
            let height = 1.2 * size * curtain.heightScale * (0.9 + 0.2 * glow)
            let shape = { (a: Float, h: Float, reach: Float) -> SIMD3<Float> in
                self.point(along: a, up: h, height: height * reach, curtain: curtain,
                           placement: c.layer.placement, size: size)
            }
            curtain.lower.update(position: { a, h in shape(a, h, 1) },
                                 u: { a in a * 2 + self.rayDrift + curtain.phase * 0.1 })
            curtain.upper.update(position: { a, h in shape(a, h, 1.5) },
                                 u: { a in a * 1.6 - self.rayDrift * 0.7 + curtain.phase * 0.1 })

            curtain.lower.entity.model?.materials = [texturedLight(lowUI, texture: lowerTexture, opacity: opacity * curtain.brightness)]
            curtain.upper.entity.model?.materials = [texturedLight(highUI, texture: upperTexture, opacity: opacity * curtain.brightness * 0.7)]
        }
    }

    /// A point on a curtain. `a` runs along it (0...1), `h` up it (0 at the bottom edge, 1 at the top).
    private func point(along a: Float, up h: Float, height: Float, curtain: Curtain,
                       placement: Placement, size: Float) -> SIMD3<Float> {
        let d = drift + curtain.phase
        // Large, slow folds along the curtain, and waves that travel upward and grow with height.
        let sway = pow(h, 1.4)

        switch placement {
        case .surround:
            let angle = a * 2 * .pi
            let fold = 0.25 * sin(3 * angle + d * 0.9) + 0.1 * sin(5 * angle - d * 1.3)
            let rise = 0.3 * sway * sin(2 * angle - d * 0.8 + 2.2 * h)
            let radius = 2.5 - curtain.depth + fold + rise
            let bottom = 0.85 + 0.06 * sin(4 * angle + d * 0.7)
            return [cos(angle) * radius, bottom + h * height, sin(angle) * radius]

        case .front, .above:
            let x = (a - 0.5) * 5 * size
            let fold = 0.35 * sin(0.9 * x + d * 0.8) + 0.14 * sin(2.1 * x - d * 1.1)
            let rise = 0.3 * sway * sin(1.3 * x - d * 0.9 + 2.2 * h)
            let sideways = 0.18 * sway * sin(0.7 * x + d * 0.5)
            let baseHeight: Float = placement == .above ? 0.1 : 0.6
            let bottom = baseHeight + 0.07 * sin(1.5 * x + d * 0.6)
            return [x + sideways, bottom + h * height, -1.2 + curtain.depth + fold + rise]
        }
    }

    private func targetColors(_ c: LayerContext) -> (SIMD3<Float>, SIMD3<Float>) {
        switch c.layer.colorSource {
        case .notes:
            let order = c.features.chroma.indices.sorted { c.features.chroma[$0] > c.features.chroma[$1] }
            let second = order.count > 1 ? order[1] : order[0]
            return (rgb(c.color(forPitchClass: order[0])), rgb(c.color(forPitchClass: second)))
        case .single:
            let base = c.layer.singleColor.uiColor
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let shifted = UIColor(hue: (h + 0.22).truncatingRemainder(dividingBy: 1), saturation: s, brightness: b, alpha: 1)
            return (rgb(base), rgb(shifted))
        }
    }

    private func rgb(_ color: UIColor) -> SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Float(r), Float(g), Float(b)]
    }
}

/// A flexible rectangular sheet (columns × rows of vertices), reshaped every frame.
@MainActor
final class CurtainMesh {
    let entity: ModelEntity
    private let mesh: LowLevelMesh
    private let columns: Int
    private let rows: Int

    init?(columns: Int, rows: Int) {
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<FlowMesh.Vertex>.offset(of: \.position)!),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<FlowMesh.Vertex>.offset(of: \.normal)!),
            .init(semantic: .uv0, format: .float2, offset: MemoryLayout<FlowMesh.Vertex>.offset(of: \.uv)!),
        ]
        descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<FlowMesh.Vertex>.stride)]
        descriptor.vertexCapacity = columns * rows
        let indexCount = (columns - 1) * (rows - 1) * 12   // both windings, visible from either side
        descriptor.indexCapacity = indexCount
        descriptor.indexType = .uint32

        guard let mesh = try? LowLevelMesh(descriptor: descriptor) else { return nil }
        mesh.withUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to: UInt32.self)
            var o = 0
            for col in 0..<(columns - 1) {
                for row in 0..<(rows - 1) {
                    let a = UInt32(col * rows + row)        // bottom-left
                    let b = a + 1                            // top-left
                    let c = UInt32((col + 1) * rows + row)  // bottom-right
                    let d = c + 1                            // top-right
                    for index in [a, c, b, b, c, d, a, b, c, b, d, c] {
                        indices[o] = index
                        o += 1
                    }
                }
            }
        }
        mesh.parts.replaceAll([
            LowLevelMesh.Part(indexCount: indexCount, topology: .triangle,
                              bounds: BoundingBox(min: [-5, -5, -5], max: [5, 5, 5])),
        ])
        guard let resource = try? MeshResource(from: mesh) else { return nil }
        self.mesh = mesh
        self.columns = columns
        self.rows = rows
        entity = ModelEntity(mesh: resource, materials: [UnlitMaterial(color: .white)])
    }

    /// `position(a, h)` gives each vertex: `a` along the sheet (0...1), `h` up it (0...1).
    func update(position: (Float, Float) -> SIMD3<Float>, u: (Float) -> Float) {
        let columns = columns, rows = rows
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let vertices = raw.bindMemory(to: FlowMesh.Vertex.self)
            for col in 0..<columns {
                let a = Float(col) / Float(columns - 1)
                let uValue = u(a)
                for row in 0..<rows {
                    let h = Float(row) / Float(rows - 1)
                    vertices[col * rows + row] = FlowMesh.Vertex(position: position(a, h), normal: [0, 0, 1], uv: [uValue, h])
                }
            }
        }
    }
}

enum AuroraTexture {
    /// Soft, broad vertical rays, seamless across the repeat.
    private static func rays(_ u: Float) -> Float {
        let r = 0.78
            + 0.12 * sin(2 * .pi * (4 * u))
            + 0.07 * sin(2 * .pi * (7 * u + 0.3))
            + 0.03 * sin(2 * .pi * (11 * u + 0.7))
        return max(0, min(1, r))
    }

    /// Bright lower edge that fades smoothly upward.
    @MainActor
    static func makeLower() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 512, height: 128, repeatsHorizontally: true) { u, v in
            let up = 1 - v                                     // image rows run top to bottom
            let edge = smoothstep(0, 0.08, up)
            let fade = exp(-up * 2.4)
            return rays(u) * edge * fade
        }
    }

    /// A faint glow higher up the curtain.
    @MainActor
    static func makeUpper() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 512, height: 128, repeatsHorizontally: true) { u, v in
            let up = 1 - v
            let band = exp(-pow((up - 0.6) / 0.28, 2))
            return 0.75 * rays(u * 0.8 + 0.13) * band
        }
    }

    private static func smoothstep(_ lo: Float, _ hi: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
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
