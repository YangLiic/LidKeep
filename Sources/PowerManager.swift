import AppKit
import CoreGraphics
import Darwin
import Foundation

enum PowerManager {
    static let helperPath = "/Library/PrivilegedHelperTools/com.ylc.lidkeep.helper"
    static let agentLabel = "com.ylc.lidkeep.lidwatch"
    static let preview = ProcessInfo.processInfo.environment["LIDKEEP_PREVIEW"] == "1"
    static var helperReady: Bool {
        let result = execute("/usr/bin/sudo", ["-n", helperPath, "version"])
        return result.code == 0 && result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    static func readStatus() -> PowerStatus {
        var status = PowerStatus()
        let pm = runUser("/usr/bin/pmset", ["-g"])
        status.sleepDisabled = pm.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
        let custom = runUser("/usr/bin/pmset", ["-g", "custom"])
        status.sleepMinutesBattery = PowerParsing.minutes(custom, section: "Battery Power") ?? 1
        status.sleepMinutesAC = PowerParsing.minutes(custom, section: "AC Power") ?? 1
        status.onAC = runUser("/usr/bin/pmset", ["-g", "batt"]).contains("AC Power")
        // AppleClamshellState is an undocumented IORegistry property.
        let lid = runUser("/usr/sbin/ioreg", ["-r", "-k", "AppleClamshellState", "-d", "4"])
        status.lidAvailable = lid.contains("\"AppleClamshellState\" =")
        status.lidClosed = lid.contains("\"AppleClamshellState\" = Yes")
        status.screenLocked = isScreenLocked()
        let helper = execute("/usr/bin/sudo", ["-n", helperPath, "status"])
        if helper.code == 0 {
            let fields = helper.output.components(separatedBy: .newlines)
            status.lidAwakeWanted = fields.contains("wanted=1")
            status.suspended = fields.contains("suspended=1")
        }
        let displays = onlineDisplayInfo()
        status.externalDisplays = displays.external
        status.displayInfoAvailable = displays.available
        return status
    }

    static func externalDisplayCount() -> Int {
        onlineDisplayInfo().external
    }

    private static func onlineDisplayInfo() -> (external: Int, available: Bool) {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return (0, false) }
        guard count > 0 else { return (0, true) }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return (0, false) }
        return (ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count, true)
    }

    private static func checkWritable() throws {
        guard !preview else { throw PowerError.failed(L.text("Preview mode cannot change system settings.")) }
    }
    private static func requireHelper() throws {
        try checkWritable()
        if !helperReady { try installPrivilegedOnce() }
    }
    private static func helperCommand(_ arguments: [String]) throws {
        let result = execute("/usr/bin/sudo", ["-n", helperPath] + arguments)
        guard result.code == 0 else {
            throw PowerError.failed(L.format("Power helper failed: %@", result.output.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
    static func enableLidAwake() throws {
        guard readStatus().lidAvailable else { throw PowerError.failed(L.text("No MacBook lid sensor detected.")) }
        try requireHelper()
        try installLaunchAgent()
        try helperCommand(["lid-on"])
        notifyScreenPolicyChanged()
    }
    static func restoreLidSleep() throws {
        try requireHelper()
        try helperCommand(["lid-off"])
        notifyScreenPolicyChanged()
        try restoreScreenBrightness()
    }
    static func restoreSystem() throws {
        try checkWritable()
        guard helperReady else { throw PowerError.failed(L.text("No working LidKeep helper is available. Install it before restoring settings.")) }
        try helperCommand(["restore-system"])
        notifyScreenPolicyChanged()
        try restoreScreenBrightness()
    }
    static func uninstall() throws {
        try checkWritable()
        guard let script = Bundle.main.url(forResource: "uninstall-helper", withExtension: "sh") else {
            throw PowerError.failed(L.text("The uninstaller is missing."))
        }
        try runAdmin(["/bin/bash", script.path].map(PowerParsing.shellQuote).joined(separator: " "))
        _ = execute("/bin/launchctl", ["bootout", "gui/\(getuid())/" + agentLabel])
        try restoreScreenBrightness()
        let home = FileManager.default.homeDirectoryForCurrentUser
        for path in ["Library/LaunchAgents/" + agentLabel + ".plist", "Library/Application Support/LidKeep/lidwatch.sh", "Library/Application Support/LidKeep/.watcher", "Library/Application Support/LidKeep/screen-brightness.json.lock"] {
            let file = home.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
        UserDefaults.standard.removePersistentDomain(forName: "com.ylc.lidkeep")
    }

    static func applyAfterLock(ac: AfterLockPolicy, battery: AfterLockPolicy) throws {
        guard ac.isValid && battery.isValid else { throw PowerError.failed(L.text("Unsupported sleep delay.")) }
        try requireHelper()
        try helperCommand(["sleep-both", "\(ac.pmsetSleepMinutes)", "\(battery.pmsetSleepMinutes)"])
    }
    static func suspendAndSleep() throws {
        try checkWritable()
        try helperCommand(["suspend"])
        notifyScreenPolicyChanged()
        BuiltInBacklight().restore()
        try sleepNow()
    }
    private static func restoreScreenBrightness() throws {
        guard BuiltInBacklight().restore() else {
            throw PowerError.failed(L.text("Brightness could not be restored. Open the lid and try again; the saved brightness has been retained."))
        }
    }
    static func notifyScreenPolicyChanged() {
        DistributedNotificationCenter.default().postNotificationName(ScreenPolicy.notificationName, object: nil, userInfo: nil, deliverImmediately: true)
    }
    static func holdLidAwakeIfWanted() {
        guard !preview else { return }
        _ = execute("/usr/bin/sudo", ["-n", helperPath, "hold"])
    }
    static func isScreenLocked() -> Bool {
        // CGSSessionScreenIsLocked is an undocumented session key.
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    }
    static func sleepNow() throws {
        try checkWritable()
        let result = execute("/usr/bin/pmset", ["sleepnow"])
        guard result.code == 0 else { throw PowerError.failed(L.format("Sleep request failed: %@", result.output)) }
    }
    static func policyFromPmset(sleepMinutes: Int) -> AfterLockPolicy {
        sleepMinutes == 0 ? .stayAwake : AfterLockPolicy(sleepAfterLock: true, delayMinutes: sleepMinutes)
    }
    static func lidStatusText(wanted: Bool, active: Bool, suspended: Bool = false) -> (String, Bool?) {
        if suspended { return (L.text("Suspended; enable keep-awake to resume"), nil) }
        if wanted && active { return (L.text("Enabled for lid closure and screen lock"), true) }
        if wanted { return (L.text("Trying to resume keep-awake"), false) }
        if active { return (L.text("System sleep disabled, possibly by another app"), false) }
        return (L.text("Disabled; using system sleep settings"), nil)
    }
    private static func installPrivilegedOnce() throws {
        guard let helper = Bundle.main.url(forResource: "pmset-helper", withExtension: "sh"),
              let installer = Bundle.main.url(forResource: "install-helper", withExtension: "sh") else {
            throw PowerError.failed(L.text("Installation files are missing. Reinstall LidKeep."))
        }
        let user = NSUserName()
        guard user.range(of: #"^[A-Za-z_][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil else {
            throw PowerError.failed(L.text("The account short name cannot be used for helper authorization."))
        }
        let command = (["/bin/bash", installer.path, helper.path, user].map(PowerParsing.shellQuote)).joined(separator: " ")
        try runAdmin(command)
        guard helperReady else { throw PowerError.failed(L.text("Helper installation could not be verified.")) }
    }
    private static func installLaunchAgent() throws {
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LidKeep")
        let agents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        guard let bundled = Bundle.main.url(forResource: "lidwatch", withExtension: "sh") else {
            throw PowerError.failed(L.text("The background keep-awake script is missing."))
        }
        let watch = support.appendingPathComponent("lidwatch.sh")
        try Data(contentsOf: bundled).write(to: watch, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: watch.path)
        // Preserve the bundle metadata required by the executable's signature.
        let staged = support.appendingPathComponent(".watcher-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staged) }
        let watcherApp = staged.appendingPathComponent("LidKeep.app")
        try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: watcherApp)
        let signature = execute("/usr/bin/codesign", ["--verify", "--deep", "--strict", watcherApp.path])
        guard signature.code == 0 else { throw PowerError.failed(L.format("Background service failed to load: %@", signature.output)) }
        let plist = agents.appendingPathComponent(agentLabel + ".plist")
        let body: [String: Any] = ["Label": agentLabel, "ProgramArguments": ["/bin/bash", watch.path], "KeepAlive": ["Crashed": false], "ThrottleInterval": 10, "RunAtLoad": true]
        try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0).write(to: plist, options: .atomic)
        let domain = "gui/\(getuid())"
        _ = execute("/bin/launchctl", ["bootout", domain + "/" + agentLabel])
        let watcher = support.appendingPathComponent(".watcher")
        if FileManager.default.fileExists(atPath: watcher.path) { try FileManager.default.removeItem(at: watcher) }
        try FileManager.default.moveItem(at: staged, to: watcher)
        let result = execute("/bin/launchctl", ["bootstrap", domain, plist.path])
        guard result.code == 0 else { throw PowerError.failed(L.format("Background service failed to load: %@", result.output)) }
    }
    // Drain output before waiting to avoid a full-pipe deadlock.
    static func execute(_ path: String, _ arguments: [String]) -> (code: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
    static func runUser(_ path: String, _ arguments: [String]) -> String { execute(path, arguments).output }
    static func runAdmin(_ command: String) throws {
        if geteuid() == 0 {
            let result = execute("/bin/bash", ["-c", command])
            guard result.code == 0 else { throw PowerError.failed(result.output) }
            return
        }
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let result = execute("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
        if result.code != 0 {
            if result.output.contains("(-128)") { throw PowerError.cancelled }
            throw PowerError.failed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
