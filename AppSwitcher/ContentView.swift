import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = AppListViewModel()
    @State private var hoveredApp: pid_t? = nil

    let columns = [GridItem(.adaptive(minimum: 72, maximum: 80), spacing: 3)]

    var body: some View {
        ZStack {
            DarkGlassBackground()
            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.08))
                appGrid
                Divider().background(Color.white.opacity(0.08))
                footer
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(viewModel.isEditMode ? "Edit" : "AppSwitcher 1.0")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .animation(.easeInOut(duration: 0.2), value: viewModel.isEditMode)
            Spacer()
            if !viewModel.isEditMode {
                Button(action: { viewModel.loadApps() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    viewModel.isEditMode.toggle()
                }
            }) {
                Text(viewModel.isEditMode ? "Done" : "Edit")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(viewModel.isEditMode ? Color.white : Color.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(viewModel.isEditMode ? Color.white.opacity(0.18) : Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }

    private var appGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if viewModel.visibleApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("Tap Edit to choose apps")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(viewModel.visibleApps) { app in
                        AppTile(
                            app: app,
                            isHovered: hoveredApp == app.id,
                            isEditMode: viewModel.isEditMode,
                            isPinned: viewModel.isPinned(app)
                        )
                        .onHover { hovered in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                hoveredApp = hovered ? app.id : nil
                            }
                        }
                        .onTapGesture {
                            if viewModel.isEditMode {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    viewModel.togglePin(app)
                                }
                            } else {
                                viewModel.activate(app)
                            }
                        }
                    }
                }
                .padding(4)
            }
        }
        .frame(maxHeight: 340)
    }

    private var footer: some View {
        HStack {
            Text(viewModel.isEditMode
                 ? "\(viewModel.pinnedBundleIDs.count) selected"
                 : "\(viewModel.visibleApps.count) apps")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("Cmd+Shift+Space")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.06)))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }
}

struct AppTile: View {
    let app: RunningApp
    let isHovered: Bool
    let isEditMode: Bool
    let isPinned: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Icon
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.fill").resizable().foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: isHovered ? .white.opacity(0.3) : .clear, radius: 10, x: 0, y: 3)
            .scaleEffect(isHovered && !isEditMode ? 1.1 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: isHovered)
            // Hover-Hintergrund
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isHovered && !isEditMode ? Color.white.opacity(0.12) : Color.clear)
                    .blur(radius: 4)
                    .scaleEffect(1.15)
            )

            // Edit-Modus Checkmark
            if isEditMode {
                ZStack {
                    Circle()
                        .fill(isPinned ? Color.white : Color.black.opacity(0.55))
                        .frame(width: 17, height: 17)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    if isPinned {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .offset(x: 3, y: -3)
                .transition(.scale.combined(with: .opacity))
            } else if app.windowCount > 1 {
                // Fenster-Badge
                Text("\(app.windowCount)")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.28)))
                    .offset(x: 3, y: -3)
            }
        }
        // Im Edit-Modus: nicht-ausgewaehlte Icons ausblenden
        .opacity(isEditMode && !isPinned ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPinned)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEditMode && isPinned ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        // Tooltip zeigt App-Namen beim Hovern (kein Label noetig)
        .help(app.name)
    }
}



struct DarkGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // .hudWindow: leichteres Material, lässt mehr Inhalt durchscheinen
        // als .fullScreenUI - der Hintergrund wird transparenter und weniger opak
        view.material = .titlebar
        view.blendingMode = .behindWindow
        view.state = .active
        // darkAqua bleibt: stellt sicher, dass die App immer dunkel erscheint
        view.appearance = NSAppearance(named: .darkAqua)
        view.alphaValue = 0.55
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
