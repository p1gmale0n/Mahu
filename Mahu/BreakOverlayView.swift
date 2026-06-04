import Foundation
import SwiftUI

@MainActor
final class BreakOverlayViewModel: ObservableObject {
    @Published private(set) var remainingSeconds: TimeInterval

    private let onSkip: () -> Void

    init(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void = {}) {
        self.remainingSeconds = max(0, remainingSeconds)
        self.onSkip = onSkip
    }

    var titleText: String {
        "Время отвлечься"
    }

    var countdownText: String {
        let clampedSeconds = Int(ceil(max(0, remainingSeconds)))
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        self.remainingSeconds = max(0, remainingSeconds)
    }

    func skip() {
        onSkip()
    }
}

struct BreakOverlayView: View {
    @ObservedObject var viewModel: BreakOverlayViewModel

    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.48)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(viewModel.titleText)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.countdownText)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Button("Skip") {
                    viewModel.skip()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white.opacity(0.18))
                .foregroundStyle(.white)
            }
            .padding(40)
        }
    }
}
