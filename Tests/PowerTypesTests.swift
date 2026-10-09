import Foundation

@main struct PowerTypesTests {
    static func main() throws {
        precondition(AppLanguage.code(for: .system, preferredLanguages: ["zh-Hans-CN", "en"]) == "zh-Hans")
        precondition(AppLanguage.code(for: .system, preferredLanguages: ["en-GB", "zh-Hans"]) == "en")
        precondition(AppLanguage.code(for: .system, preferredLanguages: ["fr-FR"]) == "en")
        precondition(AppLanguage.code(for: .system, preferredLanguages: []) == "en")
        precondition(AppLanguage.code(for: .english, preferredLanguages: ["zh-Hans"]) == "en")
        precondition(AppLanguage.code(for: .simplifiedChinese, preferredLanguages: ["en"]) == "zh-Hans")
        // Keep test preferences separate from the installed app.
        let domain = "LidKeepTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: domain)!
        defer { preferences.removePersistentDomain(forName: domain) }
        preferences.set(AppLanguage.english.rawValue, forKey: "language")
        let language = LanguageSettings(defaults: preferences)
        precondition(language.selection == .english)
        language.selection = .simplifiedChinese
        precondition(L.preference(in: preferences) == .simplifiedChinese)
        preferences.removePersistentDomain(forName: domain)
        let deadline = Date().addingTimeInterval(1)
        while language.selection != .system && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(language.selection == .system, "Language selector must reset after uninstall")
        let sample = """
        Battery Power:
         disksleep 10
         sleep 5
         displaysleep 3
        AC Power:
         sleep 0
        UPS Power:
         sleep 30
        """
        precondition(PowerParsing.minutes(sample, section: "Battery Power") == 5)
        precondition(PowerParsing.minutes(sample, section: "AC Power") == 0)
        precondition(PowerParsing.minutes(sample, section: "Missing") == nil)
        precondition(PowerParsing.minutes("AC Power:\n displaysleep 4", section: "AC Power") == nil)
        let defaultDelay = try PowerParsing.sleepDelay(["ac-sleep"])
        precondition(defaultDelay == 1)
        for value in ["abc", "-1", "2", "31", "1; touch /tmp/pwn"] {
            do { _ = try PowerParsing.sleepDelay(["ac-sleep", value]); fatalError("Accepted invalid CLI input") }
            catch {}
        }
        precondition(PowerParsing.shellQuote("path's file $(touch pwn)") == "'path'\\''s file $(touch pwn)'")
        let policy = AfterLockPolicy(sleepAfterLock: true, delayMinutes: 0)
        precondition(policy.pmsetSleepMinutes == 1)
        var status = PowerStatus(); status.lidAvailable = true; status.screenLocked = true
        precondition(PowerParsing.shouldSleepAfterLock(status, policy: policy))
        status.lidClosed = true
        precondition(!PowerParsing.shouldSleepAfterLock(status, policy: policy))
        status.lidClosed = false; status.lidAwakeWanted = true
        precondition(!PowerParsing.shouldSleepAfterLock(status, policy: policy))
        status.lidAwakeWanted = false; status.sleepDisabled = true
        precondition(!PowerParsing.shouldSleepAfterLock(status, policy: policy))
        // Suspension must not activate saved lock timers.
        status.lidAwakeWanted = true; status.sleepDisabled = false; status.suspended = true
        precondition(status.lockPolicyOverridden)
        precondition(status.lockPolicyOverrideMessage == L.text("Keep-awake is suspended. Disable keep-awake before editing the screen-lock policy."))
        precondition(!PowerParsing.shouldSleepAfterLock(status, policy: policy))
        status.lidAwakeWanted = false; status.suspended = false
        precondition(!status.lockPolicyOverridden && status.lockPolicyOverrideMessage == nil)
        precondition(PowerParsing.shouldSleepAfterLock(status, policy: policy))
        print("Power parsing, CLI validation, shell quoting, override states and sleep guards passed.")
    }
}
