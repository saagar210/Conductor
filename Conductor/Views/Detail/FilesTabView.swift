import SwiftUI

struct FilesTabView: View {
    let node: AgentNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !node.filesModified.isEmpty {
                    Section {
                        ForEach(node.filesModified, id: \.self) { file in
                            Label(file, systemImage: "pencil.circle")
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    } header: {
                        Label("Modified (\(node.filesModified.count))", systemImage: "doc.badge.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                if !node.filesCreated.isEmpty {
                    Section {
                        ForEach(node.filesCreated, id: \.self) { file in
                            Label(file, systemImage: "plus.circle")
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    } header: {
                        Label("Created (\(node.filesCreated.count))", systemImage: "doc.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                if node.filesModified.isEmpty && node.filesCreated.isEmpty {
                    Text("No file changes")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}
