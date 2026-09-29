import Darwin
import Foundation

enum ProcessFiles {
    /// Paths of regular files the process currently has open.
    static func openPaths(pid: pid_t) -> [String] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / MemoryLayout<proc_fdinfo>.stride)
        let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, size)
        guard filled > 0 else { return [] }
        return fds.prefix(Int(filled) / MemoryLayout<proc_fdinfo>.stride)
            .filter { $0.proc_fdtype == PROX_FDTYPE_VNODE }
            .compactMap { fd in
                var info = vnode_fdinfowithpath()
                let length = Int32(MemoryLayout<vnode_fdinfowithpath>.size)
                guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, length) == length else { return nil }
                return withUnsafePointer(to: &info.pvip.vip_path) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                }
            }
    }
}
