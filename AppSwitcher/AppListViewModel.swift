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

        // Schritt 1: App unhiden falls sie per Cmd+H oder hide() versteckt wurde
        // isHidden = true bedeutet die App laeuft aber alle Fenster sind unsichtbar
        if nsApp.isHidden {
            nsApp.unhide()
        }

        // Schritt 2: Minimierte Fenster via Accessibility API wiederherstellen
        // AXMinimized = true bedeutet das Fenster ist im Dock verschwunden
        let appElement = AXUIElementCreateApplication(app.id)
        var windowList: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
           let windows = windowList as? [AXUIElement] {
            for window in windows {
                var minimized: CFTypeRef?
                // Jeden minimierten Fenster aufklappen
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool, isMinimized {
                    // kAXMinimizedAttribute auf false setzen klappt das Fenster auf
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                }
            }
        }

        // Schritt 3: App in den Vordergrund bringen (alle Fenster)
        // Kurze Verzoegerung damit unhide/unminimize abgeschlossen ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            nsApp.activate(options: [.activateAllWindows])
        }
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
