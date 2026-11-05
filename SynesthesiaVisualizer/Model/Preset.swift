import SwiftUI

/// A colour stored as plain numbers so presets can be saved as JSON.
struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: Color) {
        self.init(uiColor: UIColor(color))
    }

    init(hue: Double, saturation: Double = 0.85, brightness: Double = 1) {
        self.init(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }

    init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255,
                  g: Double((hex >> 8) & 0xFF) / 255,
                  b: Double(hex & 0xFF) / 255)
    }

    init(uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        func clamp(_ v: CGFloat) -> Double { Double(min(1, max(0, v))) }
        self.init(r: clamp(r), g: clamp(g), b: clamp(b), a: clamp(a))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
}

enum EffectKind: String, Codable, CaseIterable, Identifiable {
    case orbs, ribbon, bursts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .orbs: "Floating orbs"
        case .ribbon: "Flowing ribbon"
        case .bursts: "Bursts on the beat"
        }
    }

    var systemImage: String {
        switch self {
        case .orbs: "circle.hexagongrid.fill"
        case .ribbon: "scribble.variable"
        case .bursts: "sparkles"
        }
    }
}

enum ColorSource: String, Codable, CaseIterable, Identifiable {
    case notes, single

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notes: "Colour of the notes"
        case .single: "One colour"
        }
    }
}

enum Reaction: String, Codable, CaseIterable, Identifiable {
    case volume, bass, mid, treble, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .volume: "Overall volume"
        case .bass: "Low sounds (bass)"
        case .mid: "Middle sounds"
        case .treble: "High sounds (treble)"
        case .none: "Nothing (steady)"
        }
    }
}

enum Placement: String, Codable, CaseIterable, Identifiable {
    case front, surround, above

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: "In front of me"
        case .surround: "All around me"
        case .above: "Above me"
        }
    }

    /// Where the layer sits, in metres, relative to the floor below the user.
    var anchor: SIMD3<Float> {
        switch self {
        case .front: [0, 1.3, -1.5]
        case .surround: [0, 1.3, 0]
        case .above: [0, 2.3, -1.0]
        }
    }
}

/// One visual effect. A preset is a stack of these.
struct EffectLayer: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: EffectKind
    var colorSource: ColorSource = .notes
    var singleColor = RGBA(hue: 0.6)
    var size: Double = 1
    var speed: Double = 1
    var reaction: Reaction = .volume
    var sensitivity: Double = 1
    var placement: Placement = .front
    var opacity: Double = 0.85
    var isVisible = true
}

/// Everything needed to recreate one person's experience of one piece of music.
struct Preset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var trackID: String?
    var trackTitle: String?
    var noteColors: [RGBA]
    var layers: [EffectLayer]

    static let noteNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    static let rainbowColors: [RGBA] = (0..<12).map { RGBA(hue: Double($0) / 12) }

    /// Approximate colours from Scriabin's "clavier à lumières" (historical curiosity, not a standard).
    static let scriabinColors: [RGBA] = ([
        0xFF0000, 0x8F00FF, 0xFFFF00, 0xB7468B, 0x87CEEB, 0x8B0000,
        0x3D7BFF, 0xFF8C00, 0xBB75FC, 0x33CC33, 0xA9A9C9, 0x8EC9FF,
    ] as [UInt32]).map { RGBA(hex: $0) }

    static var starter: Preset {
        Preset(
            name: "My preset",
            noteColors: rainbowColors,
            layers: [
                EffectLayer(name: "Orbs", kind: .orbs),
                EffectLayer(name: "Ribbon", kind: .ribbon, reaction: .treble),
            ]
        )
    }
}
