//
//  SettingsView.swift
//  Mahu — Preferences window (macOS 14+)
//
//  Drop into a SwiftUI lifecycle app. Wire it up as the Settings scene:
//
//      @main
//      struct MahuApp: App {
//          var body: some Scene {
//              MenuBarExtra("Mahu", systemImage: "eye") { /* … */ }
//              Settings { SettingsView() }   // ⌘, opens this window
//          }
//      }
//
//  State is persisted with @AppStorage (UserDefaults) so the panel behaves
//  like a real Preferences window. Swap to @Binding if you prefer to hoist
//  state into a parent / view model.
//

import SwiftUI

struct SettingsView: View {

    // MARK: Persisted settings
    @AppStorage("workDuration")   private var workDuration: Int = 20      // minutes
    @AppStorage("breakDuration")  private var breakDuration: Int = 20     // seconds
    @AppStorage("showMenuTimer")  private var showMenuTimer: Bool = false
    @AppStorage("launchAtLogin")  private var launchAtLogin: Bool = false
    @AppStorage("idleResetEnabled") private var idleResetEnabled: Bool = false
    @AppStorage("idleResetMinutes") private var idleResetMinutes: Int = 5
    @AppStorage("overlayMessage") private var overlayMessage: String = "Время отвлечься"

    // Launch-at-login is gated for unsigned builds (see note below).
    private let launchAtLoginAvailable = false

    var body: some View {
        Form {

            // MARK: Timers
            Section("Timers") {
                Stepper(value: $workDuration, in: 1...180) {
                    LabeledContent("Work Duration") {
                        Text("\(workDuration) min").monospacedDigit()
                    }
                }
                Stepper(value: $breakDuration, in: 5...600, step: 5) {
                    LabeledContent("Break Duration") {
                        Text("\(breakDuration) sec").monospacedDigit()
                    }
                }
            }

            // MARK: General
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(!launchAtLoginAvailable)
            } header: {
                Text("General")
            } footer: {
                if !launchAtLoginAvailable {
                    Label {
                        Text("Currently unavailable due to macOS security policies "
                           + "for unsigned apps. Add Mahu to Login Items manually "
                           + "in System Settings.")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }

            // MARK: Away Behavior
            Section {
                Toggle(isOn: $idleResetEnabled) {
                    HStack(spacing: 8) {
                        Text("Also reset timer when inactive for")
                        if idleResetEnabled {
                            Stepper(value: $idleResetMinutes, in: 1...240) {
                                Text("\(idleResetMinutes) min").monospacedDigit()
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
            } header: {
                Text("Away Behavior")
            } footer: {
                Text("Mahu always resets the timer when your screen is locked "
                   + "or your Mac goes to sleep.")
                    .foregroundStyle(.secondary)
            }

            // MARK: Display
            Section("Display") {
                Toggle("Show timer in menu bar", isOn: $showMenuTimer)
                LabeledContent("Break overlay message") {
                    TextField("Time to look away", text: $overlayMessage)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 220)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .scrollDisabled(true)
    }
}

#Preview {
    SettingsView()
}
