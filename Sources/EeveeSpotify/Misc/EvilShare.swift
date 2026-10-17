// Evil Share: appends a short evil-themed signature to Spotify links the app
// shares. Implemented as a post-processor inside CleanShareLinks so it rides
// the same pasteboard/share-sheet/deep-link interception, and never fights the
// tracking-parameter cleaner (it runs after a link has been cleaned).

import Orion
import UIKit

enum EvilShare {
    static let launchEnabled = UserDefaults.evilShareTag

    static let signatures: [String] = [
        "shared from the dark side via Evil Spotify",
        "this link has been cursed by Evil Spotify",
        "sinister audio, courtesy of Evil Spotify",
    ]

    static func tag(_ string: String) -> String {
        guard UserDefaults.evilShareTag, !string.isEmpty else { return string }

        // Only tag if the cleaned text actually contains a Spotify link.
        guard string.range(of: "open.spotify.com", options: .caseInsensitive) != nil else {
            return string
        }
        // Already tagged or user manually typed something; don't stack tags.
        if string.contains(signatures[0]) || string.contains(signatures[1]) || string.contains(signatures[2]) {
            return string
        }
        return string + "\n— " + (signatures.randomElement() ?? signatures[0])
    }

    static func tag(_ url: URL) -> URL {
        // URLs can't carry arbitrary text; only the string forms get tagged.
        // Kept for symmetry with CleanShareLinks so callers can be uniform.
        return url
    }

    static func tagValue(_ value: Any) -> Any {
        if let string = value as? String { return tag(string) }
        return value
    }
}

extension UserDefaults {
    static var evilShareTag: Bool {
        get { container.bool(forKey: "eeveeEvilShareTag") }
        set { container.set(newValue, forKey: "eeveeEvilShareTag") }
    }
}

func activateEvilShare() {
    guard EvilShare.launchEnabled else { return }
    // No hooks of its own: EvilShare.tag is invoked from CleanShareLinks'
    // string-cleaning path, which is always installed. Pure function, so just log.
    eeveeLog("[EeveeSpotify][EvilShare] Active (%.2f ms)", CFAbsoluteTimeGetCurrent())
}
