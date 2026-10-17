// Evil Spotify launch greeting: shows one of several evil-themed meme
// messages shortly after the app comes up. Popups themselves are the tweak's
// own dialogs (never blocked by UpsellPopupBlocker, which allow-lists the
// "Evil Spotify" title); CMP marketing popups stay suppressed separately.

import Orion
import UIKit

// MARK: - Evil greeting popup
// Shown shortly after launch when evilGreetings is on. Rotates through a pool
// of meme/greeting lines so repeat launches don't feel stale.

enum EvilGreetings {
    static let launchEnabled = UserDefaults.evilGreetings

    // Localized at display time via `<key>`.localized lookups on keys below.
    static let keys: [String] = [
        "evil_greeting_welcome",
        "evil_greeting_deals",
        "evil_greeting_soul",
        "evil_greeting_skips",
        "evil_greeting_lyrics",
        "evil_greeting_battery",
    ]

    static func present(delayed: Bool = true) {
        guard UserDefaults.evilGreetings else { return }
        let key = keys.randomElement() ?? keys[0]
        PopUpHelper.showPopUp(
            delayed: delayed,
            message: key.localized,
            buttonText: "evil_greeting_ack".localized
        )
    }
}

extension UserDefaults {
    static var evilGreetings: Bool {
        get { container.bool(forKey: "eeveeEvilGreetings") }
        set { container.set(newValue, forKey: "eeveeEvilGreetings") }
    }
}

func activateEvilGreetings() {
    guard EvilGreetings.launchEnabled else { return }
    // Wait until the UI is up so the Encore presenter has a window to attach to.
    DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
        EvilGreetings.present(delayed: false)
    }
    eeveeLog("[EeveeSpotify][Evil] Greetings armed (%.2f ms)", CFAbsoluteTimeGetCurrent())
}
