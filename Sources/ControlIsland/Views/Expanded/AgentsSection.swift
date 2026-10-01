import SwiftUI

struct AgentsSection: View {
    @ObservedObject var herdr: HerdrMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("🐑")
                Text("Herdr")
                Spacer()
                Tally(count: herdr.waitingCount, working: false)
                Tally(count: herdr.workingCount, working: true)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(herdr.agents) { agent in
                        AgentRow(agent: agent, since: herdr.statusSince[agent.id]) { herdr.focus(agent) }
                            .frame(height: IslandLayout.agentRowHeight - 3)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(IslandAnimation.value, value: herdr.agents)
            }
            .frame(height: CGFloat(min(herdr.agents.count, IslandLayout.maxAgentRows)) * IslandLayout.agentRowHeight)
        }
    }
}

private struct Tally: View {
    let count: Int
    let working: Bool

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(working: working, size: 5)
            Text("\(count)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .opacity(count == 0 ? 0.4 : 1)
        .animation(IslandAnimation.value, value: count)
    }
}

private struct AgentRow: View {
    let agent: HerdrAgent
    let since: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HarnessIcon(harness: agent.harness, size: 16)
                Text(agent.title).lineLimit(1)
                Spacer()
                if agent.isWorking {
                    WorkingDots()
                } else {
                    waiting
                }
                if agent.focused {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(.white.opacity(agent.focused ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .animation(IslandAnimation.value, value: agent.isWorking)
    }

    private var waiting: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 5) {
                if let since {
                    Text(Self.elapsed(since: since, now: context.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                }
                StatusDot(working: false)
            }
        }
    }

    private static func elapsed(since: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(since) / 60)
        return switch minutes {
        case ..<1: "now"
        case ..<60: "\(minutes)m"
        default: "\(minutes / 60)h"
        }
    }
}
