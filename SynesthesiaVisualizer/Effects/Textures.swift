import RealityKit
import Metal
import UIKit

/// Builds small greyscale textures in code, used as both colour and transparency so effects have soft edges.
enum TextureMaker {
    @MainActor
    static func make(width: Int, height: Int, repeatsHorizontally: Bool,
                     value: (_ u: Float, _ v: Float) -> Float) -> MaterialParameters.Texture? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let v = (Float(y) + 0.5) / Float(height)
            for x in 0..<width {
                let u = (Float(x) + 0.5) / Float(width)
                let byte = UInt8(max(0, min(1, value(u, v))) * 255)
                let i = (y * width + x) * 4
                pixels[i] = byte
                pixels[i + 1] = byte
                pixels[i + 2] = byte
                pixels[i + 3] = byte
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let resource = try? TextureResource(image: image, options: .init(semantic: .raw))
        else { return nil }

        let sampler = MTLSamplerDescriptor()
        sampler.sAddressMode = repeatsHorizontally ? .repeat : .clampToEdge
        sampler.tAddressMode = .clampToEdge
        sampler.minFilter = .linear
        sampler.magFilter = .linear
        return MaterialParameters.Texture(resource, sampler: .init(sampler))
    }
}

/// A soft-edged, streaky texture that repeats along a strand, so the light appears to flow.
enum FlowTexture {
    @MainActor
    static func make() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 256, height: 32, repeatsHorizontally: true) { u, v in
            let edge = pow(sin(Float.pi * v), 1.5)
            // Whole-number frequencies along u keep the pattern seamless when it repeats.
            let streaks = 0.5
                + 0.25 * sin(2 * .pi * (3 * u + 0.7 * v))
                + 0.15 * sin(2 * .pi * (7 * u - 1.3 * v + 0.3))
                + 0.10 * sin(2 * .pi * (13 * u + 2.1 * v))
            return edge * (0.4 + 0.6 * streaks)
        }
    }
}

/// A round glow: a bright centre that fades smoothly to nothing at the edge.
enum GlowTexture {
    @MainActor
    static func make() -> MaterialParameters.Texture? {
        TextureMaker.make(width: 128, height: 128, repeatsHorizontally: false) { u, v in
            let dx = (u - 0.5) * 2, dy = (v - 0.5) * 2
            let r2 = dx * dx + dy * dy
            guard r2 < 1 else { return 0 }
            let halo = 0.75 * exp(-5 * r2)
            let core = 0.5 * exp(-25 * r2)
            return min(1, halo + core) * (1 - r2)
        }
    }
}
