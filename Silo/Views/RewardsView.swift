import SwiftUI
import SwiftData

@MainActor
struct RewardsView: View {
    var progressVM: UserProgressViewModel
    @Environment(\.modelContext) private var modelContext

    let themes: [(String, String, Color, Int)] = [
        ("Classic Light", "sun.max.fill", .orange, 1),
        ("Graphite Dark", "moon.fill", .gray, 1),
        ("Forest Study", "leaf.fill", .green, 5),
        ("Warm Paper", "doc.text.fill", Color(red: 0.83, green: 0.66, blue: 0.42), 10),
        ("Midnight Blue", "staroflife.fill", .indigo, 20),
    ]

    let sounds: [(String, String, Color, Int)] = [
        ("Rain Pack", "cloud.rain.fill", .blue, 5),
        ("Library Pack", "books.vertical.fill", Color(red: 0.6, green: 0.4, blue: 0.2), 10),
        ("Nature Pack", "leaf.circle.fill", .green, 15),
    ]

    var profile: UserProfile? { progressVM.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                levelCard
                themesSection
                soundsSection
            }
            .padding(24)
        }
        .overlay {
            if progressVM.showLevelUp {
                levelUpOverlay
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rewards")
                .font(.title2).fontWeight(.bold)
            Text("Unlock themes and sounds as you level up")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    var levelCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 72, height: 72)
                Text("\(profile?.level ?? 1)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.rankTitle ?? "Starter")
                    .font(.title3).fontWeight(.bold)
                Text("Level \(profile?.level ?? 1)")
                    .font(.subheadline).foregroundStyle(.secondary)
                XPProgressBar(
                    progress: profile?.levelProgress ?? 0,
                    currentXP: profile?.xpProgressInLevel ?? 0,
                    neededXP: profile?.xpNeededForNextLevel ?? 100
                )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(profile?.totalXP ?? 0)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("Total XP")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    var themesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Themes").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(themes, id: \.0) { name, icon, color, requiredLevel in
                    ThemeCard(
                        name: name,
                        icon: icon,
                        color: color,
                        requiredLevel: requiredLevel,
                        currentLevel: profile?.level ?? 1,
                        isSelected: profile?.selectedTheme == name,
                        isUnlocked: (profile?.level ?? 1) >= requiredLevel
                    ) {
                        selectTheme(name)
                    }
                }
            }
        }
    }

    var soundsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sound Packs").font(.headline)
            HStack(spacing: 14) {
                ForEach(sounds, id: \.0) { name, icon, color, requiredLevel in
                    SoundPackCard(
                        name: name,
                        icon: icon,
                        color: color,
                        requiredLevel: requiredLevel,
                        currentLevel: profile?.level ?? 1,
                        isUnlocked: (profile?.level ?? 1) >= requiredLevel
                    )
                }
                Spacer()
            }
        }
    }

    var levelUpOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🎉").font(.system(size: 64))
                Text("Level Up!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(progressVM.levelUpTitle)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Button("Continue") {
                    progressVM.showLevelUp = false
                }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(.white).foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(40)
            .background(
                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 40)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: progressVM.showLevelUp)
    }

    func selectTheme(_ name: String) {
        guard let p = profile else { return }
        p.selectedTheme = name
        try? modelContext.save()
    }
}

struct ThemeCard: View {
    var name: String
    var icon: String
    var color: Color
    var requiredLevel: Int
    var currentLevel: Int
    var isSelected: Bool
    var isUnlocked: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: isUnlocked ? onSelect : {}) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isUnlocked ? color.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(height: 70)
                    Image(systemName: isUnlocked ? icon : "lock.fill")
                        .font(.system(size: isUnlocked ? 28 : 24))
                        .foregroundStyle(isUnlocked ? color : .secondary.opacity(0.4))
                }
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                if !isUnlocked {
                    Text("Level \(requiredLevel)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct SoundPackCard: View {
    var name: String
    var icon: String
    var color: Color
    var requiredLevel: Int
    var currentLevel: Int
    var isUnlocked: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isUnlocked ? color : .secondary.opacity(0.4))
            }
            Text(name).font(.system(size: 12, weight: .medium))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
            if !isUnlocked {
                Text("Level \(requiredLevel)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 110)
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
