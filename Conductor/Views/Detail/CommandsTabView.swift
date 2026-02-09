import SwiftUI

struct CommandsTabView: View {
    let node: AgentNode

    private var sortedCommands: [CommandRecord] {
        node.commandRecords.sorted { $0.executedAt < $1.executedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if sortedCommands.isEmpty {
                    Text("No commands")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedCommands, id: \.id) { record in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                if !record.stdout.isEmpty {
                                    Text("stdout")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(record.stdout)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(nsColor: .textBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                if !record.stderr.isEmpty {
                                    Text("stderr")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Text(record.stderr)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color.red.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                Text(String(format: "%.1fs", record.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        } label: {
                            HStack {
                                Image(systemName: record.exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(record.exitCode == 0 ? .green : .red)
                                Text(record.command)
                                    .font(.body.monospaced())
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}
