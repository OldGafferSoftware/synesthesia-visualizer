import RealityKit
import UIKit

/// Northern lights at sky scale: tall curtains far away and above eye level, so you look up at
/// them (they show through walls and ceiling, like a window onto the sky).
///
/// Each curtain has a sharp, bright lower edge that fades upward into a faint fringe of a second
/// colour, and is made of many fine vertical rays. Two ray layers drift against each other so the
/// rays shimmer. The curtain folds slowly, and small faster kinks ripple along its lower edge.
/// Three curtains at different distances give depth. Colours blend smoothly from note to note,
/// and the light swells and fades gradually with the music.
@MainActor
final class AuroraNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.aurora

    private struct Curtain {
        let lower: CurtainMesh
        let shimmer: CurtainMesh
        let upper: CurtainMesh
        /// 0 is the nearest curtain; larger numbers are farther away.
        let distance: Float
        let phase: Float
        let heightScale: Float
        let brightness: Float
    }

    private static let columns = 220
    private static let rows = 16

    private var curtains: [Curtain] = []
    private let lowerTexture = AuroraTexture.makeLower(seed: 1)
    private let shimmerTexture = AuroraTexture.makeLower(seed: 2)
    private let upperTexture = AuroraTexture.makeUpper()

    private var drift: Float = 0
    private var kinkDrift: Float = 0
    private var rayDrift: Float = 0
    private var glow: Float = 0.3
    private var lowColor = SIMD3<Float>(0.3, 1, 0.6)
    private var highColor = SIMD3<Float>(0.6, 0.3, 1)

    init() {
        let settings: [(distance: Float, phase: Float, height: Float, brightness: Float)] = [
            (0, 0, 1, 1),
            (1, 1.9, 1.25, 0.7),
            (2.2, 3.7, 0.85, 0.5),
        ]
        for s in settings.reversed() {   // farthest first, so nearer curtains draw over them
            guard let lower = CurtainMesh(columns: Self.columns, rows: Self.rows),
                  let shimmer = CurtainMesh(columns: Self.columns, rows: Self.rows),
                  let upper = CurtainMesh(columns: Self.columns, rows: Self.rows) else { continue }
            entity.addChild(upper.entity)
            entity.addChild(lower.entity)
            entity.addChild(shimmer.entity)
            curtains.append(Curtain(lower: lower, shimmer: shimmer, upper: upper, distance: s.distance,
                                    phase: s.phase, heightScale: s.height, brightness: s.brightness))
        }
    }

    func update(_ c: LayerContext) {
        let dt = c.deltaTime
        drift += dt * 0.12 * c.speed
        kinkDrift += dt * (0.6 + 0.8 * glow) * c.speed
        rayDrift += dt * 0.01 * c.speed

        // Swell and fade slowly, the way an aurora brightens.
        let target = min(1.1, c.drive)
        glow += (target - glow) * min(1, dt * 1.2)

        // Blend colours over about a second instead of jumping with every note.
        let (lowTarget, highTarget) = targetColors(c)
        let blend = min(1, dt * 1.0)
        lowColor += (lowTarget - lowColor) * blend
        highColor += (highTarget - highColor) * blend

        let scale = Float(c.layer.size)
        let opacity = Float(c.layer.opacity) * (0.45 + 0.55 * min(1, glow))
        let lowUI = UIColor(red: CGFloat(lowColor.x), green: CGFloat(lowColor.y), blue: CGFloat(lowColor.z), alpha: 1)
        let highUI = UIColor(red: CGFloat(highColor.x), green: CGFloat(highColor.y), blue: CGFloat(highColor.z), alpha: 1)

        for curtain in curtains {
            let height = 5 * curtain.heightScale * (0.9 + 0.2 * glow)
            let shape = { (a: Float, h: Float, reach: Float) -> SIMD3<Float> in
                self.point(along: a, up: h, height: height * reach, curtain: curtain,
                           placement: c.layer.placement) * scale
            }
            let p = curtain.phase * 0.1
            curtain.lower.update(position: { a, h in shape(a, h, 1) },
                                 u: { a in a * 6 + self.rayDrift + p })
            curtain.shimmer.update(position: { a, h in shape(a, h, 1.05) },
                                   u: { a in a * 6.4 - self.rayDrift * 1.7 + p })
            curtain.upper.update(position: { a, h in shape(a, h, 1.6) },
                                 u: { a in a * 5 - self.rayDrift * 0.6 + p })

            let alpha = opacity * curtain.brightness
            curtain.lower.entity.model?.materials = [texturedLight(lowUI, texture: lowerTexture, opacity: alpha * 0.8)]
            curtain.shimmer.entity.model?.materials = [texturedLight(lowUI, texture: shimmerTexture, opacity: alpha * 0.55)]
            curtain.upper.entity.model?.materials = [texturedLight(highUI, texture: upperTexture, opacity: alpha * 0.6)]
        }
    }

    /// A point on a curtain at size 1, in metres from the placement's anchor.
    /// `a` runs along the curtain (0...1), `h` up it (0 at the bottom edge, 1 at the top).
    private func point(along a: Float, up h: Float, height: Float, curtain: Curtain,
                       placement: Placement) -> SIMD3<Float> {
        let d = drift + curtain.phase
        let k = kinkDrift + curtain.phase * 2
        // The top sways more than the bottom.
        let sway = pow(h, 1.3)

        switch placement {
        case .surround:
            // A ring of curtains around you, far off.
            let angle = a * 2 * .pi
            let fold = 1.4 * sin(3 * angle + d) + 0.6 * sin(7 * angle - d * 1.4)
            let kink = 0.3 * sin(23 * angle - k) * (1 - 0.5 * h)
            let rise = 0.8 * sway * sin(2 * angle - d * 0.8 + 1.5 * h)
            let radius = 9 + 2.5 * curtain.distance + fold + kink + rise
            let bottom = 1.6 + 0.3 * sin(4 * angle + d * 0.7)
            return [cos(angle) * radius, bottom + h * height, sin(angle) * radius]

        case .front, .above:
            // A long curtain across the sky ahead, or arching overhead.
            let x = (a - 0.5) * 26
            let fold = 1.6 * sin(0.24 * x + d) + 0.7 * sin(0.55 * x - d * 1.3)
            let kink = 0.28 * sin(2.3 * x - k) * (1 - 0.5 * h)
            let rise = 0.9 * sway * sin(0.3 * x - d * 0.9 + 1.5 * h)
            let lean = 0.5 * sway * sin(0.17 * x + d * 0.5)
            let overhead = placement == .above
            let z = overhead ? -(1 + 2.5 * curtain.distance) : -(8 + 2.5 * curtain.distance)
            let bottom: Float = (overhead ? 1.2 : 1.4) + 0.3 * sin(0.4 * x + d * 0.6)
            return [x + lean, bottom + h * height, z + fold + kink + rise]
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
                              bounds: BoundingBox(min: [-60, -10, -60], max: [60, 60, 60])),
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
                    vertices[col * rows + row] = FlowMesh.Vertex(position: position(a, h), normal: [0, 0, 1], uv: [uValue, 1 - h])   // texture row 0 is the bottom edge on device
                }
            }
        }
    }
}

enum AuroraTexture {
    /// Many fine vertical rays of uneven brightness, seamless across the repeat.
    /// Built from whole-number frequencies so the left and right edges match.
    private static func rays(_ u: Float, seed: UInt32) -> Float {
        var state = seed &* 747_796_405 &+ 2_891_336_453
        func random() -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 24)
        }
        var sum: Float = 0
        var total: Float = 0
        for f in stride(from: 3, through: 48, by: 3) {
            let amp = (0.4 + 0.6 * random()) / sqrt(Float(f))
            sum += amp * sin(2 * .pi * (Float(f) * u + random()))
            total += amp
        }
        // Sharpen into distinct streaks, with a dim floor between them.
        let n = 0.5 + 0.5 * sum / total
        return 0.25 + 0.75 * pow(max(0, n), 2.2) * 1.8
    }

    /// A sharp, bright lower edge that fades upward through the rays.
    @MainActor
    static func makeLower(seed: UInt32) -> MaterialParameters.Texture? {
        TextureMaker.make(width: 1024, height: 128, repeatsHorizontally: true) { u, v in
            let up = 1 - v                                     // image rows run top to bottom
            let edge = smoothstep(0, 0.03, up)
            let fade = 0.85 * exp(-up * 3.2) + 0.15 * (1 - up)
            return min(1, rays(u, seed: seed) * edge * fade)
        }
    }

    /// A faint, high glow of the second colour at the top of the curtain.
    @MainActor
    static func makeUpper() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 1024, height: 128, repeatsHorizontally: true) { u, v in
            let up = 1 - v
            let band = smoothstep(0.25, 0.6, up) * (1 - smoothstep(0.75, 1, up))
            return min(1, 0.6 * rays(u, seed: 7) * band)
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
