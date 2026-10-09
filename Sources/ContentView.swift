import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var language: LanguageSettings
    @State private var draftAC = AfterLockPolicy.stayAwake
    @State private var draftBattery = AfterLockPolicy.stayAwake
    @State private var draftDisplayOffAC = true
    @State private var draftDisplayOffBattery = true
    @State private var draftsReady = false
    @State private var confirmUninstall = false
    @State private var advancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let banner = model.banner {
                    Text(banner)
                        .font(.callout)
                        .foregroundStyle(model.bannerIsError ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lidKeepPanel()
                }
                statusCard
                lidSection
                DisclosureGroup(L.text("Advanced settings"), isExpanded: $advancedExpanded) {
                    VStack(alignment: .leading, spacing: 20) {
                        afterLockSection
                        Divider()
                        displayOffSection
                    }
                    .padding(.top, 8)
                }
                .font(.headline)
                .lidKeepPanel()
                extras
                footer
            }
            .padding(20)
        }
        .id(language.selection)
        .frame(width: 520, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.blue)
        .onChange(of: model.acPolicy) { _, value in draftAC = value }
        .onChange(of: model.batteryPolicy) { _, value in draftBattery = value }
        .onChange(of: language.selection) { _, _ in model.clearOutdatedBanner() }
        .alert(L.text("Restore settings and uninstall the helper?"), isPresented: $confirmUninstall) {
            Button(L.text("Cancel"), role: .cancel) {}
            Button(L.text("Uninstall"), role: .destructive) { model.uninstall() }
        } message: {
            Text(L.text("This restores the original power settings and removes the administrator helper and background service. Administrator authorization is required. Then you can quit and remove the app."))
        }
        .onAppear {
            model.refresh()
            draftAC = model.acPolicy
            draftBattery = model.batteryPolicy
            draftDisplayOffAC = model.acSleepWhenDisplayOff
            draftDisplayOffBattery = model.batterySleepWhenDisplayOff
            draftsReady = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.text("LidKeep"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker(L.text("Language"), selection: $language.selection) {
                    Text(L.text("Follow system")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 135)
            }
            Text(L.text("Lock screen: ⌃⌘Q"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(spacing: 0) {
            statusRow(L.text("Keep-awake"), model.lidLine.0, good: model.lidLine.1)
            Divider().opacity(0.35)
            statusRow(L.text("Lid"), model.status.lidAvailable ? (model.status.lidClosed ? L.text("Closed") : L.text("Open")) : L.text("Unavailable"), good: nil)
            Divider().opacity(0.35)
            statusRow(L.text("Power"), model.status.onAC ? L.text("AC power") : L.text("Battery"), good: nil)
            Divider().opacity(0.35)
            statusRow(L.text("External displays"), model.status.externalDisplays > 0 ? L.format("%d connected", model.status.externalDisplays) : L.text("None"), good: nil)
            Divider().opacity(0.35)
            statusRow(L.text("Screen-lock policy"), model.currentAfterLockSummary, good: nil)
            Divider().opacity(0.35)
            statusRow(L.text("Display disconnect"), model.currentDisplayOffSummary, good: nil)
        }
        .lidKeepPanel(inset: 12)
    }

    private func statusRow(_ title: String, _ value: String, good: Bool?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: L.languageCode == "en" ? 132 : 92, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color(for: good))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .font(.system(size: 13))
    }

    private func color(for good: Bool?) -> Color {
        switch good {
        case .some(true): return .green
        case .some(false): return .orange
        case .none: return .primary
        }
    }

    private var lidSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.text("Wake controls"))
                .font(.headline)
            Text(L.text("Keep working with the lid closed or the screen locked. Lock the screen yourself. The display-disconnect rule can still suspend keep-awake."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                model.enableLidAwake()
            } label: {
                Label(L.text("Keep awake (lid and screen lock)"), systemImage: "sun.max")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActionButtonStyle(kind: .apply, size: .main))
            .disabled(model.busy || PowerManager.preview)
            .keyboardShortcut("a", modifiers: [.command])

            Button {
                model.restoreLidSleep()
            } label: {
                Label(L.text("Disable keep-awake"), systemImage: "moon.zzz")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActionButtonStyle(kind: .restore, size: .main))
            .disabled(model.busy || PowerManager.preview)
            .keyboardShortcut("r", modifiers: [.command])
        }
        .lidKeepPanel()
    }

    private var afterLockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.text("Screen lock with lid open"))
                .font(.headline)
            if let message = model.status.lockPolicyOverrideMessage {
                Label(message, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L.text("Changes system idle-sleep timers, including while unlocked. Also requests sleep after the configured screen-lock delay."))
                .font(.caption)
                .foregroundStyle(.secondary)

            AfterLockEditor(title: L.text("AC power"), policy: $draftAC, disabled: model.busy || PowerManager.preview || model.status.lockPolicyOverridden)
            AfterLockEditor(title: L.text("Battery"), policy: $draftBattery, disabled: model.busy || PowerManager.preview || model.status.lockPolicyOverridden)

            Button {
                model.applyAfterLock(ac: draftAC, battery: draftBattery)
            } label: {
                Label(L.text("Apply screen-lock settings"), systemImage: "checkmark.circle")
            }
            .buttonStyle(ActionButtonStyle(kind: .apply))
            .disabled(model.busy || !draftsReady || PowerManager.preview || model.status.lockPolicyOverridden)
        }
        .font(.body)
    }

    private var displayOffSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.text("Display disconnect"))
                .font(.headline)
            Label(L.text("Exception: choosing sleep suspends keep-awake. Enable keep-awake again to resume."), systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L.text("Triggered when the last external display disconnects with the lid closed. Standby or turning a monitor off may leave it online."))
                .font(.caption)
                .foregroundStyle(.secondary)

            DisplayOffRow(title: L.text("AC power"), sleeps: $draftDisplayOffAC, disabled: model.busy || PowerManager.preview)
            DisplayOffRow(title: L.text("Battery"), sleeps: $draftDisplayOffBattery, disabled: model.busy || PowerManager.preview)

            Button {
                model.setDisplayOffSleep(ac: draftDisplayOffAC, battery: draftDisplayOffBattery)
            } label: {
                Label(L.text("Apply display-disconnect settings"), systemImage: "checkmark.circle")
            }
            .buttonStyle(ActionButtonStyle(kind: .apply))
            .disabled(model.busy || !draftsReady || PowerManager.preview)
        }
        .font(.body)
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.text("Maintenance"))
                .font(.headline)
            Button {
                model.restoreSystem()
            } label: {
                Label(L.text("Restore original power settings"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ActionButtonStyle(kind: .restore))
            .disabled(model.busy || PowerManager.preview)
            Text(L.text("Restore the power settings saved before the first change and stop keep-awake."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            Button(role: .destructive) {
                confirmUninstall = true
            } label: {
                Label(L.text("Uninstall power helper"), systemImage: "trash")
            }
            .buttonStyle(ActionButtonStyle(kind: .uninstall))
            .disabled(model.busy || PowerManager.preview)
            Text(L.text("Restore power settings and remove the helper and background service. Requires administrator authorization."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L.text("Quitting does not restore settings. Keep the Mac ventilated and allow sleep before putting it in a bag."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lidKeepPanel()
    }

    private var footer: some View {
        Text(L.text("The first change and helper upgrades require administrator authorization. Keep-awake overrides lid and screen-lock sleep. Disable it to edit the separate lock policy in Advanced settings. Lock the screen with ⌃⌘Q."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct DisplayOffRow: View {
    let title: String
    @Binding var sleeps: Bool
    let disabled: Bool

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
            Picker("", selection: $sleeps) {
                Text(L.text("Stay awake")).tag(false)
                Text(L.text("Sleep")).tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(disabled)
        }
    }
}

struct AfterLockEditor: View {
    let title: String
    @Binding var policy: AfterLockPolicy
    let disabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: sleepBinding) {
                    Text(L.text("Stay awake")).tag(false)
                    Text(L.text("Sleep")).tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(disabled)
            }
            if policy.sleepAfterLock {
                Picker(L.text("Delay"), selection: delayBinding) {
                    Text(L.text("Immediately")).tag(0)
                    Text(L.text("1 minute")).tag(1)
                    Text(L.text("5 minutes")).tag(5)
                    Text(L.text("10 minutes")).tag(10)
                    Text(L.text("30 minutes")).tag(30)
                }
                .disabled(disabled)
            }
        }
    }

    private var sleepBinding: Binding<Bool> {
        Binding(
            get: { policy.sleepAfterLock },
            set: { policy.sleepAfterLock = $0 }
        )
    }

    private var delayBinding: Binding<Int> {
        Binding(
            get: { policy.delayMinutes },
            set: { policy.delayMinutes = $0 }
        )
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var language: LanguageSettings

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.format("Keep-awake: %@", model.lidLine.0))
                Text(L.format("Screen-lock policy: %@", model.currentAfterLockSummary))
                Text(L.format("Display disconnect: %@", model.currentDisplayOffSummary))
            }
            .font(.caption)
            Button(L.text("Keep awake (lid and screen lock)")) { model.enableLidAwake() }
                .disabled(model.busy || PowerManager.preview)
                .keyboardShortcut("a")
            Button(L.text("Disable keep-awake")) { model.restoreLidSleep() }
                .disabled(model.busy || PowerManager.preview)
                .keyboardShortcut("r")
            Divider()
            Button(L.text("Show window")) { openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(L.text("Refresh status")) { model.refresh() }
            Divider()
            Button(L.text("Quit")) { NSApp.terminate(nil) }
        }
        .id(language.selection)
    }
}
