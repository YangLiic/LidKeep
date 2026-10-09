import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var status = PowerStatus()
    @Published var acPolicy = AfterLockPolicy.stayAwake
    @Published var batteryPolicy = AfterLockPolicy.stayAwake
    @Published var acSleepWhenDisplayOff = true
    @Published var batterySleepWhenDisplayOff = true
    @Published var busy = false
    @Published var banner: String?
    @Published var bannerIsError = false
    private var bannerLanguageCode = L.languageCode

    private var refreshTimer: Timer?
    private var lockSleepTimer: Timer?
    private var scheduledOnAC: Bool?
    private var observers: [NSObjectProtocol] = []
    private var sawExternalWithLidClosed = false
    private var lastExternalCount = 0

    init() {
        let current = PowerManager.readStatus()
        status = current
        acPolicy = Self.loadPolicy(key: "ac") ?? PowerManager.policyFromPmset(sleepMinutes: current.sleepMinutesAC)
        batteryPolicy = Self.loadPolicy(key: "battery") ?? PowerManager.policyFromPmset(sleepMinutes: current.sleepMinutesBattery)
        acSleepWhenDisplayOff = UserDefaults.standard.object(forKey: "displayOff.acSleep") as? Bool ?? true
        batterySleepWhenDisplayOff = UserDefaults.standard.object(forKey: "displayOff.batterySleep") as? Bool ?? true
        lastExternalCount = current.externalDisplays
        sawExternalWithLidClosed = current.lidClosed && current.externalDisplays > 0
        startWatchingLock()
        startWatchingWake()
        startWatchingDisplays()
        PowerManager.holdLidAwakeIfWanted()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        refresh()
        if PowerManager.preview { showBanner(L.text("Preview mode: read-only. All system changes are disabled.")) }
    }

    deinit {
        observers.forEach {
            DistributedNotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
            NotificationCenter.default.removeObserver($0)
        }
    }

    func refresh() {
        status = PowerManager.readStatus()
    }

    func clearOutdatedBanner() {
        if bannerLanguageCode != L.languageCode { banner = nil }
    }

    func enableLidAwake() {
        run(L.text("Enabling keep-awake…")) {
            try PowerManager.enableLidAwake()
        } after: {
            self.cancelScheduledSleep()
            self.showBanner(L.text("Keep-awake is enabled for lid closure and screen lock. Disable it to allow system sleep. The display-disconnect sleep rule can still suspend keep-awake."))
        }
    }

    func restoreLidSleep() {
        run(L.text("Disabling keep-awake…")) {
            try PowerManager.restoreLidSleep()
        } after: {
            self.showBanner(L.text("System sleep is allowed. Normal closed-display mode or other apps may still keep the Mac awake."))
        }
    }

    func applyAfterLock(ac: AfterLockPolicy, battery: AfterLockPolicy) {
        refresh()
        if let message = status.lockPolicyOverrideMessage {
            showBanner(message)
            return
        }
        run(L.text("Applying screen-lock settings…")) {
            try PowerManager.applyAfterLock(ac: ac, battery: battery)
        } after: {
            self.acPolicy = ac
            self.batteryPolicy = battery
            Self.savePolicy(key: "ac", ac)
            Self.savePolicy(key: "battery", battery)
            self.showBanner(L.format("Screen-lock policy: AC %@; battery %@", ac.summary, battery.summary))
            self.rescheduleIfNeeded()
        }
    }

    var currentAfterLockSummary: String {
        if status.lidAwakeWanted && status.suspended { return L.text("Keep-awake suspended") }
        if status.lidAwakeWanted && !status.sleepDisabled { return L.text("Waiting to resume keep-awake") }
        if status.lidAwakeWanted { return L.text("Overridden by keep-awake") }
        if status.sleepDisabled { return L.text("System sleep disabled") }
        let source = status.onAC ? L.text("AC power") : L.text("Battery")
        let policy = status.onAC ? acPolicy : batteryPolicy
        return "\(source) · \(policy.summary)"
    }

    func setDisplayOffSleep(ac: Bool, battery: Bool) {
        guard !PowerManager.preview, !busy else { return }
        acSleepWhenDisplayOff = ac
        batterySleepWhenDisplayOff = battery
        UserDefaults.standard.set(ac, forKey: "displayOff.acSleep")
        UserDefaults.standard.set(battery, forKey: "displayOff.batterySleep")
        showBanner(L.format("Display disconnect: AC %@; battery %@", ac ? L.text("Sleep") : L.text("Stay awake"), battery ? L.text("Sleep") : L.text("Stay awake")))
        handleDisplayChange()
    }

    var currentDisplayOffSummary: String {
        let sleep = status.onAC ? acSleepWhenDisplayOff : batterySleepWhenDisplayOff
        let source = status.onAC ? L.text("AC power") : L.text("Battery")
        return "\(source) · \(sleep ? L.text("Suspend keep-awake and sleep") : L.text("Keep-awake"))"
    }

    var lidLine: (String, Bool?) {
        PowerManager.lidStatusText(wanted: status.lidAwakeWanted, active: status.sleepDisabled, suspended: status.suspended)
    }

    private func tick() {
        guard !busy else { return }
        let wasOnAC = status.onAC
        handleDisplayChange()
        PowerManager.holdLidAwakeIfWanted()
        refresh()
        if wasOnAC != status.onAC { rescheduleIfNeeded() }
    }

    private func startWatchingWake() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                PowerManager.holdLidAwakeIfWanted()
                self?.refresh()
            }
        })
    }

    private func startWatchingDisplays() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDisplayChange()
            }
        })
    }

    private func handleDisplayChange() {
        guard !busy, !PowerManager.preview else { return }
        refresh()
        let external = status.externalDisplays
        if status.lidClosed && external > 0 {
            sawExternalWithLidClosed = true
        }
        if !status.lidClosed {
            sawExternalWithLidClosed = false
        }

        let lostExternal = status.lidClosed && lastExternalCount > 0 && external == 0 && sawExternalWithLidClosed
        lastExternalCount = external
        guard lostExternal else { return }

        let shouldSleep = status.onAC ? acSleepWhenDisplayOff : batterySleepWhenDisplayOff
        if shouldSleep {
            do {
                try PowerManager.suspendAndSleep()
                showBanner(L.text("External display disconnected. Keep-awake is suspended and sleep was requested. Enable keep-awake again to resume."))
            } catch { showBanner(error.localizedDescription, error: true) }
        } else {
            do {
                try PowerManager.enableLidAwake()
                refresh()
            } catch {
                showBanner(error.localizedDescription, error: true)
                return
            }
            showBanner(L.text("External display disconnected. Keeping the Mac awake as configured."))
        }
    }

    private func startWatchingLock() {
        let center = DistributedNotificationCenter.default
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.handleLocked()
            }
        })
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.cancelScheduledSleep()
                self?.refresh()
            }
        })
    }

    private func handleLocked() {
        refresh()
        rescheduleIfNeeded()
    }

    private func rescheduleIfNeeded() {
        cancelScheduledSleep()
        refresh()
        let policy = status.onAC ? acPolicy : batteryPolicy
        guard PowerParsing.shouldSleepAfterLock(status, policy: policy) else { return }

        let delay = TimeInterval(max(policy.delayMinutes, 0) * 60)
        if delay == 0 {
            requestSleep()
            return
        }
        scheduledOnAC = status.onAC
        lockSleepTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireScheduledSleep()
            }
        }
    }

    private func fireScheduledSleep() {
        refresh()
        if scheduledOnAC != status.onAC { rescheduleIfNeeded(); return }
        let policy = status.onAC ? acPolicy : batteryPolicy
        guard PowerParsing.shouldSleepAfterLock(status, policy: policy) else { return }
        requestSleep()
    }

    private func requestSleep() {
        do { try PowerManager.sleepNow() }
        catch { showBanner(error.localizedDescription, error: true) }
    }

    func restoreSystem() {
        run(L.text("Restoring original power settings…")) { try PowerManager.restoreSystem() } after: {
            self.cancelScheduledSleep()
            self.acPolicy = PowerManager.policyFromPmset(sleepMinutes: self.status.sleepMinutesAC)
            self.batteryPolicy = PowerManager.policyFromPmset(sleepMinutes: self.status.sleepMinutesBattery)
            UserDefaults.standard.removeObject(forKey: "afterLock.ac")
            UserDefaults.standard.removeObject(forKey: "afterLock.battery")
            self.showBanner(L.text("Original power settings restored. Keep-awake stopped."))
        }
    }

    func uninstall() {
        run(L.text("Restoring settings and uninstalling the helper…")) { try PowerManager.uninstall() } after: {
            self.cancelScheduledSleep()
            self.acPolicy = .stayAwake
            self.batteryPolicy = .stayAwake
            self.acSleepWhenDisplayOff = true
            self.batterySleepWhenDisplayOff = true
            self.showBanner(L.text("Helper and background service removed. Quit LidKeep, then move the app to Trash."))
        }
    }

    private func cancelScheduledSleep() {
        lockSleepTimer?.invalidate()
        lockSleepTimer = nil
        scheduledOnAC = nil
    }

    private func run(_ waiting: String, work: @escaping @Sendable () throws -> Void, after: @escaping () -> Void) {
        guard !busy else { return }
        busy = true
        banner = waiting
        bannerLanguageCode = L.languageCode
        bannerIsError = false
        Task {
            let result = await Task.detached { () -> String? in
                do { try work(); return nil }
                catch { return error.localizedDescription }
            }.value
            busy = false
            refresh()
            if let error = result { showBanner(error, error: true) }
            else { after() }
        }
    }

    private func showBanner(_ text: String, error: Bool = false) {
        banner = text
        bannerLanguageCode = L.languageCode
        bannerIsError = error
    }

    private static func loadPolicy(key: String) -> AfterLockPolicy? {
        guard let data = UserDefaults.standard.data(forKey: "afterLock.\(key)") else { return nil }
        guard let policy = try? JSONDecoder().decode(AfterLockPolicy.self, from: data), policy.isValid else { return nil }
        return policy
    }

    private static func savePolicy(key: String, _ policy: AfterLockPolicy) {
        if let data = try? JSONEncoder().encode(policy) {
            UserDefaults.standard.set(data, forKey: "afterLock.\(key)")
        }
    }
}
