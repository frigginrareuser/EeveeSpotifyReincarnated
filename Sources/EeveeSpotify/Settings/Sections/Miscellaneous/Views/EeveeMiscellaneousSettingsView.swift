import SwiftUI
import UIKit

struct EeveeMiscellaneousSettingsView: View {
    @State private var blockTelemetry = UserDefaults.blockTelemetry
    @State private var cleanShareLinks = UserDefaults.cleanShareLinks
    @State private var blockRatingPrompts = UserDefaults.blockRatingPrompts
    @State private var blockUpdatePrompts = UserDefaults.blockUpdatePrompts
    @State private var evilGreetings = UserDefaults.evilGreetings
    @State private var evilShareTag = UserDefaults.evilShareTag

    var body: some View {
        List {
            Section(footer: Text("evil_greetings_footer".localized)) {
                Toggle("evil_greetings".localized, isOn: $evilGreetings)
            }

            Section(footer: Text("evil_share_tag_footer".localized)) {
                Toggle("evil_share_tag".localized, isOn: $evilShareTag)
            }

            Section(footer: Text("block_telemetry_footer".localized)) {
                Toggle("block_telemetry".localized, isOn: $blockTelemetry)
            }

            Section(footer: Text("block_rating_prompts_footer".localized)) {
                Toggle("block_rating_prompts".localized, isOn: $blockRatingPrompts)
            }

            Section(footer: Text("block_update_prompts_footer".localized)) {
                Toggle("block_update_prompts".localized, isOn: $blockUpdatePrompts)
            }

            Section(footer: Text("clean_share_links_description".localized)) {
                Toggle("clean_share_links".localized, isOn: $cleanShareLinks)
            }

            RestartSection(visible: blockTelemetry != TelemetryBlock.launchEnabled || blockRatingPrompts != RatingPromptBlock.launchEnabled || blockUpdatePrompts != UpdatePromptBlocker.launchEnabled || evilGreetings != EvilGreetings.launchEnabled || evilShareTag != EvilShare.launchEnabled)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: blockTelemetry) { UserDefaults.blockTelemetry = $0 }
        .onChange(of: cleanShareLinks) { UserDefaults.cleanShareLinks = $0 }
        .onChange(of: blockRatingPrompts) { UserDefaults.blockRatingPrompts = $0 }
        .onChange(of: blockUpdatePrompts) { UserDefaults.blockUpdatePrompts = $0 }
        .onChange(of: evilGreetings) { UserDefaults.evilGreetings = $0 }
        .onChange(of: evilShareTag) { UserDefaults.evilShareTag = $0 }
    }
}
