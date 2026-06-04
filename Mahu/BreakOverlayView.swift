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

struct BreakOverlayView: View {
    @ObservedObject var viewModel: BreakOverlayViewModel
    private let backgroundImage: NSImage?

    init(
        viewModel: BreakOverlayViewModel,
        backgroundImageLoader: BreakOverlayBackgroundImageLoader = .main
    ) {
        self.viewModel = viewModel
        self.backgroundImage = backgroundImageLoader.loadBackgroundImage()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let backgroundImage {
                    Image(nsImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Color.black
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }

                Color.black.opacity(0.48)
                    .frame(width: geometry.size.width, height: geometry.size.height)

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
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
