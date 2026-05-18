import SwiftUI
import SwiftData

@MainActor
struct MenuBarView: View {
    @Environment(TimerViewModel.self) private var timerVM

    var body: some View {
        VStack(spacing: 0) {
            mainContent
            Divider()
            menuActions
        }
        .frame(width: 280)
    }

    var mainContent: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.blue)
                Text("Silo").font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerVM.currentMode.rawValue)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Text(timerVM.timeString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                CircularProgressRing(
                    progress: timerVM.progress,
                    lineWidth: 5,
                    size: 52,
                    isBreak: timerVM.isOnBreak
                )
            }

            HStack(spacing: 8) {
                Button {
                    switch timerVM.state {
                    case .idle:
                        timerVM.intention = "Quick Focus"
                        timerVM.confirmIntentionAndStart()
                    case .running: timerVM.pause()
                    case .paused: timerVM.resume()
                    case .break_: timerVM.resume()
                    }
                } label: {
                    Label(
                        timerVM.state == .running ? "Pause" : (timerVM.state == .idle ? "Start" : "Resume"),
                        systemImage: timerVM.state == .running ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if timerVM.state != .idle {
                    Button { timerVM.reset() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
    }

    var menuActions: some View {
        VStack(spacing: 0) {
            MenuBarButton(label: "Open Silo", icon: "arrow.up.right.square") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0.isKeyWindow == false && !$0.className.contains("StatusBar") })?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            MenuBarButton(label: "Quit", icon: "power") {
                NSApp.terminate(nil)
            }
        }
    }
}

struct MenuBarButton: View {
    var label: String
    var icon: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(label).font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
