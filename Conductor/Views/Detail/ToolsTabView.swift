import SwiftUI

struct ToolsTabView: View {
    let node: AgentNode

    private var sortedTools: [ToolCallRecord] {
        node.toolCallRecords.sorted { $0.executedAt < $1.executedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if sortedTools.isEmpty {
                    Text("No tool calls")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedTools, id: \.id) { record in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                if !record.input.isEmpty {
                                    Text("Input")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(record.input)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(nsColor: .textBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                if !record.output.isEmpty {
                                    Text("Output")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(record.output)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(nsColor: .textBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .padding(.leading, 4)
                        } label: {
                            HStack {
                                Image(systemName: toolIcon(for: record.toolName))
                                    .foregroundStyle(ConductorTheme.color(for: record.status))
                                Text(record.toolName)
                                    .font(.body)
                                StatusBadge(toolStatus: record.status)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func toolIcon(for name: String) -> String {
        switch name.lowercased() {
        case "read":  return "doc.text"
        case "write": return "square.and.pencil"
        case "edit":  return "pencil.line"
        case "bash":  return "terminal"
        case "grep":  return "magnifyingglass"
        case "glob":  return "folder.badge.magnifyingglass"
        case "task":  return "arrow.triangle.branch"
        default:      return "wrench"
        }
    }
}
