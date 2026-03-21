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
        loadApps()
        startAutoRefresh()
    }

    func loadApps() {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }
        allApps = running.compactMap { nsApp in
            guard let name = nsApp.localizedName else { return nil }
            return RunningApp(
                id: nsApp.processIdentifier,
                name: name,
                icon: nsApp.icon,
                bundleIdentifier: nsApp.bundleIdentifier,
                windowCount: countWindows(for: nsApp.processIdentifier)
            )
        }.sorted { $0.name < $1.name }
    }

    private func countWindows(for pid: pid_t) -> Int {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else { return 0 }
        return windows.count
    }

    func activate(_ app: RunningApp) {
        guard let nsApp = NSRunningApplication(processIdentifier: app.id) else { return }
        nsApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
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
            Task { @MainActor in self?.loadApps() }
        }
    }
}
