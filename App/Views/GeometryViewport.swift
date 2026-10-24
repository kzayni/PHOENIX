import SwiftUI

/// Renders an immutable PhoenixCore geometry snapshot with equal physical-axis
/// scaling. Pan and zoom are view-only transforms and never regenerate or
/// mutate the computational geometry.
struct GeometryViewport: View {
    let geometry: SurfaceGeometry2D?
    let showsSurfacePoints: Bool
    let showsSurfaceNormals: Bool
    let resetToken: Int

    @State private var zoom = 1.0
    @State private var pan = CGSize.zero
    @GestureState private var gestureZoom = 1.0
    @GestureState private var gesturePan = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.secondary.opacity(0.06)

                if let geometry {
                    Canvas { context, size in
                        draw(geometry: geometry, in: &context, size: size)
                    }
                    .accessibilityLabel("Two-dimensional geometry viewport")
                    .accessibilityIdentifier("geometryViewport")
                } else {
                    ContentUnavailableView(
                        "No Valid Geometry",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Correct the parameters in the geometry panel.")
                    )
                }

                viewportOverlay
                    .padding(12)
            }
            .contentShape(Rectangle())
            .clipped()
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .background {
                ScrollWheelObserver { scaleFactor, location, size in
                    applyScrollZoom(
                        scaleFactor: scaleFactor,
                        around: location,
                        viewportSize: size
                    )
                }
            }
            .onChange(of: resetToken) { _, _ in
                resetCamera()
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
            }
            .padding()
        }
    }

    private var viewportOverlay: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let geometry {
                Text("\(geometry.points.count) points · \(geometry.connectivity.rawValue)")
                Text("CCW surface · outward normal to the right")
            }
            Text("Zoom \(zoom * gestureZoom, format: .number.precision(.fractionLength(2)))×")
                .accessibilityIdentifier("viewportZoomLabel")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($gesturePan) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureZoom) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoom = min(max(zoom * value, 0.1), 100.0)
            }
    }

    private func resetCamera() {
        zoom = 1.0
        pan = .zero
    }

    private func applyScrollZoom(
        scaleFactor: CGFloat,
        around location: CGPoint,
        viewportSize: CGSize
    ) {
        let oldZoom = zoom
        let newZoom = min(max(oldZoom * scaleFactor, 0.1), 100.0)
        guard newZoom != oldZoom else { return }

        // Preserve the geometry location under the pointer while zooming.
        let appliedFactor = newZoom / oldZoom
        let cameraCenter = CGPoint(
            x: viewportSize.width / 2 + pan.width,
            y: viewportSize.height / 2 + pan.height
        )
        pan.width += (location.x - cameraCenter.x) * (1 - appliedFactor)
        pan.height += (location.y - cameraCenter.y) * (1 - appliedFactor)
        zoom = newZoom
    }

    private func draw(
        geometry: SurfaceGeometry2D,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let padding = 36.0
        let availableWidth = max(size.width - 2.0 * padding, 1.0)
        let availableHeight = max(size.height - 2.0 * padding, 1.0)
        let bounds = geometry.bounds
        let geometryWidth = max(bounds.width, 1.0e-12)
        let geometryHeight = max(bounds.height, 1.0e-12)
        let fitScale = min(
            availableWidth / geometryWidth,
            availableHeight / geometryHeight
        )
        let scale = fitScale * zoom * gestureZoom
        let center = bounds.center
        let effectivePan = CGSize(
            width: pan.width + gesturePan.width,
            height: pan.height + gesturePan.height
        )

        func screenPoint(_ point: Point2D) -> CGPoint {
            CGPoint(
                x: size.width / 2.0 + effectivePan.width + (point.x - center.x) * scale,
                y: size.height / 2.0 + effectivePan.height - (point.y - center.y) * scale
            )
        }

        var contour = Path()
        contour.move(to: screenPoint(geometry.points[0]))
        for point in geometry.points.dropFirst() {
            contour.addLine(to: screenPoint(point))
        }
        if geometry.connectivity == .periodic {
            contour.closeSubpath()
        }
        context.stroke(contour, with: .color(.accentColor), lineWidth: 2.0)

        if showsSurfacePoints {
            for point in geometry.points {
                let location = screenPoint(point)
                let marker = Path(
                    ellipseIn: CGRect(
                        x: location.x - 2.5,
                        y: location.y - 2.5,
                        width: 5.0,
                        height: 5.0
                    )
                )
                context.fill(marker, with: .color(.orange))
            }
        }

        if showsSurfaceNormals {
            drawSurfaceNormals(
                for: geometry,
                into: &context,
                screenPoint: screenPoint
            )
        }
    }

    private func drawSurfaceNormals(
        for geometry: SurfaceGeometry2D,
        into context: inout GraphicsContext,
        screenPoint: (Point2D) -> CGPoint
    ) {
        let sampleStep = max(geometry.points.count / 32, 1)
        let arrowLength = 28.0
        let arrowHeadLength = 6.0
        let arrowHeadWidth = 3.5

        for index in stride(from: 0, to: geometry.points.count, by: sampleStep) {
            guard let normal = try? geometry.outwardUnitNormal(at: index) else { continue }
            let start = screenPoint(geometry.points[index])
            let screenDirection = CGVector(dx: normal.x, dy: -normal.y)
            let end = CGPoint(
                x: start.x + screenDirection.dx * arrowLength,
                y: start.y + screenDirection.dy * arrowLength
            )
            let perpendicular = CGVector(dx: -screenDirection.dy, dy: screenDirection.dx)

            var arrow = Path()
            arrow.move(to: start)
            arrow.addLine(to: end)
            arrow.move(to: end)
            arrow.addLine(to: CGPoint(
                x: end.x - screenDirection.dx * arrowHeadLength
                    + perpendicular.dx * arrowHeadWidth,
                y: end.y - screenDirection.dy * arrowHeadLength
                    + perpendicular.dy * arrowHeadWidth
            ))
            arrow.move(to: end)
            arrow.addLine(to: CGPoint(
                x: end.x - screenDirection.dx * arrowHeadLength
                    - perpendicular.dx * arrowHeadWidth,
                y: end.y - screenDirection.dy * arrowHeadLength
                    - perpendicular.dy * arrowHeadWidth
            ))
            context.stroke(arrow, with: .color(.cyan.opacity(0.9)), lineWidth: 1.2)
        }
    }
}
