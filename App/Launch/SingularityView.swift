import SwiftUI

/// A deterministic, interactive singularity scene rendered with SwiftUI Canvas.
struct SingularityView: View {
    let elapsed: TimeInterval

    @State private var cameraAzimuth = 0.0
    @GestureState private var dragTranslation = CGSize.zero

    var body: some View {
        Canvas(opaque: true, colorMode: .extendedLinear) { context, size in
            render(
                into: &context,
                size: size,
                azimuth: cameraAzimuth + elapsed * 0.055 + dragTranslation.width * 0.003
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    cameraAzimuth += value.translation.width * 0.003
                }
        )
        .accessibilityLabel("Interactive two-dimensional singularity visualization")
    }

    private func render(
        into context: inout GraphicsContext,
        size: CGSize,
        azimuth: Double
    ) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.53)
        let scale = min(size.width, size.height)
        let coreRadius = max(34, scale * 0.078)

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.012, green: 0.02, blue: 0.035),
                    Color(red: 0.002, green: 0.004, blue: 0.009),
                    .black,
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.75
            )
        )

        drawStars(into: &context, size: size, azimuth: azimuth)

        var glowContext = context
        glowContext.addFilter(.blur(radius: max(7, scale * 0.014)))
        drawDisk(
            into: &glowContext,
            size: size,
            center: center,
            coreRadius: coreRadius,
            azimuth: azimuth,
            glow: true
        )
        drawDisk(
            into: &context,
            size: size,
            center: center,
            coreRadius: coreRadius,
            azimuth: azimuth,
            glow: false
        )

        drawPhotonRing(into: &context, center: center, radius: coreRadius)

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - coreRadius,
                y: center.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [.black, .black, Color(red: 0.002, green: 0.012, blue: 0.04)]),
                center: center,
                startRadius: 0,
                endRadius: coreRadius
            )
        )

        drawVignette(into: &context, size: size, center: center)
    }

    private func drawStars(
        into context: inout GraphicsContext,
        size: CGSize,
        azimuth: Double
    ) {
        for star in SingularityScene.stars {
            let x = (star.x + azimuth * star.depth * 0.008).truncatingRemainder(dividingBy: 1.08)
            let wrappedX = x < 0 ? x + 1.08 : x
            let point = CGPoint(x: (wrappedX - 0.04) * size.width, y: star.y * size.height)
            let diameter = 0.45 + star.brightness * 1.25
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )),
                with: .color(.white.opacity(0.18 + star.brightness * 0.52))
            )
        }
    }

    private func drawDisk(
        into context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        coreRadius: CGFloat,
        azimuth: Double,
        glow: Bool
    ) {
        let maximumRadius = min(
            size.width * 0.3,
            size.height * 0.28,
            coreRadius * 3.8
        )

        for particle in SingularityScene.particles {
            let angle = particle.angle + azimuth * particle.speed
            let radius = coreRadius * 1.22 + particle.radius * (maximumRadius - coreRadius * 1.22)
            let radialFalloff = 1 - particle.radius
            let turbulence = sin(angle * 3.0 + particle.radius * 19.0 + elapsed * 0.3)
            let planarRadius = radius
                + particle.height * coreRadius * 0.08
                + turbulence * 1.2 * particle.radius
            let point = CGPoint(
                x: center.x + cos(angle) * planarRadius,
                y: center.y + sin(angle) * planarRadius
            )
            let tangent = CGVector(dx: -sin(angle), dy: cos(angle))
            let length = (3 + 17 * particle.length) * (0.35 + radialFalloff)
            var path = Path()
            path.move(to: CGPoint(
                x: point.x - tangent.dx * length * 0.5,
                y: point.y - tangent.dy * length * 0.5
            ))
            path.addLine(to: CGPoint(
                x: point.x + tangent.dx * length * 0.5,
                y: point.y + tangent.dy * length * 0.5
            ))

            let hot = pow(radialFalloff, 1.8)
            let color = Color(
                red: 0.025 + 0.9 * hot,
                green: 0.28 + 0.72 * hot,
                blue: 1
            )
            let opacity = glow ? 0.14 : 0.3 + particle.brightness * 0.62
            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                lineWidth: glow ? 3.2 : 0.5 + particle.brightness * 1.15
            )
        }
    }

    private func drawPhotonRing(
        into context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let ringRect = CGRect(
            x: center.x - radius * 1.12,
            y: center.y - radius * 1.12,
            width: radius * 2.24,
            height: radius * 2.24
        )

        var glow = context
        glow.addFilter(.blur(radius: radius * 0.22))
        glow.stroke(
            Path(ellipseIn: ringRect),
            with: .color(Color.cyan.opacity(0.72)),
            lineWidth: radius * 0.2
        )
        context.stroke(
            Path(ellipseIn: ringRect),
            with: .linearGradient(
                Gradient(colors: [.blue, .cyan, .white, .cyan, .blue]),
                startPoint: CGPoint(x: ringRect.minX, y: ringRect.minY),
                endPoint: CGPoint(x: ringRect.maxX, y: ringRect.maxY)
            ),
            lineWidth: max(1.1, radius * 0.045)
        )
    }

    private func drawVignette(
        into context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint
    ) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: .black.opacity(0.18), location: 0.72),
                    .init(color: .black.opacity(0.8), location: 1),
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.76
            )
        )
    }
}

private enum SingularityScene {
    struct Particle {
        let radius: Double
        let angle: Double
        let height: Double
        let length: Double
        let brightness: Double
        let speed: Double
    }

    struct Star {
        let x: Double
        let y: Double
        let brightness: Double
        let depth: Double
    }

    static let particles: [Particle] = {
        var random = SeededRandomNumberGenerator(seed: 0x50484F454E4958)
        return (0..<720).map { _ in
            let biasedRadius = pow(Double.random(in: 0...1, using: &random), 1.35)
            return Particle(
                radius: biasedRadius,
                angle: Double.random(in: 0...(2 * .pi), using: &random),
                height: Double.random(in: -1...1, using: &random),
                length: Double.random(in: 0...1, using: &random),
                brightness: Double.random(in: 0.15...1, using: &random),
                speed: Double.random(in: 0.82...1.18, using: &random)
            )
        }
    }()

    static let stars: [Star] = {
        var random = SeededRandomNumberGenerator(seed: 0x53494E47554C4152)
        return (0..<120).map { _ in
            Star(
                x: Double.random(in: 0...1, using: &random),
                y: Double.random(in: 0...1, using: &random),
                brightness: Double.random(in: 0...1, using: &random),
                depth: Double.random(in: 0.2...1, using: &random)
            )
        }
    }()
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
