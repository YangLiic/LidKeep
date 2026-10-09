import Foundation

@main struct ScreenPowerTests {
    static func main() throws {
        var created = 0
        var released: [UInt32] = []
        var darkenRequests = 0
        var restoreRequests = 0
        var canDarken = true
        var awake = true
        var controller: ScreenPowerController? = ScreenPowerController(
            createAssertion: { created += 1; return UInt32(created) },
            removeAssertion: { released.append($0) },
            darken: { darkenRequests += 1; return canDarken },
            restore: { restoreRequests += 1; return true },
            displayIsAwake: { awake }
        )
        var status = PowerStatus()
        status.lidAvailable = true
        status.lidAwakeWanted = true
        status.sleepDisabled = true
        status.displayInfoAvailable = true
        controller!.update(status: status, policy: .keepOn)
        controller!.update(status: status, policy: .keepOn)
        precondition(created == 1 && released.isEmpty)
        status.screenLocked = true
        controller!.update(status: status, policy: .keepOn)
        controller!.update(status: status, policy: .automatic)
        precondition(released == [1] && darkenRequests == 0, "Lock follows the system display timer in both modes")
        status.screenLocked = false
        awake = false
        controller!.update(status: status, policy: .keepOn)
        precondition(created == 1, "Do not wake a screen that is already off")
        status.lidClosed = true
        controller!.update(status: status, policy: .automatic)
        controller!.update(status: status, policy: .automatic)
        precondition(created == 2 && darkenRequests == 2 && released == [1], "Darken the backlight while keeping remote capture active")
        let restoresBeforeSwitch = restoreRequests
        controller!.update(status: status, policy: .keepOn)
        precondition(restoreRequests == restoresBeforeSwitch + 1 && created == 2 && released == [1])
        controller!.update(status: status, policy: .automatic)
        precondition(darkenRequests == 3)
        status.externalDisplays = 1
        controller!.update(status: status, policy: .automatic)
        precondition(released == [1, 2] && darkenRequests == 3)
        status.externalDisplays = 0
        status.suspended = true
        controller!.update(status: status, policy: .automatic)
        precondition(created == 2 && darkenRequests == 3)
        status.suspended = false
        canDarken = false
        controller!.update(status: status, policy: .automatic)
        precondition(released == [1, 2, 3], "Unsupported backlight control must not keep the display awake")
        canDarken = true
        controller!.update(status: status, policy: .automatic)
        status.lidClosed = false
        let restoresBeforeOpen = restoreRequests
        controller!.update(status: status, policy: .automatic)
        precondition(released == [1, 2, 3, 4] && restoreRequests == restoresBeforeOpen + 1)
        awake = true
        controller!.update(status: status, policy: .keepOn)
        controller = nil
        precondition(released == [1, 2, 3, 4, 5], "Release display assertion when its owner exits")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LidKeepBrightnessTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = directory.appendingPathComponent("brightness.json")
        var brightness: Float = 0.63
        var displayUUID = "built-in-display"
        var readSupported = true
        var writeSupported = true
        var writes: [Float] = []
        let makeBacklight = {
            BuiltInBacklight(snapshotURL: snapshot, display: { 1 }, identity: { _ in displayUUID },
                read: { _ in readSupported ? brightness : nil },
                write: { id, value in
                    precondition(id == 1)
                    guard writeSupported else { return false }
                    writes.append(value)
                    brightness = value
                    return true
                })
        }
        let backlight = makeBacklight()
        precondition(backlight.darken() && brightness == 0)
        precondition(backlight.darken() && writes == [0], "Repeated events must preserve the original brightness")
        let restartedBacklight = makeBacklight()
        writeSupported = false
        precondition(!restartedBacklight.restore() && FileManager.default.fileExists(atPath: snapshot.path))
        writeSupported = true
        displayUUID = "different-display"
        precondition(!restartedBacklight.restore() && writes == [0], "Never apply a saved brightness to another display")
        displayUUID = "built-in-display"
        precondition(restartedBacklight.restore() && brightness == 0.63)
        precondition(!FileManager.default.fileExists(atPath: snapshot.path))
        readSupported = false
        precondition(!backlight.darken() && brightness == 0.63 && writes == [0, 0.63])
        print("Backlight persistence, recovery, remote-capture assertions and system lock timers passed.")
    }
}
