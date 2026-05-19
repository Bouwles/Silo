import SwiftUI

@MainActor
struct FriendsView: View {
    @EnvironmentObject var supabase: SupabaseService
    var progressVM: UserProgressViewModel

    var body: some View {
        Group {
            if !supabase.isConfigured {
                SetupView()
            } else if let email = supabase.pendingVerificationEmail {
                VerificationView(email: email)
            } else if supabase.needsUsernameSetup {
                ChooseUsernameView()
            } else if !supabase.isLoggedIn {
                AuthView()
            } else {
                FriendsContent(progressVM: progressVM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(supabase)
    }
}

// MARK: - Setup (Supabase URL + key)

struct SetupView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var url = ""
    @State private var key = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 48)).foregroundStyle(.blue)
            Text("Connect to Supabase").font(.title2).fontWeight(.bold)
            Text("Create a free project at supabase.com, run the SQL from SupabaseService.swift, then paste your project URL and anon key below.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField("Project URL (https://xxx.supabase.co)", text: $url)
                    .textFieldStyle(.roundedBorder)
                SecureField("Anon Key", text: $key)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 360)

            Button("Connect") {
                supabase.configure(url: url, key: key)
            }
            .buttonStyle(.borderedProminent)
            .disabled(url.isEmpty || key.isEmpty)
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Auth (Sign in / Sign up)

struct AuthView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var mode = 0  // 0 = sign in, 1 = sign up
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 40)).foregroundStyle(.blue).padding(.bottom, 8)
            Text("Friends").font(.title2).fontWeight(.bold).padding(.bottom, 20)

            Picker("Mode", selection: $mode) {
                Text("Sign In").tag(0)
                Text("Sign Up").tag(1)
            }
            .pickerStyle(.segmented).frame(width: 220).padding(.bottom, 20)

            VStack(spacing: 12) {
                if mode == 1 {
                    TextField("Username (no spaces)", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 280)

            if let err = error {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 6)
            }

            Button(mode == 0 ? "Sign In" : "Create Account") {
                error = nil
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty || (mode == 1 && username.isEmpty))
            .padding(.top, 16)

            HStack {
                VStack { Divider() }
                Text("or").font(.caption).foregroundStyle(.secondary)
                VStack { Divider() }
            }
            .frame(maxWidth: 280).padding(.top, 8)

            Button {
                error = nil
                Task {
                    isLoading = true
                    do { try await supabase.signInWithGoogle() }
                    catch { self.error = error.localizedDescription }
                    isLoading = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                }
                .frame(maxWidth: 280)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            if isLoading { ProgressView().padding(.top, 8) }
            Spacer()
        }
        .padding(40)
    }

    func submit() async {
        isLoading = true
        do {
            if mode == 0 {
                try await supabase.signIn(email: email, password: password)
            } else {
                try await supabase.signUp(email: email, password: password, username: username)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Main friends content

@MainActor
struct FriendsContent: View {
    @EnvironmentObject var supabase: SupabaseService
    var progressVM: UserProgressViewModel

    @State private var showAddFriend = false
    @State private var reminderTarget: SiloProfile? = nil
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends").font(.title2).fontWeight(.bold)
                    if let me = supabase.currentProfile {
                        Text("@\(me.username) · Level \(me.level)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { Task { isRefreshing = true; await supabase.loadFriends(); isRefreshing = false } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Button { showAddFriend = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20)).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    // Pending requests
                    if !supabase.pendingRequests.isEmpty {
                        pendingSection
                    }

                    // My profile card
                    if let me = supabase.currentProfile {
                        myProfileCard(me)
                    }

                    // Friends
                    if supabase.friends.isEmpty {
                        noFriendsState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(supabase.friends) { friend in
                                FriendRow(friend: friend) {
                                    reminderTarget = friend
                                }
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAddFriend) { AddFriendSheet() }
        .sheet(item: $reminderTarget) { target in ReminderSheet(target: target) }
        .onAppear {
            Task {
                if let p = progressVM.profile {
                    await supabase.syncStats(level: p.level, xp: p.totalXP, streak: p.currentStreak)
                }
                await supabase.loadFriends()
                supabase.startPolling()
            }
        }
    }

    var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FRIEND REQUESTS")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
            ForEach(supabase.pendingRequests) { req in
                HStack(spacing: 12) {
                    initialsCircle(req.profile, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(req.profile.username)").font(.system(size: 14, weight: .medium))
                        Text("Level \(req.profile.level) · 🔥 \(req.profile.streak)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Accept") {
                        Task { try? await supabase.acceptRequest(friendshipId: req.friendshipId) }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Decline") {
                        Task { await supabase.declineRequest(friendshipId: req.friendshipId) }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal, 20).padding(.vertical, 6)
            }
            Divider()
        }
    }

    @ViewBuilder func myProfileCard(_ me: SiloProfile) -> some View {
        HStack(spacing: 12) {
            initialsCircle(me, size: 40)
                .overlay(
                    Circle().stroke(Color.blue, lineWidth: 2)
                        .frame(width: 40, height: 40)
                )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(me.username)").font(.system(size: 14, weight: .semibold))
                    Text("You").font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                Text("Level \(me.level) · \(me.xp) XP · 🔥 \(me.streak) streak")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Sign Out") { supabase.signOut() }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.blue.opacity(0.04))
        Divider()
    }

    var noFriendsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2").font(.system(size: 36)).foregroundStyle(.secondary.opacity(0.4))
            Text("No friends yet").font(.headline)
            Text("Add friends by username to see their progress and send study reminders.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Add Friend") { showAddFriend = true }.buttonStyle(.borderedProminent)
        }
        .padding(40).frame(maxWidth: .infinity)
    }

    func initialsCircle(_ profile: SiloProfile, size: CGFloat) -> some View {
        let words = profile.username.split(separator: "_")
        let initials: String
        if words.count >= 2 {
            initials = String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            initials = String(profile.username.prefix(2)).uppercased()
        }
        let hue = Double(abs(profile.username.hashValue) % 360) / 360.0
        return ZStack {
            Circle().fill(Color(hue: hue, saturation: 0.5, brightness: 0.7))
                .frame(width: size, height: size)
            Text(initials).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(.white)
        }
    }
}

// MARK: - Friend row

struct FriendRow: View {
    let friend: SiloProfile
    let onRemind: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            initialsCircle(friend, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("@\(friend.username)").font(.system(size: 14, weight: .medium))
                HStack(spacing: 8) {
                    Text("Level \(friend.level)").font(.caption).foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text("🔥 \(friend.streak) streak").font(.caption).foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text("\(friend.xp) XP").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onRemind) {
                Label("Remind", systemImage: "bell.fill")
                    .font(.caption).fontWeight(.medium)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    func initialsCircle(_ profile: SiloProfile, size: CGFloat) -> some View {
        let words = profile.username.split(separator: "_")
        let initials = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(profile.username.prefix(2)).uppercased()
        let hue = Double(abs(profile.username.hashValue) % 360) / 360.0
        return ZStack {
            Circle().fill(Color(hue: hue, saturation: 0.5, brightness: 0.7)).frame(width: size, height: size)
            Text(initials).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(.white)
        }
    }
}

// MARK: - Add Friend Sheet

struct AddFriendSheet: View {
    @EnvironmentObject var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var result: SiloProfile? = nil
    @State private var isSearching = false
    @State private var requestSent = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Friend").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    TextField("Search by username", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await search() } }
                    Button("Search") { Task { await search() } }
                        .buttonStyle(.bordered)
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }

                if isSearching {
                    ProgressView()
                } else if let p = result {
                    HStack(spacing: 12) {
                        resultInitials(p)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(p.username)").font(.system(size: 14, weight: .semibold))
                            Text("Level \(p.level) · 🔥 \(p.streak) streak")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if requestSent {
                            Label("Sent", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        } else {
                            Button("Add") {
                                Task {
                                    do {
                                        try await supabase.sendFriendRequest(toUserId: p.id)
                                        requestSent = true
                                    } catch {
                                        self.error = error.localizedDescription
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let err = error {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(20)
            Spacer()
        }
        .frame(width: 340, height: 240)
    }

    func search() async {
        isSearching = true; result = nil; error = nil; requestSent = false
        do { result = try await supabase.searchUser(username: query.trimmingCharacters(in: .whitespaces)) }
        catch { self.error = error.localizedDescription }
        isSearching = false
    }

    func resultInitials(_ p: SiloProfile) -> some View {
        let words = p.username.split(separator: "_")
        let initials = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(p.username.prefix(2)).uppercased()
        let hue = Double(abs(p.username.hashValue) % 360) / 360.0
        return ZStack {
            Circle().fill(Color(hue: hue, saturation: 0.5, brightness: 0.7)).frame(width: 36, height: 36)
            Text(initials).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
        }
    }
}

// MARK: - Reminder Sheet

struct ReminderSheet: View {
    @EnvironmentObject var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let target: SiloProfile

    @State private var custom = ""
    @State private var sent = false
    @State private var error: String? = nil

    let presets = [
        ("Time to study! 📚", "Time to study! 📚"),
        ("Let's grind 💪", "Let's grind 💪"),
        ("Don't fall behind 👀", "Don't fall behind 👀"),
        ("You've got this ✨", "You've got this ✨"),
        ("Stop scrolling and open your notes 😤", "Stop scrolling and open your notes 😤"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Remind @\(target.username)").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    if sent {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36)).foregroundStyle(.green)
                            Text("Reminder sent!").font(.headline)
                            Text("@\(target.username) will get a notification when Silo is open.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                    } else {
                        ForEach(presets, id: \.0) { label, message in
                            Button {
                                Task { await send(message) }
                            } label: {
                                HStack {
                                    Text(label).font(.system(size: 14))
                                    Spacer()
                                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.secondary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 4)

                        HStack(spacing: 8) {
                            TextField("Custom message...", text: $custom)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { Task { await send(custom) } }
                            Button("Send") { Task { await send(custom) } }
                                .buttonStyle(.borderedProminent)
                                .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if let err = error {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 380)
    }

    func send(_ message: String) async {
        guard !message.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await supabase.sendReminder(toUserId: target.id, message: message)
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Email OTP Verification

struct VerificationView: View {
    @EnvironmentObject var supabase: SupabaseService
    let email: String
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44)).foregroundStyle(.blue).padding(.bottom, 12)
            Text("Check your email").font(.title2).fontWeight(.bold).padding(.bottom, 6)
            Text("We sent a 6-digit code to\n\(email)")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.bottom, 24)

            TextField("Enter code", text: $code)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 180)
                .onChange(of: code) { _, new in
                    code = String(new.filter(\.isNumber).prefix(6))
                }

            if let err = error {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 8)
            }

            Button("Verify") {
                error = nil
                Task {
                    isLoading = true
                    do { try await supabase.verifyOTP(email: email, token: code) }
                    catch { self.error = error.localizedDescription }
                    isLoading = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || code.count < 6)
            .padding(.top, 16)

            if isLoading { ProgressView().padding(.top, 8) }

            Button("Back") { supabase.pendingVerificationEmail = nil }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary).padding(.top, 16)

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Choose Username (Google OAuth new user)

struct ChooseUsernameView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var username = ""
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44)).foregroundStyle(.blue).padding(.bottom, 12)
            Text("Choose a username").font(.title2).fontWeight(.bold).padding(.bottom, 6)
            Text("Pick a unique username for Silo.")
                .font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 24)

            TextField("Username (no spaces)", text: $username)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            if let err = error {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 8)
            }

            Button("Continue") {
                error = nil
                Task {
                    isLoading = true
                    do { try await supabase.setUsername(username.trimmingCharacters(in: .whitespaces)) }
                    catch { self.error = error.localizedDescription }
                    isLoading = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || username.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 16)

            if isLoading { ProgressView().padding(.top, 8) }

            Button("Sign Out") { supabase.signOut() }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary).padding(.top, 16)

            Spacer()
        }
        .padding(40)
    }
}
