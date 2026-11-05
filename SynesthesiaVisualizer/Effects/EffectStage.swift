import RealityKit
import UIKit

/// Everything a layer needs to draw one frame.
struct LayerContext {
    let time: Float
    let deltaTime: Float
    let features: AudioFeatures
    let layer: EffectLayer
    let noteColors: [RGBA]

    /// Movement speed: the layer's own setting, scaled by the music's tempo if the layer follows it.
    var speed: Float { Float(layer.speed) * (layer.followsTempo ? features.tempoFactor : 1) }

    /// How strongly the layer should react right now (0...~2).
    var drive: Float { features.value(for: layer.reaction) * Float(layer.sensitivity) }

    func color(forPitchClass pitchClass: Int) -> UIColor {
        switch layer.colorSource {
        case .single: layer.singleColor.uiColor
        case .notes: noteColors.isEmpty ? .white : noteColors[pitchClass % noteColors.count].uiColor
        }
    }

    /// Roughly where the viewer's head is, in the layer's own coordinates.
    var viewer: SIMD3<Float> { SIMD3<Float>(0, 1.5, 0) - layer.placement.anchor }

    /// The colour of the note sounding most strongly right now.
    var currentColor: UIColor { color(forPitchClass: features.dominantPitchClass) }
}

@MainActor
protocol LayerNode: AnyObject {
    var entity: Entity { get }
    var kind: EffectKind { get }
    func update(_ context: LayerContext)
}

@MainActor
func glowMaterial(_ color: UIColor, opacity: Float) -> UnlitMaterial {
    var material = UnlitMaterial(color: color)
    material.blending = .transparent(opacity: .init(scale: min(1, max(0, opacity))))
    return material
}

/// Holds one RealityKit entity per layer in the current preset and keeps them in sync.
@MainActor
final class EffectStage {
    let root = Entity()
    var updateSubscription: EventSubscription?

    private var nodes: [UUID: LayerNode] = [:]
    private var time: Float = 0

    func update(deltaTime: Float, features: AudioFeatures, preset: Preset) {
        time += deltaTime

        let wanted = Set(preset.layers.map(\.id))
        for (id, node) in nodes where !wanted.contains(id) {
            node.entity.removeFromParent()
            nodes[id] = nil
        }

        for layer in preset.layers {
            let node: LayerNode
            if let existing = nodes[layer.id], existing.kind == layer.kind {
                node = existing
            } else {
                nodes[layer.id]?.entity.removeFromParent()
                node = Self.makeNode(for: layer.kind)
                root.addChild(node.entity)
                nodes[layer.id] = node
            }

            node.entity.isEnabled = layer.isVisible
            node.entity.position = layer.placement.anchor
            guard layer.isVisible else { continue }
            node.update(LayerContext(
                time: time,
                deltaTime: deltaTime,
                features: features,
                layer: layer,
                noteColors: preset.noteColors
            ))
        }
    }

    private static func makeNode(for kind: EffectKind) -> LayerNode {
        switch kind {
        case .orbs: return OrbsNode()
        case .ribbon: return RibbonNode()
        case .bursts: return BurstsNode()
        }
    }
}
