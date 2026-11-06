import SwiftUI

/// Names, notices and contact details shown on the splash page and the Info sheet.
enum AppInfo {
    static let name = "Synesthesia Visualizer"
    static let copyright = "© 2026 David Hodge, Old Gaffer Software. All rights reserved."
    static let email = "info@oldgaffersoftware.com"
    static let emailURL = URL(string: "mailto:\(email)?subject=Synesthesia%20Visualizer")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    static let purpose = """
        Synesthesia Visualizer helps people with music-colour synesthesia show others what they see \
        when they hear music: build the effects, save them with the music, and record what you see.
        """

    static let notMedicalAdvice = """
        This app is for illustration and communication only. It is not a medical device and does not \
        provide medical advice, diagnosis or treatment, and nothing in it should be relied on as such. \
        Talk to a qualified health professional about any medical concern.
        """

    static let flashingLights = """
        The effects include flashing and moving light. If you have photosensitive epilepsy or are \
        sensitive to flashing lights, talk to your doctor before use, and stop if you feel unwell.
        """

    static let privacy = "Everything you create stays on your device. The app has no accounts and sends no data."

    static let musicCredits = """
        Built-in music: the compositions are in the public domain, and the performances were \
        made for this app by Old Gaffer Software, some using the FluidR3 GM soundfont \
        (© Frank Wen, MIT licence). Music you import remains your responsibility.
        """

    static let trademarks = "Apple Vision Pro and visionOS are trademarks of Apple Inc."
}

/// Shown at launch (the user must tap Continue) and from the Info button.
struct AboutView: View {
    enum Mode { case splash, info }

    let mode: Mode
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380)
                    .accessibilityLabel(AppInfo.name)

                Text(AppInfo.purpose)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 640)

                VStack(alignment: .leading, spacing: 20) {
                    notice("Not medical advice", systemImage: "stethoscope", text: AppInfo.notMedicalAdvice)
                    notice("Flashing lights", systemImage: "exclamationmark.triangle", text: AppInfo.flashingLights)
                    notice("Privacy", systemImage: "lock", text: AppInfo.privacy)
                    notice("Music", systemImage: "music.note", text: AppInfo.musicCredits)
                }
                .frame(maxWidth: 640)
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))

                Link(destination: AppInfo.emailURL) {
                    Label("Contact us: \(AppInfo.email)", systemImage: "envelope")
                }

                VStack(spacing: 6) {
                    Text(AppInfo.copyright)
                    Text("Version \(AppInfo.version)")
                    Text(AppInfo.trademarks)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button(mode == .splash ? "I understand, continue" : "Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private func notice(_ title: String, systemImage: String, text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage).font(.title3)
        }
    }
}
