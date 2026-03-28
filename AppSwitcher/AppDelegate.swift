import AppKit
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: FloatingPanel?
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupFloatingPanel()
        registerGlobalHotkey()
        showPanel()
        checkAccessibilityPermission()
    }

    func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let alert = NSAlert()
            alert.messageText = "Bedienungshilfen fehlen"
            alert.informativeText = "Systemeinstellungen > Datenschutz > Bedienungshilfen: FloatSwitch entfernen, neu hinzufuegen und Schalter aktivieren. Dann App neu starten."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Systemeinstellungen oeffnen")
            alert.addButton(withTitle: "Spaeter")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    func setupFloatingPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 268, height: 320),
            styleMask: [
                .nonactivatingPanel,
                .borderless,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        let contentView = ContentView()
        panel.contentView = FirstMouseHostingView(rootView: contentView)
        panel.center()
        self.floatingPanel = panel
    }

    @objc func showPanel() { floatingPanel?.orderFront(nil) }
    @objc func hidePanel() { floatingPanel?.orderOut(nil) }

    func togglePanel() {
        if floatingPanel?.isVisible == true { hidePanel() }
        else { showPanel() }
    }

    func registerGlobalHotkey() {
        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.signature = OSType("APPS".fourCharCode)
        gMyHotKeyID.id = UInt32(1)
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &eventSpec, nil, nil)
        RegisterEventHotKey(
            UInt32(122), UInt32(controlKey),
            gMyHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }
}

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private func hotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?) -> OSStatus {
    if let delegate = NSApp.delegate as? AppDelegate { delegate.togglePanel() }
    return noErr
}

extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in utf8.prefix(4) { result = result << 8 + FourCharCode(char) }
        return result
    }
}