import Foundation

enum CLI {
    private static var usage: String { L.text("cli.help") }

    static func run(arguments: [String]) -> Int32 {
        let cmd = arguments.first ?? "help"
        do {
            if !["ac-sleep", "battery-sleep"].contains(cmd), arguments.count > 1 {
                throw PowerError.failed(L.text("Unexpected arguments. Run lidkeep help."))
            }
            switch cmd {
            case "help", "-h", "--help": print(usage)
            case "status": printStatus()
            case "doctor":
                let version = Bundle.main.object(forInfoDictionaryKey: "LidKeepVersion") as? String ?? "unknown"
                print("LidKeep \(version)")
                print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
                #if arch(arm64)
                print("Process architecture: arm64")
                #else
                print("Process architecture: x86_64")
                #endif
                print("Helper v1 ready: \(PowerManager.helperReady)")
                print("Read-only preview: \(PowerManager.preview)")
                printStatus()
            case "on": try PowerManager.enableLidAwake(); print(L.text("Keep-awake enabled."))
            case "off", "restore": try PowerManager.restoreLidSleep(); print(L.text("System sleep allowed."))
            case "restore-system":
                try PowerManager.restoreSystem()
                UserDefaults.standard.removeObject(forKey: "afterLock.ac")
                UserDefaults.standard.removeObject(forKey: "afterLock.battery")
                print(L.text("Original power settings restored."))
            case "ac-awake", "battery-awake", "ac-sleep", "battery-sleep":
                let status = PowerManager.readStatus()
                var ac = PowerManager.policyFromPmset(sleepMinutes: status.sleepMinutesAC)
                var battery = PowerManager.policyFromPmset(sleepMinutes: status.sleepMinutesBattery)
                let policy = cmd.hasSuffix("awake") ? AfterLockPolicy.stayAwake : AfterLockPolicy(sleepAfterLock: true, delayMinutes: try PowerParsing.sleepDelay(arguments))
                if cmd.hasPrefix("ac-") { ac = policy } else { battery = policy }
                try PowerManager.applyAfterLock(ac: ac, battery: battery)
                for (key, value) in [("ac", ac), ("battery", battery)] {
                    UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: "afterLock.\(key)")
                }
                print(L.text("Idle-sleep settings applied. Keep the app running for screen-lock timers."))
            default: fputs(usage + "\n", stderr); return 2
            }
            return 0
        } catch {
            fputs(L.format("Error: %@", error.localizedDescription) + "\n", stderr)
            return 1
        }
    }
    private static func printStatus() {
        let s = PowerManager.readStatus()
        print("Lid sensor available: \(s.lidAvailable)")
        print("Lid closed: \(s.lidClosed)")
        print("Power: \(s.onAC ? "AC" : "Battery")")
        print("Sleep disabled: \(s.sleepDisabled)")
        print("LidKeep keep-awake wanted: \(s.lidAwakeWanted)")
        print("Keep-awake suspended: \(s.suspended)")
        print("External displays: \(s.externalDisplays)")
        print("System idle sleep / AC: \(s.sleepMinutesAC) min")
        print("System idle sleep / Battery: \(s.sleepMinutesBattery) min")
        print("Screen locked: \(s.screenLocked)")
    }
}
