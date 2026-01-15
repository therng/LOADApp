
import ActivityKit
import Foundation

struct NowPlayingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
    }

    var title: String
}
