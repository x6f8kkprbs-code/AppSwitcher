import SwiftUI
import AppKit

@main
struct AppSwitcherApp: App {
    // AppDelegate verwaltet das floating Panel und den globalen Hotkey
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Wir brauchen keine standard WindowGroup — das Panel wird manuell verwaltet
        Settings {
            EmptyView()
        }
    }
}
