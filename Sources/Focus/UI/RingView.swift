import SwiftUI

/// The circular progress indicator at the heart of the window.
struct RingView: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 9
    var paused: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if progress > 0.002 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        tint.opacity(paused ? 0.45 : 1),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
    }
}

/// One dot per focus session in the cycle; filled dots are done.
struct CycleDots: View {
    var completed: Int
    var total: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(1, total), id: \.self) { index in
                Circle()
                    .fill(index < completed ? tint : tint.opacity(0.25))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("\(completed) of \(total) sessions in this cycle completed")
    }
}
