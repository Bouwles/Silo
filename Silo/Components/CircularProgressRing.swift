import SwiftUI

struct CircularProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var size: CGFloat = 240
    var isBreak: Bool = false

    private var ringColor: Color {
        isBreak ? .green : .blue
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}
