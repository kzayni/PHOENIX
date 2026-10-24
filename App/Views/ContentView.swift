//
//  ContentView.swift
//  PHOENIX
//
//  Created by Mohamad Karim ZAYNI on 2026-10-20.
//

import SwiftUI

/// Defines the geometry workspace without embedding computational algorithms.
struct ContentView: View {
    @StateObject private var model = GeometryViewModel()

    var body: some View {
        NavigationSplitView {
            Form {
                Section("Geometry") {
                    Picker("Type", selection: $model.selection) {
                        ForEach(GeometrySelection.allCases) { selection in
                            Text(selection.rawValue).tag(selection)
                        }
                    }
                    .accessibilityIdentifier("geometryTypePicker")
                }

                switch model.selection {
                case .nacaFourDigit:
                    nacaFourDigitControls
                case .nacaFiveDigit:
                    nacaFiveDigitControls
                case .circularCylinder:
                    cylinderControls
                }

                Section("Display") {
                    Toggle("Show surface points", isOn: $model.showsSurfacePoints)
                    Toggle("Show surface normals", isOn: $model.showsSurfaceNormals)
                        .accessibilityIdentifier("showSurfaceNormalsToggle")
                    Button("Fit to View", systemImage: "arrow.up.left.and.arrow.down.right") {
                        model.resetViewport()
                    }
                    .accessibilityIdentifier("fitToViewButton")
                }

                Section {
                    Button("Generate / Update", systemImage: "arrow.clockwise") {
                        model.regenerate()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("generateGeometryButton")
                }

                if let errorMessage = model.errorMessage {
                    Section("Input Error") {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("geometryErrorMessage")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Geometry")
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 400)
        } detail: {
            GeometryViewport(
                geometry: model.geometry,
                showsSurfacePoints: model.showsSurfacePoints,
                showsSurfaceNormals: model.showsSurfaceNormals,
                resetToken: model.viewportResetToken
            )
            .navigationTitle(model.selection.rawValue)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var nacaFourDigitControls: some View {
        Section("NACA Four-Digit Airfoil") {
            TextField("Designation", text: $model.nacaDesignation)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("nacaDesignationField")
            TextField(
                "Chord length",
                value: $model.nacaChordLength,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("nacaChordField")
            HStack {
                TextField("Surface points", value: $model.nacaPointCount, format: .number)
                    .accessibilityIdentifier("nacaPointCountField")
                Stepper("", value: $model.nacaPointCount, in: 8...4096)
                    .labelsHidden()
            }
            Picker("Point distribution", selection: $model.nacaPointDistribution) {
                ForEach(PointDistribution.allCases) { distribution in
                    Text(distribution.displayName).tag(distribution)
                }
            }
            .accessibilityIdentifier("nacaPointDistributionPicker")
            Toggle(
                "Sharp trailing edge",
                isOn: Binding(
                    get: { model.nacaTrailingEdge == .closed },
                    set: { isSharp in
                        model.nacaTrailingEdge = isSharp ? .closed : .open
                    }
                )
            )
            .help(
                model.nacaTrailingEdge == .closed
                    ? "Zero-thickness sharp trailing edge"
                    : "Finite-thickness blunt trailing edge"
            )
            .accessibilityIdentifier("nacaSharpTrailingEdgeToggle")
        }
    }

    private var nacaFiveDigitControls: some View {
        Section("NACA Five-Digit Airfoil") {
            TextField("Designation", text: $model.naca5Designation)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("naca5DesignationField")
            TextField(
                "Chord length",
                value: $model.naca5ChordLength,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("naca5ChordField")
            HStack {
                TextField("Surface points", value: $model.naca5PointCount, format: .number)
                    .accessibilityIdentifier("naca5PointCountField")
                Stepper("", value: $model.naca5PointCount, in: 8...4096)
                    .labelsHidden()
            }
            Picker("Point distribution", selection: $model.naca5PointDistribution) {
                ForEach(PointDistribution.allCases) { distribution in
                    Text(distribution.displayName).tag(distribution)
                }
            }
            .accessibilityIdentifier("naca5PointDistributionPicker")
            Toggle(
                "Sharp trailing edge",
                isOn: Binding(
                    get: { model.naca5TrailingEdge == .closed },
                    set: { isSharp in
                        model.naca5TrailingEdge = isSharp ? .closed : .open
                    }
                )
            )
            .help(
                model.naca5TrailingEdge == .closed
                    ? "Zero-thickness sharp trailing edge"
                    : "Finite-thickness blunt trailing edge"
            )
            .accessibilityIdentifier("naca5SharpTrailingEdgeToggle")
        }
    }

    private var cylinderControls: some View {
        Section("Circular Cylinder") {
            TextField(
                "Radius",
                value: $model.cylinderRadius,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("cylinderRadiusField")
            TextField(
                "Center X",
                value: $model.cylinderCenterX,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("cylinderCenterXField")
            TextField(
                "Center Y",
                value: $model.cylinderCenterY,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("cylinderCenterYField")
            HStack {
                TextField("Surface points", value: $model.cylinderPointCount, format: .number)
                    .accessibilityIdentifier("cylinderPointCountField")
                Stepper("", value: $model.cylinderPointCount, in: 3...4096)
                    .labelsHidden()
            }
            TextField(
                "Starting angle (degrees)",
                value: $model.cylinderStartingAngleDegrees,
                format: .number.precision(.fractionLength(0...6))
            )
            .accessibilityIdentifier("cylinderStartingAngleField")
        }
    }
}

#Preview {
    ContentView()
}
