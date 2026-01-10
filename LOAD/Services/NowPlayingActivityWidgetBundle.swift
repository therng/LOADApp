
import WidgetKit
import SwiftUI
import ActivityKit

struct NowPlayingActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingActivityWidget()
    }
}

struct NowPlayingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            VStack {
                Text(context.attributes.title)
                Text("\(Int(context.state.elapsedTime))s")
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                }
            } compactLeading: {
                Text("▶︎")
            } compactTrailing: {
                Text("\(Int(context.state.elapsedTime))s")
            } minimal: {
                Text("▶︎")
            }
        }
    }
}
