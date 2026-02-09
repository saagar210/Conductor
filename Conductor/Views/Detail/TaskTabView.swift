import SwiftUI

struct TaskTabView: View {
    let node: AgentNode

    var body: some View {
        ScrollView {
            Text(node.task)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
        }
    }
}
