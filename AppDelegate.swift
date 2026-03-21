import AppKit
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: NSPanel?
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App versteckt sich aus dem Dock — nur das Float-Panel ist sichtbar
        NSApp.setActivationPolicy(.accessory)

        setupFloatingPanel()
        registerGlobalHotkey()
        showPanel()
    }

    // MARK: - Floating Panel erstellen

    func setupFloatingPanel() {
        // NSPanel statt NSWindow: schwebt über anderen Fenstern, auch wenn eine andere App aktiv ist
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 480),
            styleMask: [
                .nonactivatingPanel,   // Panel aktiviert NICHT die eigene App → andere Apps bleiben im Fokus
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView   // Content geht bis in die Titelleiste
            ],
            backing: .buffered,
            defer: false
        )

        panel.title = "App Switcher"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true              // Schwebt über normalen Fenstern
        panel.level = .floating                  // NSWindowLevel: höher als normale Fenster
        panel.collectionBehavior = [
            .canJoinAllSpaces,                   // Erscheint auf ALLEN Spaces/Desktops
            .stationary,                         // Bewegt sich nicht bei Space-Wechsel
            .fullScreenAuxiliary                 // Bleibt auch im Fullscreen-Modus sichtbar
        ]
        panel.isMovableByWindowBackground = true // Panel durch Klicken und Ziehen verschiebbar
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // SwiftUI View als Inhalt setzen
        let contentView = ContentView()
        panel.contentView = NSHostingView(rootView: contentView)

        // Panel in der Bildschirmmitte positionieren
        panel.center()

        // Schließen-Button versteckt Panel nur (beendet App nicht)
        panel.standardWindowButton(.closeButton)?.target = self
        panel.standardWindowButton(.closeButton)?.action = #selector(hidePanel)

        self.floatingPanel = panel
    }

    // MARK: - Panel anzeigen / verstecken

    @objc func showPanel() {
        floatingPanel?.orderFront(nil)   // Ins Vordergrund bringen ohne die eigene App zu aktivieren
    }

    @objc func hidePanel() {
        floatingPanel?.orderOut(nil)     // Verstecken ohne zu schließen (View bleibt im Speicher)
    }

    func togglePanel() {
        if floatingPanel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Globaler Hotkey (⌥ Space)

    func registerGlobalHotkey() {
        // Carbon Event Handler registrieren — funktioniert systemweit, auch wenn andere Apps aktiv sind
        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.signature = OSType("APPS".fourCharCode)
        gMyHotKeyID.id = UInt32(1)

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C-Callback über eine globale Funktion (Closures gehen hier nicht wegen C-Interop)
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyHandler,
            1,
            &eventSpec,
            nil,
            nil
        )

        // Hotkey registrieren: Option (⌥) + Space
        RegisterEventHotKey(
            UInt32(kVK_Space),                           // Taste: Space
            UInt32(optionKey),                           // Modifier: ⌥ Option
            gMyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Hotkey beim Beenden freigeben
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}

// MARK: - C-kompatibler Hotkey-Handler

/// Diese Funktion muss außerhalb der Klasse und ohne @objc stehen,
/// da Carbon einen C-Funktionszeiger erwartet (kein Swift-Objekt-Methoden-Pointer)
private func hotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    // AppDelegate über das gemeinsame NSApp-Delegate ansprechen
    if let delegate = NSApp.delegate as? AppDelegate {
        delegate.togglePanel()
    }
    return noErr
}

// MARK: - String → FourCharCode Hilfserweiterung

extension String {
    /// Wandelt einen 4-Buchstaben-String in einen OSType (UInt32) um,
    /// wie ihn Carbon für Event-Signaturen braucht
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
