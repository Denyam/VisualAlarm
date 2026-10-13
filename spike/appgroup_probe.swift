import Foundation

// Verifies whether an ad-hoc ("sign -") signed sandboxed app can actually use
// an App Group container. This is the load-bearing premise for the project's
// IPC design, so it is checked empirically rather than assumed.

let groupID = "group.ETFKU52LQ6.co.denis.VisualAlarm.spike"
let fm = FileManager.default

print("uid=\(getuid())")

guard let container = fm.containerURL(
    forSecurityApplicationGroupIdentifier: groupID
) else {
    print("RESULT containerURL=nil")
    print("sandboxed-check: " + homeIsContainered().description)
    exit(2)
}
print("RESULT containerURL=\(container.path)")

do {
    try fm.createDirectory(at: container, withIntermediateDirectories: true)
    let probe = container.appendingPathComponent("probe.txt")
    try "hello".write(to: probe, atomically: true, encoding: .utf8)
    let back = try String(contentsOf: probe, encoding: .utf8)
    print("RESULT write+read=\(back)")
} catch {
    print("RESULT write FAILED: \(error)")
    exit(3)
}

/// Heuristic sandbox check: a sandboxed process's HOME points inside its
/// container directory.
func homeIsContainered() -> Bool {
    let home = NSHomeDirectory()
    return home.contains("/Containers/")
}

print("home=\(NSHomeDirectory())")
print("sandboxed-check: " + homeIsContainered().description)
print("DONE")