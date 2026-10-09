import Foundation

struct AfterLockPolicy: Equatable, Codable {
    var sleepAfterLock: Bool
    var delayMinutes: Int
    static let allowedDelays = [0, 1, 5, 10, 30]
    static let stayAwake = AfterLockPolicy(sleepAfterLock: false, delayMinutes: 1)
    var isValid: Bool { Self.allowedDelays.contains(delayMinutes) }
    var summary: String {
        guard sleepAfterLock else { return L.text("Stay awake") }
        return delayMinutes == 0 ? L.text("Sleep immediately") : L.format("Sleep after %d minutes", delayMinutes)
    }
    // pmset idle timers apply even when the screen is unlocked.
    var pmsetSleepMinutes: Int { sleepAfterLock ? max(delayMinutes, 1) : 0 }
}

struct PowerStatus: Equatable {
    var sleepDisabled = false
    var sleepMinutesAC = 1
    var sleepMinutesBattery = 1
    var onAC = true
    var lidClosed = false
    var lidAvailable = false
    var screenLocked = false
    var lidAwakeWanted = false
    var suspended = false
    var externalDisplays = 0

    // Global keep-awake takes precedence over lock timers.
    var lockPolicyOverridden: Bool { lidAwakeWanted || sleepDisabled }
    var lockPolicyOverrideMessage: String? {
        if lidAwakeWanted && suspended {
            return L.text("Keep-awake is suspended. Disable keep-awake before editing the screen-lock policy.")
        }
        if lidAwakeWanted {
            return L.text("Overridden by keep-awake. Disable keep-awake to edit the screen-lock policy.")
        }
        if sleepDisabled {
            return L.text("System sleep is disabled. Allow system sleep before editing the screen-lock policy.")
        }
        return nil
    }
}

enum PowerError: LocalizedError {
    case cancelled
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .cancelled: return L.text("Administrator authorization cancelled.")
        case .failed(let message): return message
        }
    }
}

enum PowerParsing {
    static func minutes(_ text: String, section: String) -> Int? {
        var active = false
        for line in text.components(separatedBy: .newlines) {
            if line.hasSuffix(":") { active = line.trimmingCharacters(in: .whitespaces) == section + ":" }
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            if active, parts.count >= 2, parts[0] == "sleep" { return Int(parts[1]) }
        }
        return nil
    }
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    static func sleepDelay(_ arguments: [String]) throws -> Int {
        guard arguments.count <= 2 else { throw PowerError.failed(L.text("Too many arguments.")) }
        guard let minutes = Int(arguments.dropFirst().first ?? "1"), AfterLockPolicy.allowedDelays.contains(minutes) else {
            throw PowerError.failed(L.text("The delay must be 0, 1, 5, 10 or 30 minutes."))
        }
        return minutes
    }
    static func shouldSleepAfterLock(_ status: PowerStatus, policy: AfterLockPolicy) -> Bool {
        status.lidAvailable && !status.lockPolicyOverridden && !status.lidClosed && status.screenLocked && policy.sleepAfterLock
    }
}
