import AppKit
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
        let safeSeconds = AppConfig.safeDisplayWholeSeconds(remainingSeconds)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02lld:%02lld", minutes, seconds)
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        self.remainingSeconds = max(0, remainingSeconds)
    }

    func skip() {
        onSkip()
    }
}

enum BreakOverlayAccessibilityID {
    static let title = "break-overlay-title"
    static let countdown = "break-overlay-countdown"
    static let skipButton = "break-overlay-skip"
}

struct BreakOverlayView: View {
    @ObservedObject var viewModel: BreakOverlayViewModel
    let backgroundImage: NSImage?

    init(
        viewModel: BreakOverlayViewModel,
        backgroundImageLoader: BreakOverlayBackgroundImageLoader = .main
    ) {
        self.viewModel = viewModel
        self.backgroundImage = backgroundImageLoader.loadBackgroundImage()
    }

    @ViewBuilder
    var backgroundView: some View {
        if let backgroundImage {
            Image(nsImage: backgroundImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.black
        }
    }

    var foregroundContent: some View {
        VStack(spacing: 24) {
            Text(viewModel.titleText)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .accessibilityIdentifier(BreakOverlayAccessibilityID.title)

            Text(viewModel.countdownText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .accessibilityIdentifier(BreakOverlayAccessibilityID.countdown)

            Button("Skip") {
                viewModel.skip()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.white.opacity(0.18))
            .foregroundStyle(.white)
            .accessibilityIdentifier(BreakOverlayAccessibilityID.skipButton)
        }
    }

    var body: some View {
        ZStack {
            backgroundView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            Color.black.opacity(0.48)

            foregroundContent
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .ignoresSafeArea()
    }
}

struct BreakOverlayBackgroundImageLoader {
    private let loadImage: () -> NSImage?

    static let main = BreakOverlayBackgroundImageLoader(bundle: .main)

    init(bundle: Bundle) {
        self.loadImage = {
            guard let resourceURL = bundle.url(forResource: "background", withExtension: "png") else {
                return nil
            }

            return NSImage(contentsOf: resourceURL)
        }
    }

    init(loadBackgroundImage: @escaping () -> NSImage?) {
        self.loadImage = loadBackgroundImage
    }

    func loadBackgroundImage() -> NSImage? {
        loadImage()
    }
}
