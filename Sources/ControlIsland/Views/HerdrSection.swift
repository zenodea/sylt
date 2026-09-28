import SwiftUI

struct HerdrSection: View {
    @ObservedObject var herdr: HerdrMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("🐑")
                Text("Herdr")
                Spacer()
                Text("\(herdr.workingCount) grazing · \(herdr.idleCount) resting")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(herdr.agents) { agent in
                        AgentRow(agent: agent) { herdr.focus(agent) }
                            .frame(height: IslandLayout.agentRowHeight - 4)
                    }
                }
            }
            .frame(height: CGFloat(min(herdr.agents.count, IslandLayout.maxAgentRows)) * IslandLayout.agentRowHeight)
        }
    }
}

private struct AgentRow: View {
    let agent: HerdrAgent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HarnessIcon(harness: agent.harness, size: 16)
                Text(agent.title).lineLimit(1)
                Spacer()
                Text(agent.isWorking ? "grazing" : "resting")
                    .font(.system(size: 11))
                    .foregroundStyle(agent.isWorking ? Color.green.opacity(0.9) : .white.opacity(0.4))
                if agent.focused {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
