import Foundation

struct PlaybackExtrasOptions: Codable, Equatable {
    var sleepTimerMinutes = 30
    var keepScreenOn = false
}

extension UserDefaults {
    @UserDefault(key: "everettPlaybackExtrasOptions", defaultValue: PlaybackExtrasOptions())
    static var playbackExtrasOptions
}

extension UserDefaults {
    static var blockUpdatePrompts: Bool {
        get { container.bool(forKey: "everettBlockUpdatePrompts") }
        set { container.set(newValue, forKey: "everettBlockUpdatePrompts") }
    }
}
