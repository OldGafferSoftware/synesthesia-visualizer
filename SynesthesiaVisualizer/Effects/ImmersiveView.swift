import SwiftUI
import RealityKit

/// The effects, floating in the user's real room.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var stage = EffectStage()

    var body: some View {
        RealityView { content in
            content.add(stage.root)
            let stage = stage
            let model = model
            stage.updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                MainActor.assumeIsolated {
                    stage.update(
                        deltaTime: Float(event.deltaTime),
                        features: model.audio.features,
                        preset: model.preset
                    )
                }
            }
        }
        .onAppear { model.isStageOpen = true }
        .onDisappear { model.isStageOpen = false }
    }
}
