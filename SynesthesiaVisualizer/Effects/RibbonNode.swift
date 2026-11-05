import RealityKit
import Metal
import UIKit

/// Flowing light: several soft, glowing strands that braid around a path, like water.
///
/// The head of the flow wanders through space and rises with higher, brighter sounds.
/// Each strand takes the colour of one of the strongest notes, so a chord shows as
/// several coloured currents. Light streaks travel along the strands, faster when
/// the music is louder.
@MainActor
final class RibbonNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.ribbon

    private struct Strand {
        let core: FlowMesh
        let halo: FlowMesh
        let phase: Float
    }

    private static let pointCount = 140
    private static let sampleInterval: Float = 1.0 / 60

    private var strands: [Strand] = []
    private var path: [SIMD3<Float>]
    private var started = false
    private var sampleClock: Float = 0
    private var wander: Float = 0
    private var flow: Float = 0
    private let texture = FlowTexture.make()

    init(strandCount: Int = 3) {
        path = Array(repeating: .zero, count: Self.pointCount)
        for s in 0..<strandCount {
            guard let core = FlowMesh(points: Self.pointCount),
                  let halo = FlowMesh(points: Self.pointCount) else { continue }
            entity.addChild(halo.entity)
            entity.addChild(core.entity)
            strands.append(Strand(core: core, halo: halo, phase: Float(s) * 2 * .pi / Float(strandCount)))
        }
    }

    func update(_ c: LayerContext) {
        let speed = Float(c.layer.speed)
        let size = Float(c.layer.size)
        let drive = min(1.5, c.drive)

        wander += c.deltaTime * speed * (0.5 + 0.5 * drive)
        flow += c.deltaTime * (0.3 + 0.9 * speed) * (0.6 + drive)

        let head = headPosition(placement: c.layer.placement, height: (c.features.brightness - 0.5) * 0.9)
        if !started {
            path = Array(repeating: head, count: Self.pointCount)
            started = true
        }

        // Record the head's position at a steady rate, so the trail length doesn't depend on frame rate.
        sampleClock += c.deltaTime
        let steps = min(Self.pointCount - 1, Int(sampleClock / Self.sampleInterval))
        if steps > 0 {
            sampleClock -= Float(steps) * Self.sampleInterval
            path.removeLast(steps)
            path.insert(contentsOf: Array(repeating: head, count: steps), at: 0)
        }
        path[0] = head

        let strongestNotes = c.features.chroma.indices.sorted { c.features.chroma[$0] > c.features.chroma[$1] }
        let opacity = Float(c.layer.opacity)

        for (k, strand) in strands.enumerated() {
            let pitchClass: Int
            let strength: Float
            switch c.layer.colorSource {
            case .notes:
                pitchClass = strongestNotes[k % strongestNotes.count]
                strength = k == 0 ? 1 : max(0.2, c.features.chroma[pitchClass])
            case .single:
                pitchClass = c.features.dominantPitchClass
                strength = k == 0 ? 1 : 0.6
            }
            let color = c.color(forPitchClass: pitchClass)

            let radius = 0.05 * size * (0.8 + 0.8 * drive)
            let halfWidth = 0.05 * size * (0.6 + 0.9 * drive)
            let swirl = strand.phase + wander * 1.8

            strand.core.update(path: path, offsetRadius: radius, offsetPhase: swirl, twist: 0.09,
                               halfWidth: halfWidth, flow: flow + strand.phase, viewer: c.viewer)
            strand.halo.update(path: path, offsetRadius: radius, offsetPhase: swirl, twist: 0.09,
                               halfWidth: halfWidth * 2.8, flow: flow * 0.6 + strand.phase, viewer: c.viewer)

            strand.core.entity.model?.materials = [flowMaterial(color, opacity: opacity * strength)]
            strand.halo.entity.model?.materials = [flowMaterial(color, opacity: opacity * strength * 0.28)]
        }
    }

    private func headPosition(placement: Placement, height: Float) -> SIMD3<Float> {
        let w = wander
        switch placement {
        case .surround:
            let angle = w * 0.5
            let radius: Float = 1.5 + 0.2 * sin(w * 0.9)
            return [cos(angle) * radius, height + 0.2 * sin(w * 1.3), sin(angle) * radius]
        case .front, .above:
            return [0.8 * sin(w * 0.45) + 0.15 * sin(w * 1.3 + 1),
                    height + 0.22 * sin(w * 0.7),
                    0.3 * sin(w * 0.35) + 0.1 * cos(w * 1.1)]
        }
    }

    private func flowMaterial(_ color: UIColor, opacity: Float) -> UnlitMaterial {
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
}

/// A flat strip of triangles that follows a path, rebuilt in place every frame.
@MainActor
final class FlowMesh {
    struct Vertex {
        var position: SIMD3<Float> = .zero
        var normal: SIMD3<Float> = [0, 0, 1]
        var uv: SIMD2<Float> = .zero
    }

    let entity: ModelEntity
    private let mesh: LowLevelMesh
    private let points: Int

    init?(points: Int) {
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal)!),
            .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
        ]
        descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
        descriptor.vertexCapacity = points * 2
        // Both windings, so the strip is visible from either side.
        let indexCount = (points - 1) * 12
        descriptor.indexCapacity = indexCount
        descriptor.indexType = .uint32

        guard let mesh = try? LowLevelMesh(descriptor: descriptor) else { return nil }

        mesh.withUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to: UInt32.self)
            for i in 0..<(points - 1) {
                let a = UInt32(i * 2)
                let o = i * 12
                let quad: [UInt32] = [a, a + 1, a + 2, a + 1, a + 3, a + 2,
                                      a, a + 2, a + 1, a + 1, a + 2, a + 3]
                for j in 0..<12 { indices[o + j] = quad[j] }
            }
        }
        mesh.parts.replaceAll([
            LowLevelMesh.Part(indexCount: indexCount, topology: .triangle,
                              bounds: BoundingBox(min: [-4, -4, -4], max: [4, 4, 4])),
        ])

        guard let resource = try? MeshResource(from: mesh) else { return nil }
        self.mesh = mesh
        self.points = points
        entity = ModelEntity(mesh: resource, materials: [UnlitMaterial(color: .white)])
    }

    func update(path: [SIMD3<Float>], offsetRadius: Float, offsetPhase: Float, twist: Float,
                halfWidth: Float, flow: Float, viewer: SIMD3<Float>) {
        let n = min(points, path.count)
        guard n > 1 else { return }

        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let vertices = raw.bindMemory(to: Vertex.self)
            for i in 0..<n {
                let p = path[i]
                var tangent = path[max(0, i - 1)] - path[min(n - 1, i + 1)]
                if simd_length(tangent) < 1e-5 { tangent = [1, 0, 0] }
                tangent = simd_normalize(tangent)

                var n1 = simd_cross(tangent, SIMD3<Float>(0, 1, 0))
                if simd_length(n1) < 1e-4 { n1 = simd_cross(tangent, SIMD3<Float>(1, 0, 0)) }
                n1 = simd_normalize(n1)
                let n2 = simd_cross(tangent, n1)

                // Each strand spirals around the shared path.
                let angle = offsetPhase + Float(i) * twist
                let centre = p + offsetRadius * (cos(angle) * n1 + sin(angle) * n2)

                // Turn the strip to face the viewer, so it always reads as a band of light.
                let toViewer = viewer - centre
                var side = simd_cross(tangent, toViewer)
                if simd_length(side) < 1e-4 { side = n1 }
                side = simd_normalize(side)
                let normal = simd_length(toViewer) > 1e-4 ? simd_normalize(toViewer) : SIMD3<Float>(0, 0, 1)

                let along = Float(i) / Float(n - 1)
                let taper = pow(1 - along, 0.8) * min(1, Float(i + 1) / 6)
                let width = halfWidth * taper
                let u = along * 3 - flow

                vertices[i * 2] = Vertex(position: centre + side * width, normal: normal, uv: [u, 0])
                vertices[i * 2 + 1] = Vertex(position: centre - side * width, normal: normal, uv: [u, 1])
            }
        }
    }
}
