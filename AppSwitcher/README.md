# AppSwitcher 1.0

Ein schlanker, eleganter App-Launcher für macOS mit floating Panel-Design.

## Features ✨

- **Floating Panel**: Schwebendes, halbtransparentes Fenster mit Dark Glass Design
- **App-Grid**: Übersichtliche Icon-Darstellung aller laufenden Apps
- **Edit-Modus**: Apps pinnen und nur favorisierte Apps anzeigen
- **Fenster-Badges**: Zeigt Anzahl der offenen Fenster pro App
- **Corner Buttons**: Pfeile zum schnellen Verschieben in Bildschirmecken
- **Global Hotkey**: Ctrl+F1 zum Ein-/Ausblenden
- **Multi-Monitor**: Funktioniert auf allen angeschlossenen Bildschirmen
- **Auto-Refresh**: Aktualisiert App-Liste automatisch alle 2 Sekunden

## Installation 🚀

### Voraussetzungen
- macOS 13.0 (Ventura) oder neuer
- Xcode 15 oder neuer (zum Kompilieren)

### Kompilieren
1. Öffne `AppSwitcher.xcodeproj` in Xcode
2. Wähle "Any Mac" als Build Target
3. Product → Archive
4. Distribute App → Copy App
5. Kopiere `AppSwitcher.app` in den `/Applications` Ordner

### Berechtigungen einrichten
Nach dem ersten Start:
1. **Systemeinstellungen** → **Datenschutz & Sicherheit** → **Bedienungshilfen**
2. Klicke auf das **+** Symbol
3. Wähle **AppSwitcher.app** aus
4. Aktiviere das Häkchen
5. Starte AppSwitcher neu

## Nutzung 📖

### Starten
- Doppelklick auf AppSwitcher.app
- Kein Dock-Icon - läuft im Hintergrund
- Panel erscheint automatisch in der Bildschirmmitte

### Bedienung
- **Ctrl+F1**: Panel ein-/ausblenden
- **Klick auf App-Icon**: App aktivieren und in den Vordergrund holen
- **Edit-Button**: Edit-Modus aktivieren
  - Im Edit-Modus: Apps durch Anklicken pinnen/unpinnen
  - Nur gepinnte Apps werden außerhalb des Edit-Modus angezeigt
- **Refresh-Button** (⟳): App-Liste manuell aktualisieren
- **Pfeil-Buttons**: Panel in Bildschirmecke verschieben
  - ↖︎ Oben Links
  - ↗︎ Oben Rechts
  - ↙︎ Unten Links
  - ↘︎ Unten Rechts
- **Rechtsklick**: Kontextmenü → AppSwitcher beenden
- **Cmd+Q**: App beenden

### Edit-Modus
1. Klicke auf "Edit"
2. Alle laufenden Apps werden angezeigt
3. Klicke Apps an, um sie zu pinnen (Häkchen erscheint)
4. Klicke "Done"
5. Nur gepinnte Apps bleiben sichtbar

## Design 🎨

### Dark Glass Material
- Halbtransparentes Fenster mit Blur-Effekt
- Material: `.titlebar` mit 55% Opacity
- Dunkles Theme (`.darkAqua`)
- 20pt abgerundete Ecken

### Icon-Grid
- Adaptive Spalten (72-80pt pro Icon)
- 62×62pt App-Icons
- Hover-Effekte mit Scale und Glow
- Maximale Höhe: 340pt (scrollbar bei vielen Apps)

### Typografie
- Header: 11pt semibold, rounded
- Footer: 9pt rounded
- Buttons: 10pt medium

## Technische Details ⚙️

### Architektur
- **SwiftUI** für die UI
- **AppKit** für Panel-Management
- **Accessibility API** für Fenster-Zählung
- **Carbon** für globalen Hotkey
- **Async/Await** für performante App-Liste

### Projekt-Struktur
```
AppSwitcher/
├── AppSwitcherApp.swift      # @main Einstiegspunkt
├── AppDelegate.swift         # NSPanel Setup, Hotkey
├── AppListViewModel.swift    # Business Logic
├── ContentView.swift         # SwiftUI UI
└── Info.plist               # App-Konfiguration
```

### Klassen
- `FloatingPanel`: NSPanel mit `canBecomeKey: false`
- `FirstMouseHostingView`: Ermöglicht Klicks ohne Fokus
- `AppListViewModel`: ObservableObject für App-Verwaltung
- `RunningApp`: Modell für laufende Apps
- `CornerButton`: Pfeil-Button Komponente

### Sicherheit
- **Kein Sandbox**: Notwendig für globalen Hotkey
- **Accessibility-Berechtigung**: Für Fenster-Zählung
- **LSUIElement**: Versteckt Dock-Icon

## Fehlerbehebung 🔧

### Panel erscheint nicht
- Prüfe, ob die App läuft (Activity Monitor)
- Drücke Ctrl+F1 mehrmals
- Neustart der App

### Apps werden nicht angezeigt
- Klicke auf "Edit" - zeigt alle laufenden Apps
- Klicke Refresh-Button (⟳)
- Prüfe Accessibility-Berechtigung

### Hotkey funktioniert nicht
- Prüfe, ob Ctrl+F1 anderweitig belegt ist
- Systemeinstellungen → Tastatur → Tastaturkurzbefehle
- App neu starten

### Fenster-Anzahl zeigt 0
- Accessibility-Berechtigung fehlt
- Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen
- AppSwitcher aktivieren und neu starten

## Credits 👨‍💻

Entwickelt mit Swift, SwiftUI und AppKit für macOS.

## Version History 📝

### 1.0 (2026-03-22)
- Initiales Release
- Floating Panel Design
- Edit-Modus mit Pin-Funktion
- Corner Buttons
- Global Hotkey Support
- Multi-Monitor Support

## Lizenz 📄

Alle Rechte vorbehalten.
