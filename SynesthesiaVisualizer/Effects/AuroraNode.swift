import RealityKit
import UIKit

/// Northern lights as they look from the ground: long, soft bands of light high in the sky.
///
/// Each band is a tall curtain whose bottom edge sits about ten metres up and runs for tens of
/// metres. Seen from below, bands running away from you converge toward the horizon, as in
/// photographs of the aurora. Each has a brighter lower edge that fades softly upward into a
/// second colour, made of soft vertical rays; two ray layers drift against each other so the
/// light shimmers. Bands sway and curl slowly, with faster ripples running along them.
/// Colours blend smoothly from note to note, and the light swells and fades with the music.
@MainActor
final class AuroraNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.aurora

    private struct Band {
        let lower: CurtainMesh
        let shimmer: CurtainMesh
        let upper: CurtainMesh
        /// Sideways offset (front and above) or direction (all around), from -1 to 1.
        let offset: Float
        let phase: Float
        let bottom: Float
        let heightScale: Float
        let brightness: Float
    }

    private static let columns = 160
    private static let rows = 14

    private var bands: [Band] = []
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
        let settings: [(offset: Float, phase: Float, bottom: Float, height: Float, brightness: Float)] = [
            (-0.85, 0.0, 10, 1.0, 0.75),
            (-0.45, 2.1, 9, 1.2, 1.0),
            (-0.1, 4.0, 11, 0.9, 0.85),
            (0.25, 1.2, 9.5, 1.3, 1.0),
            (0.6, 3.1, 10.5, 1.0, 0.8),
            (0.95, 5.0, 12, 0.8, 0.6),
        ]
        for s in settings {
            guard let lower = CurtainMesh(columns: Self.columns, rows: Self.rows),
                  let shimmer = CurtainMesh(columns: Self.columns, rows: Self.rows),
                  let upper = CurtainMesh(columns: Self.columns, rows: Self.rows) else { continue }
            entity.addChild(upper.entity)
            entity.addChild(lower.entity)
            entity.addChild(shimmer.entity)
            bands.append(Band(lower: lower, shimmer: shimmer, upper: upper, offset: s.offset, phase: s.phase,
                              bottom: s.bottom, heightScale: s.height, brightness: s.brightness))
        }
    }

    func update(_ c: LayerContext) {
        let dt = c.deltaTime
        drift += dt * 0.08 * c.speed
        kinkDrift += dt * (0.5 + 0.7 * glow) * c.speed
        rayDrift += dt * 0.008 * c.speed

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

        for band in bands {
            let height = 8 * band.heightScale * (0.85 + 0.3 * glow)
            let shape = { (a: Float, h: Float, reach: Float) -> SIMD3<Float> in
                self.point(along: a, up: h, height: height * reach, band: band,
                           placement: c.layer.placement) * scale
            }
            let p = band.phase * 0.1
            curtainUpdate(band.lower, shape, reach: 1, u: { a in a * 12 + self.rayDrift + p })
            curtainUpdate(band.shimmer, shape, reach: 1.05, u: { a in a * 12.7 - self.rayDrift * 1.6 + p })
            curtainUpdate(band.upper, shape, reach: 1.5, u: { a in a * 10 - self.rayDrift * 0.6 + p })

            let alpha = opacity * band.brightness
            band.lower.entity.model?.materials = [texturedLight(lowUI, texture: lowerTexture, opacity: alpha * 0.55)]
            band.shimmer.entity.model?.materials = [texturedLight(lowUI, texture: shimmerTexture, opacity: alpha * 0.35)]
            band.upper.entity.model?.materials = [texturedLight(highUI, texture: upperTexture, opacity: alpha * 0.3)]
        }
    }

    private func curtainUpdate(_ mesh: CurtainMesh, _ shape: (Float, Float, Float) -> SIMD3<Float>,
                               reach: Float, u: (Float) -> Float) {
        mesh.update(position: { a, h in shape(a, h, reach) }, u: u)
    }

    /// A point on a band at size 1, in metres from the placement's anchor.
    /// `a` runs along the band (0...1), `h` up it (0 at the bottom edge, 1 at the top).
    private func point(along a: Float, up h: Float, height: Float, band: Band,
                       placement: Placement) -> SIMD3<Float> {
        let d = drift + band.phase
        let k = kinkDrift + band.phase * 2
        let sway = pow(h, 1.3)   // the top drifts more than the bottom edge

        // Distance along the band, and the band's slow curls and faster ripples sideways to it.
        let along: Float
        let side: Float
        switch placement {
        case .front: along = 6 - a * 75          // from just overhead to far off near the horizon
        case .above: along = 35 - a * 70         // passing right over you
        case .surround: along = 3 + a * 60       // from overhead outward
        }
        let curl = 4.5 * sin(0.05 * along + d) + 1.8 * sin(0.13 * along - d * 1.3)
        let ripple = 0.35 * sin(0.9 * along - k) * (1 - 0.5 * h)
        let lean = 1.2 * sway * sin(0.07 * along + d * 0.6 + h)
        side = curl + ripple + lean
        let bottom = band.bottom + 1.0 * sin(0.04 * along + d * 0.7)
        // Bands thin out to nothing at their ends instead of stopping abruptly.
        let taper = smooth(0, 0.18, a) * (1 - smooth(0.7, 1, a))
        let y = bottom + h * height * taper

        switch placement {
        case .front, .above:
            let x = band.offset * 18 + side
            return [x, y, along]
        case .surround:
            // Bands radiate out from overhead in every direction, like an aurora corona.
            let angle = (band.offset + 1) * .pi + d * 0.05
            let dir = SIMD2<Float>(cos(angle), sin(angle))
            let perp = SIMD2<Float>(-dir.y, dir.x)
            let flat = dir * along + perp * side
            return [flat.x, y, flat.y]
        }
    }

    private func smooth(_ lo: Float, _ hi: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
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
                              bounds: BoundingBox(min: [-120, -10, -120], max: [120, 80, 120])),
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
        for f in stride(from: 2, through: 26, by: 2) {
            let amp = (0.4 + 0.6 * random()) / sqrt(Float(f))
            sum += amp * sin(2 * .pi * (Float(f) * u + random()))
            total += amp
        }
        // Sharpen into distinct streaks, with a dim floor between them.
        let n = 0.5 + 0.5 * sum / total
        return 0.35 + 0.65 * pow(max(0, n), 1.6) * 1.6
    }

    /// A sharp, bright lower edge that fades upward through the rays.
    @MainActor
    static func makeLower(seed: UInt32) -> MaterialParameters.Texture? {
        TextureMaker.make(width: 1024, height: 128, repeatsHorizontally: true) { u, v in
            let up = 1 - v                                     // image rows run top to bottom
            let edge = smoothstep(0, 0.1, up)
            let fade = 0.75 * exp(-up * 2.6) + 0.25 * (1 - up)
            return min(1, rays(u, seed: seed) * edge * fade)
        }
    }

    /// A soft, high glow of the second colour at the top of the curtain.
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
