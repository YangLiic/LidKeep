import AppKit
import CoreGraphics
import IOKit
import Foundation
import Darwin
import IOKit.pwr_mgt

// DisplayServices controls the backlight without putting the display session to sleep.
final class BuiltInBrightnessAPI {
    static let shared = BuiltInBrightnessAPI()
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let handle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL)
        self.handle = handle
        getBrightness = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetBrightness.self) }
        setBrightness = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetBrightness.self) }
    }

    deinit { if let handle = handle { dlclose(handle) } }

    func read(_ display: CGDirectDisplayID) -> Float? {
        guard let getBrightness = getBrightness, setBrightness != nil else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    func write(_ display: CGDirectDisplayID, _ value: Float) -> Bool {
        guard value.isFinite, (0...1).contains(value), let setBrightness = setBrightness else { return false }
        return setBrightness(display, value) == 0
    }

    static func display() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func identity(_ display: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

final class BuiltInBacklight {
    private struct Snapshot: Codable {
        let displayUUID: String
        let brightness: Float
        var isValid: Bool { brightness.isFinite && (0...1).contains(brightness) }
    }

    static let snapshotURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/LidKeep/screen-brightness.json")
    private let snapshotURL: URL
    private let display: () -> CGDirectDisplayID?
    private let identity: (CGDirectDisplayID) -> String?
    private let read: (CGDirectDisplayID) -> Float?
    private let write: (CGDirectDisplayID, Float) -> Bool

    init(
        snapshotURL: URL = BuiltInBacklight.snapshotURL,
        display: @escaping () -> CGDirectDisplayID? = BuiltInBrightnessAPI.display,
        identity: @escaping (CGDirectDisplayID) -> String? = BuiltInBrightnessAPI.identity,
        read: @escaping (CGDirectDisplayID) -> Float? = BuiltInBrightnessAPI.shared.read,
        write: @escaping (CGDirectDisplayID, Float) -> Bool = BuiltInBrightnessAPI.shared.write
    ) {
        self.snapshotURL = snapshotURL
        self.display = display
        self.identity = identity
        self.read = read
        self.write = write
    }

    func darken() -> Bool {
        withLock {
            guard let display = self.display(), let uuid = identity(display),
                  let brightness = read(display), brightness.isFinite, (0...1).contains(brightness) else { return false }
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                guard let snapshot = load(), snapshot.displayUUID == uuid else { return false }
            } else {
                // Save before changing brightness so a restarted service can restore it.
                do {
                    let data = try JSONEncoder().encode(Snapshot(displayUUID: uuid, brightness: brightness))
                    try data.write(to: snapshotURL, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshotURL.path)
                } catch { return false }
            }
            return brightness == 0 || write(display, 0)
        }
    }

    @discardableResult func restore() -> Bool {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return true }
        return withLock {
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return true }
            guard let snapshot = load(), let display = self.display(),
                  identity(display) == snapshot.displayUUID, write(display, snapshot.brightness) else { return false }
            do { try FileManager.default.removeItem(at: snapshotURL); return true }
            catch { return false }
        }
    }

    private func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), snapshot.isValid else { return nil }
        return snapshot
    }

    private func withLock(_ operation: () -> Bool) -> Bool {
        let directory = snapshotURL.deletingLastPathComponent()
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { return false }
        let descriptor = open(snapshotURL.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { return false }
        defer { flock(descriptor, LOCK_UN) }
        return operation()
    }
}

final class ScreenPowerController {
    private var assertion: IOPMAssertionID?
    private let createAssertion: () -> IOPMAssertionID?
    private let removeAssertion: (IOPMAssertionID) -> Void
    private let darken: () -> Bool
    private let restore: () -> Bool
    private let displayIsAwake: () -> Bool

    init(
        createAssertion: @escaping () -> IOPMAssertionID? = ScreenPowerController.makeAssertion,
        removeAssertion: @escaping (IOPMAssertionID) -> Void = { _ = IOPMAssertionRelease($0) },
        backlight: BuiltInBacklight = BuiltInBacklight(),
        darken: (() -> Bool)? = nil,
        restore: (() -> Bool)? = nil,
        displayIsAwake: @escaping () -> Bool = {
            BuiltInBrightnessAPI.display().map { CGDisplayIsAsleep($0) == 0 } ?? false
        }
    ) {
        self.createAssertion = createAssertion
        self.removeAssertion = removeAssertion
        self.darken = darken ?? backlight.darken
        self.restore = restore ?? backlight.restore
        self.displayIsAwake = displayIsAwake
    }

    deinit { releaseAssertion() }

    func update(status: PowerStatus, policy: ScreenPolicy) {
        guard !PowerManager.preview else { return }
        switch policy.action(status: status) {
        case .darkenBuiltInDisplay:
            // Keep remote capture active while the physical backlight is dark.
            if assertion == nil { assertion = createAssertion() }
            guard assertion != nil, darken() else { releaseAssertion(); _ = restore(); return }
        case .preventDisplayIdleSleep:
            _ = restore()
            if assertion == nil, displayIsAwake() { assertion = createAssertion() }
        case .none:
            releaseAssertion()
            _ = restore()
        }
    }

    func stop() {
        releaseAssertion()
        _ = restore()
    }

    private func releaseAssertion() {
        if let identifier = assertion { removeAssertion(identifier) }
        assertion = nil
    }

    private static func makeAssertion() -> IOPMAssertionID? {
        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LidKeep screen policy" as CFString,
            &identifier
        )
        return result == kIOReturnSuccess ? identifier : nil
    }
}

final class LidStateObserver {
    // kIOPMMessageClamshellStateChange is a C macro unavailable to Swift.
    private static let clamshellMessage: UInt32 = 0xe0034100
    private let onChange: () -> Void
    private var port: IONotificationPortRef?
    private var notification: io_object_t = 0
    private var source: CFRunLoopSource?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return }
        defer { IOObjectRelease(root) }
        let result = IOServiceAddInterestNotification(
            port, root, kIOGeneralInterest,
            { context, _, message, _ in
                guard message == LidStateObserver.clamshellMessage, let context = context else { return }
                Unmanaged<LidStateObserver>.fromOpaque(context).takeUnretainedValue().onChange()
            },
            Unmanaged.passUnretained(self).toOpaque(), &notification
        )
        guard result == kIOReturnSuccess,
              let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    deinit {
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if notification != 0 { IOObjectRelease(notification) }
        if let port = port { IONotificationPortDestroy(port) }
    }
}

enum BackgroundWatcher {
    static func run(readOnly: Bool = false, duration: TimeInterval? = nil) -> Int32 {
        guard !PowerManager.preview || readOnly else { return 1 }
        let controller = ScreenPowerController()
        let preferences = UserDefaults.standard
        let update = {
            preferences.synchronize()
            let status = PowerManager.readStatus()
            let policy = ScreenPolicy.load(from: preferences)
            if readOnly { _ = policy.action(status: status) }
            else { controller.update(status: status, policy: policy) }
        }
        let lidObserver = LidStateObserver(onChange: update)
        let center = DistributedNotificationCenter.default
        let observers = ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked", ScreenPolicy.notificationName.rawValue].map { name in
            center.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { _ in update() }
        }
        defer { observers.forEach { center.removeObserver($0) } }
        var nextHold: TimeInterval = 0
        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            if !readOnly, now >= nextHold {
                PowerManager.holdLidAwakeIfWanted()
                nextHold = now + 20
            }
            update()
        }
        RunLoop.main.add(timer, forMode: .common)
        let stopTimer = duration.map { seconds in
            Timer(timeInterval: seconds, repeats: false) { _ in CFRunLoopStop(CFRunLoopGetMain()) }
        }
        if let stopTimer = stopTimer { RunLoop.main.add(stopTimer, forMode: .common) }
        defer { timer.invalidate(); stopTimer?.invalidate() }
        let signals: [Int32] = [SIGTERM, SIGINT]
        let terminationSignals = signals.map { number -> (Int32, sig_t?, DispatchSourceSignal) in
            let previous = signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { CFRunLoopStop(CFRunLoopGetMain()) }
            source.resume()
            return (number, previous, source)
        }
        defer {
            terminationSignals.forEach { number, previous, source in source.cancel(); signal(number, previous) }
        }
        update()
        withExtendedLifetime(lidObserver) { CFRunLoopRun() }
        if !readOnly { controller.stop() }
        return 0
    }
}
