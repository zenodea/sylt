import AppKit
import Darwin

enum ProcessTree {
    struct Entry {
        let pid: pid_t
        let parent: pid_t
        let name: String
    }

    static func all() -> [Entry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        let count = size / MemoryLayout<kinfo_proc>.stride
        var buffer = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &buffer, &size, nil, 0) == 0 else { return [] }
        return buffer.prefix(size / MemoryLayout<kinfo_proc>.stride).map { info in
            var comm = info.kp_proc.p_comm
            let name = withUnsafePointer(to: &comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
            }
            return Entry(pid: info.kp_proc.p_pid, parent: info.kp_eproc.e_ppid, name: name)
        }
    }

    /// The GUI application whose process tree contains a process with this name.
    static func hostApplication(ofProcessNamed name: String) -> NSRunningApplication? {
        let entries = all()
        let parents = Dictionary(entries.map { ($0.pid, $0.parent) }, uniquingKeysWith: { first, _ in first })
        for entry in entries where entry.name == name {
            var pid = entry.parent
            while pid > 1 {
                if let application = NSRunningApplication(processIdentifier: pid), application.bundleIdentifier != nil {
                    return application
                }
                pid = parents[pid] ?? 0
            }
        }
        return nil
    }
}
