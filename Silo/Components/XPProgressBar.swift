import SwiftUI

struct XPProgressBar: View {
    var progress: Double
    var currentXP: Int
    var neededXP: Int
    var accentColor: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor)
                        .frame(width: geo.size.width * max(0, min(1, progress)), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(currentXP) XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(neededXP) XP to next level")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
