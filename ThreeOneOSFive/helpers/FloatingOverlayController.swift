import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Hosts `FloatingMenuContentView` inside a real floating window using AVKit's "video call" style
/// Picture-in-Picture — the only mechanism a normal (non-jailbreak-tweak) app has for drawing UI
/// that survives backgrounding and floats over other apps. Apple designed this PiP style for VoIP
/// calls, not arbitrary floating UI, so this is an unofficial reuse of it: it should work, but its
/// exact on-screen behavior can only really be confirmed on a real device.
@MainActor
final class FloatingOverlayController: NSObject {
    static let shared = FloatingOverlayController()

    private var pipController: AVPictureInPictureController?
    private var pipViewController: FloatingMenuPiPViewController?
    private var sourceView: UIView?
    private var readinessTask: Task<Void, Never>?

    private override init() { super.init() }

    var isActive: Bool { pipController != nil }

    func start(game: RemoteGameSummary, store: PatchProjectStore) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        stop()

        guard let window = Self.keyWindow() else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log("FloatingOverlay: audio session activation failed: \(error)")
        }

        let pipVC = FloatingMenuPiPViewController(makeContent: { onExpansionChange in
            FloatingMenuContentView(store: store, game: game, onExpansionChange: onExpansionChange)
        })
        pipViewController = pipVC

        // Must be a real, attached, non-zero-size view for AVKit to compute the PiP window from —
        // kept nearly invisible since it's not meant to be seen itself, only the PiP surface is.
        let source = UIView(frame: CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 1, height: 1))
        source.alpha = 0.01
        source.isUserInteractionEnabled = false
        window.addSubview(source)
        sourceView = source

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: source,
            contentViewController: pipVC
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        pipController = controller

        // isPictureInPicturePossible only flips true a short beat after the content source is
        // wired up; poll briefly instead of calling startPictureInPicture() before AVKit is ready.
        readinessTask?.cancel()
        readinessTask = Task { [weak self] in
            for _ in 0..<40 {
                guard let self, let controller = self.pipController else { return }
                if controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func stop() {
        readinessTask?.cancel()
        readinessTask = nil
        pipController?.stopPictureInPicture()
        pipController = nil
        pipViewController = nil
        sourceView?.removeFromSuperview()
        sourceView = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension FloatingOverlayController: AVPictureInPictureControllerDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        log("FloatingOverlay: failed to start: \(error)")
    }
}

/// The "video call" PiP style requires this exact subclass as its content controller — a plain
/// `UIHostingController` can't be passed directly. This just embeds one as a child.
///
/// The PiP window is always exactly `preferredContentSize` on screen — it can't shrink-wrap a
/// bare icon on its own — so this keeps that size in sync with whether the content is showing
/// the bare bubble or the full panel (reported back via the `onExpansionChange` callback passed
/// into the view). The panel itself is always the landscape layout regardless of device
/// orientation, so there's just the one expanded size to track.
final class FloatingMenuPiPViewController: AVPictureInPictureVideoCallViewController {
    private var hosting: UIHostingController<FloatingMenuContentView>?

    init(makeContent: (@escaping (Bool) -> Void) -> FloatingMenuContentView) {
        super.init(nibName: nil, bundle: nil)
        let content = makeContent { [weak self] expanded in
            self?.preferredContentSize = expanded
                ? CGSize(width: 340, height: 196)
                : CGSize(width: 64, height: 64)
        }
        hosting = UIHostingController(rootView: content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let hosting else { return }
        view.backgroundColor = .clear
        hosting.view.backgroundColor = .clear
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        preferredContentSize = CGSize(width: 64, height: 64)
    }
}
