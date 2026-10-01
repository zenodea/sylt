import SwiftUI

/// The closed island's view of Herdr: one icon per agent with its status dot.
/// Working agents come first at full strength; idle ones fade back. A dim
/// sheep when Herdr is up but nothing is running.
struct AgentStack: View {
    let agents: [HerdrAgent]

    private var ordered: [HerdrAgent] {
        agents.filter(\.isWorking) + agents.filter { !$0.isWorking }
    }

    static let iconSize: CGFloat = 14
    static let spacing: CGFloat = 3
    static let maxIcons = 3

    static func width(for count: Int) -> CGFloat {
        count == 0 ? 16 : CGFloat(min(count, maxIcons)) * (iconSize + spacing) - spacing
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            if agents.isEmpty {
                Text("🐑").font(.system(size: 13)).opacity(0.45)
            }
            ForEach(ordered.prefix(Self.maxIcons)) { agent in
                HarnessIcon(harness: agent.harness, size: Self.iconSize)
                    .saturation(agent.isWorking ? 1 : 0.2)
                    .opacity(agent.isWorking ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) {
                        StatusDot(working: agent.isWorking, size: 5)
                            .padding(0.5)
                            .background(.black, in: Circle())
                            .offset(x: 1.5, y: 1.5)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(IslandAnimation.value, value: agents)
    }
}
