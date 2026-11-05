import RealityKit
import UIKit

/// A cloud of glowing orbs. Each orb belongs to one of the 12 notes and swells when that note sounds.
@MainActor
final class OrbsNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.orbs

    private var orbs: [ModelEntity] = []
    private let seeds: [SIMD3<Float>]

    init(count: Int = 24) {
        let mesh = MeshResource.generateSphere(radius: 0.05)
        seeds = (0..<count).map { _ in
            SIMD3(Float.random(in: 0...(2 * .pi)), Float.random(in: 0...(2 * .pi)), Float.random(in: 0...(2 * .pi)))
        }
        for _ in 0..<count {
            let orb = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
            entity.addChild(orb)
            orbs.append(orb)
        }
    }

    func update(_ c: LayerContext) {
        let t = c.time * Float(c.layer.speed)
        let size = Float(c.layer.size)
        let drive = c.drive

        for (i, orb) in orbs.enumerated() {
            let s = seeds[i]
            let pitchClass = i % 12

            switch c.layer.placement {
            case .surround:
                let angle = s.x + t * 0.25
                let radius: Float = 1.6 + 0.2 * sin(t + s.y)
                orb.position = [cos(angle) * radius, 0.4 * sin(t * 0.7 + s.z), sin(angle) * radius]
            case .front, .above:
                orb.position = [0.6 * sin(t * 0.5 + s.x), 0.35 * sin(t * 0.37 + s.y), 0.25 * sin(t * 0.29 + s.z)]
            }

            let noteEnergy: Float = c.layer.colorSource == .notes ? c.features.chroma[pitchClass] : 1
            let scale = size * (0.3 + 0.7 * noteEnergy) * (0.6 + 1.2 * drive)
            orb.scale = SIMD3(repeating: max(0.05, scale))

            let opacity = Float(c.layer.opacity) * (0.25 + 0.75 * max(noteEnergy * 0.7, min(1, drive)))
            orb.model?.materials = [glowMaterial(c.color(forPitchClass: pitchClass), opacity: opacity)]
        }
    }
}

/// Sparks that burst outward on each beat, in the colour of the note playing.
@MainActor
final class BurstsNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.bursts

    private let emitterEntity = Entity()
    private var lastBeat = -1

    init() {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.05, 0.05, 0.05]
        emitter.speed = 0.8
        emitter.burstCount = 150
        emitter.mainEmitter.birthRate = 0
        emitter.mainEmitter.lifeSpan = 1.2
        emitter.mainEmitter.size = 0.012
        emitter.mainEmitter.blendMode = .additive
        emitterEntity.components.set(emitter)
        entity.addChild(emitterEntity)
    }

    func update(_ c: LayerContext) {
        guard c.features.beatCount != lastBeat else { return }
        let isFirstFrame = lastBeat < 0
        lastBeat = c.features.beatCount
        guard !isFirstFrame, var emitter = emitterEntity.components[ParticleEmitterComponent.self] else { return }

        emitter.mainEmitter.color = .constant(.single(c.currentColor))
        emitter.burstCount = Int(60 + 300 * min(1, c.drive))
        emitter.speed = 0.4 + 0.8 * Float(c.layer.speed)
        emitter.mainEmitter.size = 0.012 * Float(c.layer.size)

        switch c.layer.placement {
        case .surround:
            let angle = Float.random(in: 0..<(2 * .pi))
            emitterEntity.position = [cos(angle) * 1.6, Float.random(in: -0.3...0.4), sin(angle) * 1.6]
        case .front, .above:
            emitterEntity.position = [Float.random(in: -0.4...0.4), Float.random(in: -0.2...0.2), 0]
        }

        emitter.burst()
        emitterEntity.components.set(emitter)
    }
}
