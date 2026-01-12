import SwiftUI

struct SpeedGraphView: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(size: proxy.size)
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .frame(height: 40)
    }

    private func normalizedPoints(size: CGSize) -> [CGPoint] {
        guard !samples.isEmpty else { return [] }
        let maxValue = max(samples.max() ?? 1, 0.1)
        let stepX = size.width / CGFloat(max(samples.count - 1, 1))
        return samples.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let y = size.height - (CGFloat(value) / CGFloat(maxValue)) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
