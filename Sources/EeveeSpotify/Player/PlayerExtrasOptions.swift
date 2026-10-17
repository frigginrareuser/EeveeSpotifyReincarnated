import Foundation

enum PlayerDoubleTap: String, Codable, CaseIterable {
    case off, seek, skip, save
}

struct PlayerExtrasOptions: Codable, Equatable {
    var doubleTap = PlayerDoubleTap.off
    var threeZones = true
    var haptics = false
}

extension UserDefaults {
    @UserDefault(key: "eeveePlayerExtrasOptions", defaultValue: PlayerExtrasOptions())
    static var playerExtrasOptions
}
