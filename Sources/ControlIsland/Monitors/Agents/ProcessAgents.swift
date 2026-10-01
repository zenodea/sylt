import AppKit
import Darwin

/// Coding agents found by process name, with their working directory and
/// whether they are burning CPU.
@MainActor
final class ProcessAgents {
    private static let names: Set<String> = ["claude", "codex", "pi"]
    private var cpuTimes: [pid_t: (user: UInt64, sampled: CFTimeInterval)] = [:]

    func scan() -> [HerdrAgent] {
        let now = CACurrentMediaTime()
        var seen: Set<pid_t> = []
        let agents = ProcessTree.all().filter { Self.names.contains($0.name) }.compactMap { entry -> HerdrAgent? in
            seen.insert(entry.pid)
            let cwd = Self.workingDirectory(of: entry.pid)
            return HerdrAgent(
                agent: entry.name,
                agent_status: busy(entry.pid, at: now) ? "working" : "idle",
                pane_id: "pid:\(entry.pid)",
                cwd: cwd,
                focused: false,
                terminal_title_stripped: URL(fileURLWithPath: cwd).lastPathComponent
            )
        }
        cpuTimes = cpuTimes.filter { seen.contains($0.key) }
        return agents
    }

    func focus(_ agent: HerdrAgent) {
        guard let pid = pid_t(agent.pane_id.dropFirst(4)),
              let host = ProcessTree.hostApplication(ofProcess: pid)
        else { return }
        NSApp.yieldActivation(to: host)
        host.activate()
    }

    /// More than a few percent of a core since the last sample counts as working.
    private func busy(_ pid: pid_t, at now: CFTimeInterval) -> Bool {
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0) }
        }
        guard result == 0 else { return false }
        let user = usage.ri_user_time + usage.ri_system_time
        defer { cpuTimes[pid] = (user, now) }
        guard let last = cpuTimes[pid], now > last.sampled else { return false }
        let seconds = Double(user - last.user) / 1_000_000_000
        return seconds / (now - last.sampled) > 0.03
    }

    private static func workingDirectory(of pid: pid_t) -> String {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return "" }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }
}
