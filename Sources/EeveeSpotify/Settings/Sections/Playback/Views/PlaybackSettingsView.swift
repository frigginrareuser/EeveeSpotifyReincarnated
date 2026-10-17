import SwiftUI
import UIKit
import Combine

struct PlaybackSettingsView: View {
    // Sleep timer state lives outside UserDefaults (a running countdown doesn't
    // belong in persisted options), so it mirrors the singleton via notifications.
    @State private var selectedMinutes = UserDefaults.playbackExtrasOptions.sleepTimerMinutes
    @State private var remaining: TimeInterval? = SleepTimer.remaining
    @State private var keepScreenOn = UserDefaults.playbackExtrasOptions.keepScreenOn

    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]  // [hour, minute]
        formatter.unitsStyle = .full
        return formatter
    }()

    private var availabilityStatus: String? {
        guard let remaining, remaining > 0 else { return nil }
        return "sleep_timer_active".localizeWithFormat(Self.formatter.string(from: remaining) ?? "0:00")
    }

    var body: some View {
        List {
            Section(
                header: Text("sleep_timer".localized),
                footer: Text("sleep_timer_footer".localized)
            ) {
                Picker(selection: $selectedMinutes, label: SettingsLabel(title: "sleep_timer_duration".localized, icon: "moon.zzz.fill", color: Color(hex: "#5E5CE6"))) {
                    Text("sleep_timer_duration_off".localized).tag(0)
                    ForEach(SleepTimer.presets, id: \.self) { minutes in
                        Text("sleep_timer_minutes".localizeWithFormat(minutes)).tag(minutes)
                    }
                }

                if let status = availabilityStatus {
                    HStack {
                        SettingsLabel(title: status, icon: "moon.zzz.fill", color: Color(hex: "#30B0C7"))
                    }
                }

                if SleepTimer.isActive {
                    Button(action: { SleepTimer.stop() }) {
                        SettingsLabel(title: "sleep_timer_cancel".localized, icon: "stop.fill", color: .red)
                    }
                }
            }

            Section(
                header: Text("keep_screen_on".localized),
                footer: Text("keep_screen_on_footer".localized)
            ) {
                SettingsToggle(
                    title: "keep_screen_on".localized,
                    subtitle: "keep_screen_on_subtitle".localized,
                    icon: "iphone.and.arrow.forward",
                    color: Color(hex: "#FFD60A"),
                    isOn: $keepScreenOn
                )
            }

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: selectedMinutes) { minutes in
            guard minutes > 0 else {
                if SleepTimer.isActive { SleepTimer.stop() }
                return
            }
            SleepTimer.start(minutes: minutes)
        }
        .onChange(of: keepScreenOn) {
            var options = UserDefaults.playbackExtrasOptions
            options.keepScreenOn = $0
            UserDefaults.playbackExtrasOptions = options
            KeepScreenAwake.activate()
        }
        .onReceive(NotificationCenter.default.publisher(for: SleepTimer.changedNotification)) { _ in
            selectedMinutes = SleepTimer.isActive ? selectedMinutes : 0
            remaining = SleepTimer.remaining
        }
        .onReceive(timerPublisher) { _ in
            remaining = SleepTimer.remaining
            if !SleepTimer.isActive, remaining == nil || remaining == 0 {
                selectedMinutes = 0
            }
        }
        .onAppear {
            selectedMinutes = SleepTimer.isActive ? selectedMinutes : 0
            remaining = SleepTimer.remaining
            keepScreenOn = UserDefaults.playbackExtrasOptions.keepScreenOn
        }
    }

    private var timerPublisher: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    }
}
