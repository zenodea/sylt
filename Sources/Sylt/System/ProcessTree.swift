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
        return entries.lazy.filter { $0.name == name }.compactMap { hostApplication(above: $0.pid, parents: parents) }.first
    }

    static func hostApplication(ofProcess pid: pid_t) -> NSRunningApplication? {
        let parents = Dictionary(all().map { ($0.pid, $0.parent) }, uniquingKeysWith: { first, _ in first })
        return hostApplication(above: pid, parents: parents)
    }

    private static func hostApplication(above pid: pid_t, parents: [pid_t: pid_t]) -> NSRunningApplication? {
        var current = parents[pid] ?? 0
        while current > 1 {
            if let application = NSRunningApplication(processIdentifier: current), application.bundleIdentifier != nil {
                return application
            }
            current = parents[current] ?? 0
        }
        return nil
    }
}
