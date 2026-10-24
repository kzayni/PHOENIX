import SwiftUI

/// Presents the launch sequence, then hands control to the existing workspace.
struct LaunchExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var accumulatedElapsed: TimeInterval = 0
    @State private var activeSince: Date?
    @State private var hasSkippedIntro = false
    @State private var isShowingWorkspace = false

    var body: some View {
        Group {
            if isShowingWorkspace {
                ContentView()
                    .transition(.opacity)
            } else {
                TimelineView(
                    .animation(
                        minimumInterval: 1.0 / 60.0,
                        paused: scenePhase != .active
                    )
                ) { timeline in
                    launchFrame(elapsed: elapsed(at: timeline.date))
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(.black)
        .onAppear {
            guard activeSince == nil else { return }
            activeSince = Date()
            if reduceMotion {
                hasSkippedIntro = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            updateClock(for: phase)
        }
    }

    private func launchFrame(elapsed: TimeInterval) -> some View {
        let titleProgress = LaunchSequence.titleProgress(at: elapsed)
        let controlsProgress = LaunchSequence.controlsProgress(at: elapsed)

        return ZStack {
            SingularityView(elapsed: elapsed)
                .accessibilityIdentifier("singularityView")

            VStack(spacing: 0) {
                LiquifiedTitleView(progress: titleProgress, elapsed: elapsed)
                    .accessibilityLabel("PHOENIX")
                    .accessibilityIdentifier("phoenixTitle")
                    .accessibilityHidden(titleProgress < 0.02)

                Spacer()
            }
            .padding(.top, 64)
            .padding(.horizontal, 52)

            VStack(spacing: 0) {
                Spacer()
                landingControls
                    .opacity(controlsProgress)
                    .offset(y: 24 * (1 - controlsProgress))
                    .allowsHitTesting(controlsProgress > 0.85)
                    .accessibilityHidden(controlsProgress < 0.85)
                    .padding(.bottom, 62)
            }
            .padding(.horizontal, 52)

            VStack {
                HStack {
                    Spacer()
                    Button("Skip Intro") {
                        hasSkippedIntro = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.65))
                    .accessibilityIdentifier("skipLaunchButton")
                }
                Spacer()
            }
            .padding(24)
            .opacity(elapsed < LaunchSequence.controlsEnd ? 1 : 0)
            .allowsHitTesting(elapsed < LaunchSequence.controlsEnd)
        }
        .background(.black)
    }

    private var landingControls: some View {
        HStack(spacing: 14) {
            Button("New Project") {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isShowingWorkspace = true
                }
            }
            .buttonStyle(LaunchPrimaryButtonStyle())
            .accessibilityIdentifier("newProjectButton")

            Button("Open Project") {}
                .buttonStyle(LaunchSecondaryButtonStyle())
                .disabled(true)
                .help("Project persistence is not implemented yet.")
                .accessibilityIdentifier("openProjectButton")
        }
    }

    private func elapsed(at date: Date) -> TimeInterval {
        if hasSkippedIntro || reduceMotion {
            return LaunchSequence.controlsEnd
        }
        guard let activeSince else { return accumulatedElapsed }
        return accumulatedElapsed + max(0, date.timeIntervalSince(activeSince))
    }

    private func updateClock(for phase: ScenePhase) {
        if phase == .active {
            if activeSince == nil {
                activeSince = Date()
            }
        } else if let activeSince {
            accumulatedElapsed += max(0, Date().timeIntervalSince(activeSince))
            self.activeSince = nil
        }
    }
}

private struct LaunchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(.white.opacity(configuration.isPressed ? 0.72 : 0.94), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct LaunchSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.8))
    }
}

#Preview {
    LaunchExperienceView()
}
