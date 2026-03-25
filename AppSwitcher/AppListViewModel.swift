import AppKit
import Combine

struct RunningApp: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let bundleIdentifier: String?
    let windowCount: Int
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool { lhs.id == rhs.id }
}

@MainActor
class AppListViewModel: ObservableObject {
    @Published var allApps: [RunningApp] = []
    @Published var isEditMode: Bool = false
    // Fenster-Modus: latch = normal, xor = nur gewaehlte App sichtbar
    @Published var windowMode: WindowMode = .latch

    enum WindowMode {
        case latch  // Alle Fenster bleiben offen, gewaehlte App kommt nach vorne
        case xor    // Nur gewaehlte App bleibt sichtbar, alle anderen werden versteckt
    }
    @Published var pinnedBundleIDs: Set<String> = []
    private var refreshTimer: Timer?

    var visibleApps: [RunningApp] {
        if isEditMode { return allApps }
        if pinnedBundleIDs.isEmpty { return allApps }
        return allApps.filter { app in
            guard let bid = app.bundleIdentifier else { return false }
            return pinnedBundleIDs.contains(bid)
        }
    }

    init() {
        loadPinnedIDs()
        Task { await loadApps() }
        startAutoRefresh()
    }

    func loadApps() async {
        // Holen der App-Liste auf dem Main Thread (schnell)
        let running = await MainActor.run {
            NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular
            }
        }
        
        // Verarbeitung auf Background Thread (langsam wegen Accessibility API)
        let apps = await withTaskGroup(of: RunningApp?.self) { group in
            for nsApp in running {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    guard let name = nsApp.localizedName else { return nil }
                    // Fenster zählen auf Background Thread - nonisolated Methode
                    let windowCount = self.countWindows(for: nsApp.processIdentifier)
                    return RunningApp(
                        id: nsApp.processIdentifier,
                        name: name,
                        icon: nsApp.icon,
                        bundleIdentifier: nsApp.bundleIdentifier,
                        windowCount: windowCount
                    )
                }
            }
            
            var result: [RunningApp] = []
            for await app in group {
                if let app = app {
                    result.append(app)
                }
            }
            return result.sorted { $0.name < $1.name }
        }
        
        // UI-Update auf Main Thread
        await MainActor.run {
            self.allApps = apps
        }
    }

    // nonisolated: kann von jedem Thread aufgerufen werden (nicht @MainActor gebunden)
    nonisolated private func countWindows(for pid: pid_t) -> Int {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        
        // Timeout hinzufügen, um Hänger zu vermeiden
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

    func activate(_ app: RunningApp) {
        guard let nsApp = NSRunningApplication(processIdentifier: app.id) else { return }

        // Schritt 1: App unhiden falls per Cmd+H versteckt
        if nsApp.isHidden { nsApp.unhide() }

        // Schritt 2: Minimierte Fenster aufklappen via AX
        let appElement = AXUIElementCreateApplication(app.id)
        var windowList: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
           let windows = windowList as? [AXUIElement] {
            for window in windows {
                var minimized: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMin = minimized as? Bool, isMin {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
            }
        }

        // Schritt 3: XOR-Modus - alle anderen Apps verstecken
        // Nur die gewaehlte App bleibt sichtbar auf dem Desktop
        if windowMode == .xor {
            for running in NSWorkspace.shared.runningApplications {
                guard running.activationPolicy == .regular,
                      running.processIdentifier != app.id,
                      running.processIdentifier != ProcessInfo.processInfo.processIdentifier else { continue }
                running.hide()
            }
        }

        // Schritt 4: App in den Vordergrund bringen
        nsApp.activate(options: [.activateAllWindows])
    }

    // Clear: alle laufenden Apps verstecken -> leerer Desktop
    // Fenster-Status Toggle: clear <-> all
    @Published var windowsCleared: Bool = false

    func clearAllWindows() {
        // Alle regulaeren Apps verstecken inkl. Finder
        // activationPolicy == .regular erfasst normale Apps
        // activationPolicy == .accessory erfasst Finder und aehnliche
        // Wir verstecken BEIDE Kategorien ausser AppSwitcher selbst
        let myPID = ProcessInfo.processInfo.processIdentifier
        for running in NSWorkspace.shared.runningApplications {
            guard running.processIdentifier != myPID else { continue }
            guard running.activationPolicy == .regular
               || running.activationPolicy == .accessory else { continue }
            running.hide()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: "tell application \"Finder\" to close every window")?.executeAndReturnError(nil)
        }

        windowsCleared = true
    }

    func showAllWindows() {
        // Alle versteckten Apps wieder sichtbar machen (unhide)
        // und ans aktivieren - auf allen Spaces gleichzeitig
        for running in NSWorkspace.shared.runningApplications {
            guard running.activationPolicy == .regular,
                  running.processIdentifier != ProcessInfo.processInfo.processIdentifier else { continue }
            if running.isHidden {
                running.unhide()
            }
        }
        windowsCleared = false
    }

    func toggleClearAll() {
        if windowsCleared { showAllWindows() }
        else { clearAllWindows() }
    }

    func togglePin(_ app: RunningApp) {
        guard let bid = app.bundleIdentifier else { return }
        if pinnedBundleIDs.contains(bid) { pinnedBundleIDs.remove(bid) }
        else { pinnedBundleIDs.insert(bid) }
        savePinnedIDs()
    }

    func isPinned(_ app: RunningApp) -> Bool {
        guard let bid = app.bundleIdentifier else { return false }
        return pinnedBundleIDs.contains(bid)
    }

    private func savePinnedIDs() {
        UserDefaults.standard.set(Array(pinnedBundleIDs), forKey: "pinnedAppBundleIDs")
    }

    private func loadPinnedIDs() {
        let saved = UserDefaults.standard.stringArray(forKey: "pinnedAppBundleIDs") ?? []
        pinnedBundleIDs = Set(saved)
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { await self?.loadApps() }
        }
    }
}
