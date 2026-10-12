import ServiceManagement
import SwiftUI

struct UsagePanel: View {
    @ObservedObject var store: UsageStore
    @AppStorage("labelStyle") private var labelStyle = LabelStyle.session.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showingSettings {
                settingsHeader
                settings
            } else {
                header
                usage
            }
        }
        .padding(16)
        .frame(width: 320)
        .task { await store.refresh(force: false) }
    }

    // MARK: Usage

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Claude usage").font(.headline)
            if let at = store.snapshot?.fetchedAt {
                Text(at.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    @ViewBuilder private var usage: some View {
        if let snap = store.snapshot {
            ForEach(snap.limits) { LimitRow(limit: $0) }
        } else if store.error == nil {
            ProgressView().frame(maxWidth: .infinity)
        }

        if let err = store.error {
            Label(err, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Settings

    private var settingsHeader: some View {
        HStack {
            Button {
                showingSettings = false
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Back")
            Text("Settings").font(.headline)
            Spacer()
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Menu bar", selection: $labelStyle) {
                ForEach(LabelStyle.allCases) { Text($0.name).tag($0.rawValue) }
            }
            Picker("Refresh every", selection: $store.refreshMinutes) {
                Text("1 min").tag(1.0)
                Text("2 min").tag(2.0)
                Text("5 min").tag(5.0)
                Text("15 min").tag(15.0)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Divider().padding(.vertical, 2)

            HStack {
                Button("Open usage page") {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
                }
                .buttonStyle(.link)
                Spacer()
                Button("Quit Claude Meter") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .font(.callout)
    }
}

struct LimitRow: View {
    let limit: UsageLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.title).font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(limit.percent.rounded()))% used")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(limit.percent, 100), total: 100)
                .tint(tint)
            if let reset = resetText {
                Text(reset).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tint: Color {
        if limit.severity != "normal" || limit.percent >= 90 { return .red }
        if limit.percent >= 75 { return .orange }
        return .accentColor
    }

    private var resetText: String? {
        guard let raw = limit.resetsAt else { return limit.subtitle }
        // The API returns times like 10:59:59.9; snap to the nearest minute.
        let at = Date(timeIntervalSinceReferenceDate: (raw.timeIntervalSinceReferenceDate / 60).rounded() * 60)
        let cal = Calendar.current
        let time = at.formatted(date: .omitted, time: .shortened)
        let when = cal.isDateInToday(at) ? "at \(time)"
            : cal.isDateInTomorrow(at) ? "tomorrow \(time)"
            : "\(at.formatted(.dateTime.weekday(.wide))) \(time)"
        let base = "Resets \(when) (in \(countdown(to: at)))"
        return limit.subtitle.map { "\($0) · \(base)" } ?? base
    }

    private func countdown(to date: Date) -> String {
        let mins = max(0, Int(date.timeIntervalSinceNow / 60))
        let (d, h, m) = (mins / 1440, mins % 1440 / 60, mins % 60)
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
