import SwiftUI

struct GraphCanvasView: View {
    let positions: [NodePosition]
    let selectedNodeID: UUID?
    let onNodeTapped: (UUID) -> Void

    @State private var offset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let transform = CGAffineTransform(scaleX: scale, y: scale)
                    .translatedBy(x: -offset.width, y: -offset.height)

                // Draw edges first (below nodes)
                for pos in positions {
                    guard let parentID = pos.parentID,
                          let parentPos = positions.first(where: { $0.id == parentID }) else { continue }

                    let start = parentPos.point.applying(transform)
                    let end = pos.point.applying(transform)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(ConductorTheme.edgeColor), lineWidth: 1.5)
                }

                // Draw nodes on top
                for pos in positions {
                    let screenPoint = pos.point.applying(transform)
                    let radius = ConductorTheme.nodeRadius(for: pos.agentType) * scale
                    let rect = CGRect(
                        x: screenPoint.x - radius,
                        y: screenPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    let isSelected = pos.id == selectedNodeID

                    // Selection glow
                    if isSelected {
                        let glowRect = rect.insetBy(dx: -4, dy: -4)
                        let glowPath = Path(ellipseIn: glowRect)
                        context.fill(glowPath, with: .color(ConductorTheme.selectionGlow))
                    }

                    // Node fill (status color)
                    let circlePath = Path(ellipseIn: rect)
                    context.fill(circlePath, with: .color(ConductorTheme.nodeColor(for: pos.status)))

                    // Node stroke (type color)
                    let strokeWidth: CGFloat = isSelected ? 3.0 : 1.5
                    let strokeColor = isSelected ? ConductorTheme.selectionBorder : ConductorTheme.nodeStroke(for: pos.agentType)
                    context.stroke(circlePath, with: .color(strokeColor), lineWidth: strokeWidth)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastDragOffset.width - value.translation.width / scale,
                            height: lastDragOffset.height - value.translation.height / scale
                        )
                    }
                    .onEnded { _ in
                        lastDragOffset = offset
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(value.magnification, 0.1), 5.0)
                    }
            )
            .onTapGesture { location in
                handleTap(at: location)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func handleTap(at screenLocation: CGPoint) {
        // Convert screen → world coordinates
        let worldX = screenLocation.x / scale + offset.width
        let worldY = screenLocation.y / scale + offset.height

        var closestID: UUID?
        var closestDist = Double.infinity

        for pos in positions {
            let dx = pos.x - worldX
            let dy = pos.y - worldY
            let dist = sqrt(dx * dx + dy * dy)
            let hitRadius = ConductorTheme.nodeRadius(for: pos.agentType) + 5.0

            if dist < hitRadius && dist < closestDist {
                closestDist = dist
                closestID = pos.id
            }
        }

        if let id = closestID {
            onNodeTapped(id)
        }
    }
}
