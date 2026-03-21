import AppKit
import Combine

// MARK: - Datenmodell für eine laufende App

struct RunningApp: Identifiable, Equatable {
    let id: pid_t              // Prozess-ID — eindeutig und stabil solange die App läuft
    let name: String
    let icon: NSImage?
    let bundleIdentifier: String?
    let windowCount: Int       // Anzahl sichtbarer Fenster

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel: hält die App-Liste und aktualisiert sie

@MainActor
class AppListViewModel: ObservableObject {
    @Published var apps: [RunningApp] = []
    @Published var searchText: String = ""

    // Timer für automatisches Polling (alle 2 Sekunden)
    private var refreshTimer: AnyCancellable?

    // Gefilterte Liste basierend auf Suchtext
    var filteredApps: [RunningApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {
        loadApps()
        startAutoRefresh()
    }

    // MARK: - App-Liste laden

    func loadApps() {
        // NSWorkspace.shared.runningApplications gibt alle laufenden Prozesse zurück
        // Filter: nur reguläre Apps (keine Systemdienste im Hintergrund)
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular   // .regular = normale Apps mit Dock-Icon
        }

        apps = running.compactMap { nsApp in
            guard let name = nsApp.localizedName else { return nil }

            // Fensteranzahl zählen via Accessibility API
            let windowCount = countWindows(for: nsApp.processIdentifier)

            return RunningApp(
                id: nsApp.processIdentifier,
                name: name,
                icon: nsApp.icon,
                bundleIdentifier: nsApp.bundleIdentifier,
                windowCount: windowCount
            )
        }
        // Alphabetisch sortieren für bessere Übersicht
        .sorted { $0.name < $1.name }
    }

    // MARK: - Fensteranzahl via Accessibility API

    private func countWindows(for pid: pid_t) -> Int {
        // AXUIElement: macOS Accessibility-Objekt für den gesamten Prozess
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?

        // kAXWindowsAttribute gibt alle Fenster des Prozesses zurück
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowList
        )

        guard result == .success,
              let windows = windowList as? [AXUIElement] else {
            return 0
        }
        return windows.count
    }

    // MARK: - App in den Vordergrund bringen

    func activate(_ app: RunningApp) {
        guard let nsApp = NSRunningApplication(processIdentifier: app.id) else { return }

        // .activateAllWindows: bringt ALLE Fenster der App nach vorne (nicht nur das zuletzt aktive)
        // .activateIgnoringOtherApps: sofortiges Aktivieren ohne Warten
        nsApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    // MARK: - Automatisches Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadApps()
            }
    }
}
