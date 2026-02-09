import SwiftUI

struct ResultTabView: View {
    let node: AgentNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage = node.errorMessage, !errorMessage.isEmpty {
                    Text("Error")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !node.result.isEmpty {
                    Text("Result")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(node.result)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if node.result.isEmpty && (node.errorMessage ?? "").isEmpty {
                    Text("No result yet")
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
