import RealityKit
import UIKit

/// Soft glows that always face the viewer: a bright centre fading smoothly to nothing.
@MainActor
enum Glow {
    static let texture = GlowTexture.make()
    static let mesh = MeshResource.generatePlane(width: 1, height: 1)

    static func material(_ color: UIColor, opacity: Float) -> UnlitMaterial {
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

    static func makeEntity() -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material(.white, opacity: 0)])
        entity.components.set(BillboardComponent())
        return entity
    }
}

/// A cloud of glowing orbs. Each orb belongs to one of the 12 notes and swells when that note sounds.
@MainActor
final class OrbsNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.orbs

    private var orbs: [ModelEntity] = []
    private let seeds: [SIMD3<Float>]

    init(count: Int = 24) {
        seeds = (0..<count).map { _ in
            SIMD3(Float.random(in: 0...(2 * .pi)), Float.random(in: 0...(2 * .pi)), Float.random(in: 0...(2 * .pi)))
        }
        for _ in 0..<count {
            let orb = Glow.makeEntity()
            entity.addChild(orb)
            orbs.append(orb)
        }
    }

    func update(_ c: LayerContext) {
        let t = c.time * c.speed
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
            // The glow fades out well before the edge of its square, so it needs to be larger than the old spheres.
            let diameter = 0.28 * size * (0.3 + 0.7 * noteEnergy) * (0.6 + 1.2 * drive)
            orb.scale = SIMD3(repeating: max(0.02, diameter))

            let opacity = Float(c.layer.opacity) * (0.25 + 0.75 * max(noteEnergy * 0.7, min(1, drive)))
            orb.model?.materials = [Glow.material(c.color(forPitchClass: pitchClass), opacity: opacity)]
        }
    }
}

/// A light explosion on each beat: a bright flash that blooms and fades, and sparks that
/// fly out white-hot, cool into the note's colour, slow down, droop and leave glittering trails.
@MainActor
final class BurstsNode: LayerNode {
    let entity = Entity()
    let kind = EffectKind.bursts

    private struct Flash {
        let entity: ModelEntity
        var age: Float = 10
        var color: UIColor = .white
        var strength: Float = 0
    }

    private static let flashDuration: Float = 0.45

    private var emitters: [Entity] = []
    private var flashes: [Flash] = []
    private var nextSlot = 0
    private var lastBeat = -1

    init(slots: Int = 4) {
        for _ in 0..<slots {
            let emitter = Entity()
            emitter.components.set(Self.makeEmitter())
            entity.addChild(emitter)
            emitters.append(emitter)

            let flash = Glow.makeEntity()
            flash.isEnabled = false
            entity.addChild(flash)
            flashes.append(Flash(entity: flash))
        }
    }

    private static func makeEmitter() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.02, 0.02, 0.02]
        emitter.birthLocation = .surface
        emitter.birthDirection = .normal
        emitter.speed = 1.0
        emitter.speedVariation = 0.4
        emitter.burstCount = 200
        emitter.burstCountVariation = 40

        var sparks = emitter.mainEmitter
        sparks.birthRate = 0
        sparks.lifeSpan = 1.4
        sparks.lifeSpanVariation = 0.4
        sparks.size = 0.012
        sparks.sizeVariation = 0.004
        sparks.sizeMultiplierAtEndOfLifespan = 0.1
        sparks.stretchFactor = 4                // streaks of light, not dots
        sparks.dampingFactor = 2.2              // sparks slow as they spread
        sparks.acceleration = [0, -0.35, 0]     // and droop gently
        sparks.opacityCurve = .quickFadeInOut
        sparks.blendMode = .additive
        sparks.isLightingEnabled = false
        emitter.mainEmitter = sparks

        // Each spark sheds tiny fading glitter, leaving a trail.
        var trail = ParticleEmitterComponent.ParticleEmitter()
        trail.birthRate = 40
        trail.lifeSpan = 0.5
        trail.size = 0.004
        trail.sizeMultiplierAtEndOfLifespan = 0
        trail.opacityCurve = .linearFadeOut
        trail.blendMode = .additive
        trail.isLightingEnabled = false
        emitter.spawnedEmitter = trail
        emitter.spawnOccasion = .onUpdate
        emitter.spawnInheritsParentColor = true
        emitter.spawnVelocityFactor = 0.05

        return emitter
    }

    func update(_ c: LayerContext) {
        animateFlashes(c)

        guard c.features.beatCount != lastBeat else { return }
        let isFirstFrame = lastBeat < 0
        lastBeat = c.features.beatCount
        guard !isFirstFrame else { return }

        let slot = nextSlot
        nextSlot = (nextSlot + 1) % emitters.count
        let position = burstPosition(c.layer.placement)
        let color = c.currentColor
        let strength = min(1, max(0.25, c.drive))
        let size = Float(c.layer.size)

        let emitterEntity = emitters[slot]
        emitterEntity.position = position
        if var emitter = emitterEntity.components[ParticleEmitterComponent.self] {
            emitter.mainEmitter.color = .evolving(start: .single(.white), end: .single(color))
            emitter.burstCount = Int(80 + 320 * strength)
            emitter.speed = (0.5 + 0.7 * c.speed) * (0.7 + 0.5 * strength)
            emitter.mainEmitter.size = 0.012 * size
            emitter.burst()
            emitterEntity.components.set(emitter)
        }

        flashes[slot].entity.position = position
        flashes[slot].age = 0
        flashes[slot].color = color
        flashes[slot].strength = strength
        flashes[slot].entity.isEnabled = true
    }

    /// The flash blooms quickly, then fades as it keeps growing.
    private func animateFlashes(_ c: LayerContext) {
        let size = Float(c.layer.size)
        for i in flashes.indices where flashes[i].entity.isEnabled {
            flashes[i].age += c.deltaTime
            let progress = flashes[i].age / Self.flashDuration
            if progress >= 1 {
                flashes[i].entity.isEnabled = false
                continue
            }
            let bloom = 1 - pow(1 - progress, 3)
            let diameter = size * (0.15 + 0.85 * bloom) * (0.4 + 0.5 * flashes[i].strength)
            flashes[i].entity.scale = SIMD3(repeating: diameter)
            let fade = pow(1 - progress, 2)
            // White-hot at first, settling into the note's colour.
            let tint = progress < 0.15 ? UIColor.white : flashes[i].color
            flashes[i].entity.model?.materials = [Glow.material(tint, opacity: Float(c.layer.opacity) * fade)]
        }
    }

    private func burstPosition(_ placement: Placement) -> SIMD3<Float> {
        switch placement {
        case .surround:
            let angle = Float.random(in: 0..<(2 * .pi))
            return [cos(angle) * 1.6, Float.random(in: -0.3...0.4), sin(angle) * 1.6]
        case .front, .above:
            return [Float.random(in: -0.5...0.5), Float.random(in: -0.25...0.25), Float.random(in: -0.2...0.2)]
        }
    }
}
