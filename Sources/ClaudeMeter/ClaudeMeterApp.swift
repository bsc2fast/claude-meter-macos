import AppKit
import SwiftUI

@main
struct ClaudeMeterApp: App {
    @StateObject private var store = UsageStore()
    @AppStorage("labelStyle") private var labelStyle = LabelStyle.session.rawValue

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            MenuBarLabel(snapshot: store.snapshot, hasError: store.error != nil,
                         style: LabelStyle(rawValue: labelStyle) ?? .session)
        }
        .menuBarExtraStyle(.window)
    }
}

enum LabelStyle: String, CaseIterable, Identifiable {
    case session, sessionAndWeek, iconOnly
    var id: String { rawValue }
    var name: String {
        switch self {
        case .session: "Session %"
        case .sessionAndWeek: "Session · Week"
        case .iconOnly: "Icon only"
        }
    }
}

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot?
    let hasError: Bool
    let style: LabelStyle

    var body: some View {
        let s = snapshot?.session?.percent
        let w = snapshot?.weekly?.percent
        HStack(spacing: 3) {
            Image(nsImage: MeterIcon.make(top: s, bottom: w, dimmed: hasError && snapshot == nil))
            switch style {
            case .session:
                Text(s.map { "\(Int($0.rounded()))%" } ?? "–")
            case .sessionAndWeek:
                Text("\(s.map { "\(Int($0.rounded()))" } ?? "–") · \(w.map { "\(Int($0.rounded()))" } ?? "–")%")
            case .iconOnly:
                EmptyView()
            }
        }
    }
}

/// Two stacked mini bars (session on top, week below), drawn as a template image
/// so it follows the menu bar's light/dark tint like the battery icon does.
enum MeterIcon {
    static func make(top: Double?, bottom: Double?, dimmed: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 14)
        let img = NSImage(size: size, flipped: false) { _ in
            func bar(y: CGFloat, fraction: Double?) {
                let track = NSRect(x: 0.5, y: y, width: 15, height: 5)
                let path = NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5)
                NSColor.black.withAlphaComponent(dimmed ? 0.35 : 1).setStroke()
                path.lineWidth = 1
                path.stroke()
                if let f = fraction, f > 0 {
                    let w = max(1.5, (track.width - 2) * min(f, 100) / 100)
                    NSColor.black.withAlphaComponent(dimmed ? 0.35 : 1).setFill()
                    NSBezierPath(roundedRect: NSRect(x: track.minX + 1, y: y + 1, width: w, height: 3),
                                 xRadius: 0.75, yRadius: 0.75).fill()
                }
            }
            bar(y: 8, fraction: top)
            bar(y: 1, fraction: bottom)
            return true
        }
        img.isTemplate = true
        return img
    }
}
