import Orion
import EeveeSpotifyC
import UIKit
import ObjectiveC.runtime

// MARK: - Sleep Timer + Keep Screen On
// Two always-available QoL tools. Both are pure client-side: the sleep timer
// pauses playback through Spotify's own playback controller (or the player UI's
// play button when the controller isn't up yet), and keep-screen-on only drives
// UIApplication.isIdleTimerDisabled while the app is foregrounded.

struct SleepTimerCaptureGroup: HookGroup {}

@objc private protocol EvilSleepPlayback {
    func setPaused(_ paused: Bool)
    var isPaused: Bool { get }
}

final class SleepTimer: NSObject {
    override private init() { super.init() }

    static let changedNotification = Notification.Name("EvilSleepTimerChanged")
    static weak var playback: NSObject?
    private static var timer: Timer?
    private static var endsAt: Date?

    static var remaining: TimeInterval? {
        guard let endsAt else { return nil }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    static var isActive: Bool { timer != nil || endsAt != nil }

    static let presets: [Int] = [5, 10, 15, 30, 45, 60, 90, 120]

    // MARK: Control

    static func start(minutes: Int) {
        stop(notify: false)
        guard minutes > 0 else { return }

        var options = UserDefaults.playbackExtrasOptions
        if options.sleepTimerMinutes != minutes {
            options.sleepTimerMinutes = minutes
            UserDefaults.playbackExtrasOptions = options
        }

        endsAt = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes) * 60, repeats: false) { _ in
            fire()
        }
        eeveeLog("[EeveeSpotify][SleepTimer] Started: %d min", minutes)
        NotificationCenter.default.post(name: changedNotification, object: nil)
    }

    static func stop(notify: Bool = true) {
        timer?.invalidate()
        timer = nil
        endsAt = nil
        if notify {
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    static func fire() {
        timer = nil
        endsAt = nil
        pausePlayback()
        eeveeLog("[EeveeSpotify][SleepTimer] Fired: pausing playback")
        DispatchQueue.main.async {
            PopUpHelper.showPopUp(
                message: "sleep_timer_expired".localized,
                buttonText: "ok".localized
            )
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    private static func pausePlayback() {
        if let object = playback {
            let player = unsafeBitCast(object, to: EvilSleepPlayback.self)
            if !player.isPaused {
                player.setPaused(true)
                return
            }
            // Already paused; nothing to do.
            return
        }

        // Fallback: the mini player's play button also toggles playback.
        var button: UIView?
        for window in UIApplication.shared.windows {
            if let found = window.eeveeFirst(UIView.self, where: { $0.accessibilityIdentifier == "SPTNowPlayingPlayButton" }) {
                button = found
                break
            }
        }
        if let button {
            EeveeFireTap(button)
        } else {
            eeveeLog("[EeveeSpotify][SleepTimer] No playback controller or play button; paused not enforced")
        }
    }
}

class SleepTimerPlaybackHook: ClassHook<NSObject> {
    typealias Group = SleepTimerCaptureGroup
    static let targetName = "SPTNowPlayingPlaybackControllerImplementation"

    func initWithPlayer(_ player: AnyObject?, testManager: AnyObject?, inStreamClient: AnyObject?) -> Target {
        let controller = orig.initWithPlayer(player, testManager: testManager, inStreamClient: inStreamClient)
        SleepTimer.playback = controller
        return controller
    }
}

// MARK: - Keep Screen On

// An objc Hallo object so NotificationCenter can deliver @objc selector
// callbacks into an otherwise-Swift singleton.
final class KeepScreenAwake: NSObject {
    static let changedNotification = Notification.Name("EvilKeepScreenAwakeChanged")
    private static var observersInstalled = false

    static var isEnabled: Bool {
        UserDefaults.playbackExtrasOptions.keepScreenOn
    }

    /// Applies the setting. Call after any option change (works live, no restart).
    static func activate() {
        installObservers()

        if isEnabled {
            addObserver(UIApplication.didBecomeActiveNotification, selector: #selector(appForegrounded))
            addObserver(UIApplication.didEnterBackgroundNotification, selector: #selector(appBackgrounded))
        } else {
            removeAllObservers()
        }
        apply()
        NotificationCenter.default.post(name: changedNotification, object: nil)
    }

    static fileprivate func apply() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = isEnabled && UIApplication.shared.applicationState != .background
        }
    }

    private static func addObserver(_ name: Notification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }

    private static func removeAllObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private static func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        addObserver(UIApplication.didBecomeActiveNotification, selector: #selector(appForegrounded))
        addObserver(UIApplication.didEnterBackgroundNotification, selector: #selector(appBackgrounded))
    }

    @objc private static func appForegrounded() { apply() }
    @objc private static func appBackgrounded() {
        // A dangling "keep awake" flag would keep the screen on for every other
        // iOS app too, so drop it the moment we leave the foreground.
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

func activatePlaybackTools() {
    let options = UserDefaults.playbackExtrasOptions
    let start = CFAbsoluteTimeGetCurrent()

    // The playback-capture hook only installs when the controller exposes the
    // init selector this build of Spotify is expected to have.
    if let cls = NSClassFromString(SleepTimerPlaybackHook.targetName),
       class_getInstanceMethod(cls, Selector(("initWithPlayer:testManager:inStreamClient:"))) != nil {
        SleepTimerCaptureGroup().activate()
    } else {
        eeveeLog("[EeveeSpotify][SleepTimer] Playback controller hook unavailable (fallback: UI play button)")
    }

    if SleepTimer.isActive {
        eeveeLog("[EeveeSpotify][SleepTimer] Restoring active sleep timer after re-init")
    }

    if options.keepScreenOn {
        KeepScreenAwake.activate()
        eeveeLog("[EeveeSpotify][KeepAwake] Active (%.2f ms)", (CFAbsoluteTimeGetCurrent() - start) * 1000)
    }

    eeveeLog("[EeveeSpotify][PlaybackTools] Ready (timer %d min standby, keepAwake %@)",
             options.sleepTimerMinutes, options.keepScreenOn ? "on" : "off")
}
