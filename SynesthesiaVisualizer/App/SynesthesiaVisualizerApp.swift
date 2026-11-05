import SwiftUI

@main
struct SynesthesiaVisualizerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 980, height: 720)

        // Mixed immersion: the user still sees their room, with effects layered on top.
        ImmersiveSpace(id: AppModel.stageID) {
            ImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
