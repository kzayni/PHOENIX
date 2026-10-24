// Native SwiftUI approximation of the reference SVG turbulence timeline.
import SwiftUI

/// A native interpretation of the reference's turbulent, converging SVG reveal.
struct LiquifiedTitleView: View {
    let progress: Double
    let elapsed: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let size = min(max(proxy.size.width * 0.13, 70), 150)
            let time = max(0, elapsed - LaunchSequence.titleStart)
            // Each term mirrors one independent GSAP track from the reference
            // rather than reducing the reveal to a single opacity animation.
            let turbulence = exponentialOutRemaining(time / 3.5)
            let deviceProgress = quadraticOut(time / 2.5)
            let largePieceProgress = quadraticInOut(time / 2.0)
            let pieceProgress = exponentialInOut(time - 2.0)
            let blurProgress = clamped(time - 3.0)
            let blurRadius = 7 * (1 - blurProgress)
            let gooAmount = 1 - blurProgress

            ZStack {
                liquifiedTitle(
                    size: size,
                    turbulence: turbulence,
                    largePieceProgress: largePieceProgress,
                    pieceProgress: pieceProgress
                )
                    .foregroundStyle(.cyan.opacity(0.32 * turbulence))
                    .blur(radius: 18 + 12 * turbulence)
                    .scaleEffect(1.03)

                liquifiedTitle(
                    size: size,
                    turbulence: turbulence,
                    largePieceProgress: largePieceProgress,
                    pieceProgress: pieceProgress
                )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.92), .cyan.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: blurRadius)
                    // The SVG color matrix thresholds blurred alpha into a
                    // cohesive shape. Contrast supplies the native analogue.
                    .contrast(1 + 2.4 * gooAmount)
                    .shadow(color: .cyan.opacity(0.3 + 0.3 * turbulence), radius: 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .compositingGroup()
            .scaleEffect(deviceProgress)
            .offset(y: 40 * (1 - deviceProgress))
            .opacity(progress > 0 ? 1 : 0)
        }
        .frame(height: 190)
        .allowsHitTesting(false)
    }

    private func liquifiedTitle(
        size: CGFloat,
        turbulence: Double,
        largePieceProgress: Double,
        pieceProgress: Double
    ) -> some View {
        GeometryReader { proxy in
            // Offset masked horizontal slices to approximate an SVG
            // displacement map without introducing a WebView or Metal shader.
            let sliceCount = 18
            let sliceHeight = proxy.size.height / Double(sliceCount)

            ZStack {
                ForEach(0..<sliceCount, id: \.self) { index in
                    let verticalPosition = (Double(index) + 0.5) * sliceHeight
                    let wave = (
                        sin(Double(index) * 1.73 + elapsed * 2.1) * 24
                        + cos(Double(index) * 0.61 - elapsed * 1.4) * 13
                    ) * turbulence

                    titlePieces(
                        size: size,
                        largePieceProgress: largePieceProgress,
                        pieceProgress: pieceProgress
                    )
                        .offset(x: wave)
                        .mask(alignment: .top) {
                            Rectangle()
                                .frame(height: sliceHeight + 0.75)
                                .offset(y: verticalPosition - sliceHeight * 0.5)
                        }
                }

            }
            .compositingGroup()
        }
    }

    private func titlePieces(
        size: CGFloat,
        largePieceProgress: Double,
        pieceProgress: Double
    ) -> some View {
        HStack(spacing: 0) {
            // Opposing offsets reproduce the reference logo pieces converging
            // after the initial scale-up.
            Text("PHO")
                .scaleEffect(0.2 + 0.8 * largePieceProgress)
                .offset(x: 62 * (1 - pieceProgress))

            Text("ENIX")
                .offset(x: -62 * (1 - pieceProgress))
        }
        .font(.custom("Avenir Next Condensed", fixedSize: size).weight(.heavy))
        .tracking(size * 0.018)
        .italic()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func quadraticOut(_ value: Double) -> Double {
        let value = clamped(value)
        return 1 - (1 - value) * (1 - value)
    }

    private func quadraticInOut(_ value: Double) -> Double {
        let value = clamped(value)
        return value < 0.5
            ? 2 * value * value
            : 1 - pow(-2 * value + 2, 2) / 2
    }

    private func exponentialInOut(_ value: Double) -> Double {
        let value = clamped(value)
        if value == 0 || value == 1 {
            return value
        }
        return value < 0.5
            ? pow(2, 20 * value - 10) / 2
            : (2 - pow(2, -20 * value + 10)) / 2
    }

    private func exponentialOutRemaining(_ value: Double) -> Double {
        // This returns the unresolved fraction, so it decays from one to zero.
        let value = clamped(value)
        return value == 1 ? 0 : pow(2, -10 * value)
    }
}
