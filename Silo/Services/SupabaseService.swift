/*
 SUPABASE SETUP — paste this into your Supabase project's SQL editor:

 create extension if not exists "uuid-ossp";

 create table public.profiles (
   id uuid references auth.users primary key,
   username text unique not null,
   level integer not null default 1,
   xp integer not null default 0,
   streak integer not null default 0,
   updated_at timestamptz default now()
 );
 alter table public.profiles enable row level security;
 create policy "Profiles readable by authenticated"
   on public.profiles for select using (auth.role() = 'authenticated');
 create policy "Own profile insert"
   on public.profiles for insert with check (auth.uid() = id);
 create policy "Own profile update"
   on public.profiles for update using (auth.uid() = id);

 create table public.friendships (
   id uuid primary key default uuid_generate_v4(),
   requester_id uuid not null references public.profiles(id),
   addressee_id uuid not null references public.profiles(id),
   status text not null default 'pending',
   created_at timestamptz default now(),
   constraint no_self_friend check (requester_id != addressee_id),
   unique(requester_id, addressee_id)
 );
 alter table public.friendships enable row level security;
 create policy "Users see own friendships"
   on public.friendships for select
   using (auth.uid() = requester_id or auth.uid() = addressee_id);
 create policy "Requester inserts"
   on public.friendships for insert with check (auth.uid() = requester_id);
 create policy "Addressee accepts"
   on public.friendships for update using (auth.uid() = addressee_id);

 create table public.study_reminders (
   id uuid primary key default uuid_generate_v4(),
   from_id uuid not null references public.profiles(id),
   to_id uuid not null references public.profiles(id),
   message text not null,
   created_at timestamptz default now(),
   read_at timestamptz
 );
 alter table public.study_reminders enable row level security;
 create policy "Recipient reads reminders"
   on public.study_reminders for select using (auth.uid() = to_id);
 create policy "Sender inserts reminders"
   on public.study_reminders for insert with check (auth.uid() = from_id);
 create policy "Recipient marks read"
   on public.study_reminders for update using (auth.uid() = to_id);
*/

import Foundation
import AppKit
import AuthenticationServices
import UserNotifications

// MARK: - Models

struct SiloProfile: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let level: Int
    let xp: Int
    let streak: Int
}

struct PendingRequest: Identifiable {
    let id: String
    let friendshipId: String
    let profile: SiloProfile
}

private struct FriendshipRaw: Codable {
    let id: String
    let requester_id: String
    let addressee_id: String
}

private struct ReminderRaw: Codable {
    let id: String
    let from_id: String
    let message: String
}

private struct AuthResp: Codable {
    let access_token: String?
    let user: AuthUser?
    struct AuthUser: Codable { let id: String }
}

// MARK: - Service

@MainActor
private class WindowProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
    }
}

@MainActor
class SupabaseService: ObservableObject {
    @Published var isConfigured = false
    @Published var isLoggedIn   = false
    @Published var currentProfile: SiloProfile?
    @Published var friends: [SiloProfile] = []
    @Published var pendingRequests: [PendingRequest] = []
    @Published var errorMessage: String? = nil
    @Published var pendingVerificationEmail: String? = nil
    @Published var needsUsernameSetup = false

    private var pollingTask: Task<Void, Never>?
    private var pendingUsername: String = ""
    private let windowProvider = WindowProvider()
    private var authSession: ASWebAuthenticationSession?

    init() {
        // Pre-configure with project credentials if not already set
        if UserDefaults.standard.string(forKey: "silo_sb_url") == nil {
            UserDefaults.standard.set("https://rugwreavdvrpfokasgbg.supabase.co", forKey: "silo_sb_url")
            UserDefaults.standard.set("sb_publishable_GJghiDyv_LSi0tRpNkVozw_rrsi_9q2", forKey: "silo_sb_key")
        }
        isConfigured = !sbURL.isEmpty && !sbKey.isEmpty
        isLoggedIn   = sbToken != nil && sbUID != nil
        if isLoggedIn { Task { await refreshMe(); await loadFriends() } }
    }

    // MARK: Stored config

    var sbURL: String {
        get { UserDefaults.standard.string(forKey: "silo_sb_url") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "silo_sb_url") }
    }
    var sbKey: String {
        get { UserDefaults.standard.string(forKey: "silo_sb_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "silo_sb_key") }
    }
    var sbToken: String? {
        get { UserDefaults.standard.string(forKey: "silo_sb_token") }
        set { UserDefaults.standard.set(newValue, forKey: "silo_sb_token") }
    }
    var sbUID: String? {
        get { UserDefaults.standard.string(forKey: "silo_sb_uid") }
        set { UserDefaults.standard.set(newValue, forKey: "silo_sb_uid") }
    }

    // MARK: Request builder

    private func req(_ path: String, method: String = "GET",
                     body: [String: Any]? = nil, isAuth: Bool = false,
                     prefer: String? = nil) -> URLRequest? {
        let base = isAuth ? "\(sbURL)/auth/v1" : "\(sbURL)/rest/v1"
        guard let url = URL(string: base + path) else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(sbKey, forHTTPHeaderField: "apikey")
        if let t = sbToken { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let p = prefer { r.setValue(p, forHTTPHeaderField: "Prefer") }
        if let body { r.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        return r
    }

    // MARK: Configure

    func configure(url: String, key: String) {
        sbURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        sbKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        isConfigured = !sbURL.isEmpty && !sbKey.isEmpty
    }

    // MARK: Auth

    func signUp(email: String, password: String, username: String) async throws {
        guard var r = req("/signup", method: "POST", isAuth: true) else { throw e("Config error") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw e(parseMsg(data) ?? "Sign up failed — check email format")
        }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        if let token = auth.access_token, let uid = auth.user?.id {
            sbToken = token; sbUID = uid
            isLoggedIn = true
            try await insertProfile(id: uid, username: username)
            await refreshMe(); await loadFriends(); startPolling()
        } else {
            pendingVerificationEmail = email
            pendingUsername = username
        }
    }

    func signIn(email: String, password: String) async throws {
        guard var r = req("/token?grant_type=password", method: "POST", isAuth: true) else { throw e("Config error") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw e("Invalid email or password")
        }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        guard let token = auth.access_token, let uid = auth.user?.id else {
            throw e("Please verify your email first, then sign in")
        }
        sbToken = token; sbUID = uid
        isLoggedIn = true
        await refreshMe()
        if currentProfile == nil { needsUsernameSetup = true }
        else { await loadFriends(); startPolling() }
    }

    func signOut() {
        sbToken = nil; sbUID = nil
        isLoggedIn = false; currentProfile = nil
        friends = []; pendingRequests = []
        pendingVerificationEmail = nil; needsUsernameSetup = false
        pollingTask?.cancel()
    }

    func verifyOTP(email: String, token: String) async throws {
        guard var r = req("/verify", method: "POST", isAuth: true) else { throw e("Config error") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "signup", "email": email, "token": token])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw e(parseMsg(data) ?? "Invalid or expired code")
        }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        guard let accessToken = auth.access_token, let uid = auth.user?.id else {
            throw e("Verification failed — try signing in instead")
        }
        sbToken = accessToken; sbUID = uid
        isLoggedIn = true
        pendingVerificationEmail = nil
        try await insertProfile(id: uid, username: pendingUsername)
        await refreshMe(); await loadFriends(); startPolling()
    }

    func signInWithGoogle() async throws {
        guard let authURL = URL(string: "\(sbURL)/auth/v1/authorize?provider=google&redirect_to=silo://auth/callback") else {
            throw e("Config error")
        }
        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "silo") { url, error in
                if let error { cont.resume(throwing: error) }
                else if let url { cont.resume(returning: url) }
                else { cont.resume(throwing: self.e("No callback URL")) }
            }
            session.presentationContextProvider = windowProvider
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            _ = session.start()
        }
        authSession = nil
        var params: [String: String] = [:]
        for part in (callbackURL.fragment ?? "").components(separatedBy: "&") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { params[kv[0]] = kv[1] }
        }
        guard let token = params["access_token"] else { throw e("No token in OAuth callback") }
        sbToken = token
        guard let r = req("/user", isAuth: true),
              let (ud, _) = try? await URLSession.shared.data(for: r),
              let dict = try? JSONSerialization.jsonObject(with: ud) as? [String: Any],
              let uid = dict["id"] as? String else { throw e("Could not fetch user info") }
        sbUID = uid
        isLoggedIn = true
        await refreshMe()
        if currentProfile == nil { needsUsernameSetup = true }
        else { await loadFriends(); startPolling() }
    }

    func setUsername(_ username: String) async throws {
        guard let uid = sbUID else { throw e("Not logged in") }
        // insertProfile ignores conflict if profile exists — safe to call for sign-in recovery too
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw e("Username can't be empty") }
        try await insertProfile(id: uid, username: trimmed)
        needsUsernameSetup = false
        await refreshMe(); await loadFriends(); startPolling()
    }

    // MARK: Profile

    private func insertProfile(id: String, username: String) async throws {
        guard var r = req("/profiles?on_conflict=id", method: "POST",
                          prefer: "return=minimal,resolution=ignore-duplicates") else { return }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["id": id, "username": username])
        let (data, resp) = try await URLSession.shared.data(for: r)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 201 else {
            throw e(parseMsg(data) ?? "Username taken or invalid")
        }
    }

    func refreshMe() async {
        guard let uid = sbUID, let r = req("/profiles?id=eq.\(uid)") else { return }
        guard let (data, _) = try? await URLSession.shared.data(for: r),
              let arr = try? JSONDecoder().decode([SiloProfile].self, from: data) else { return }
        currentProfile = arr.first
    }

    func syncStats(level: Int, xp: Int, streak: Int) async {
        guard let uid = sbUID, var r = req("/profiles?id=eq.\(uid)", method: "PATCH") else { return }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["level": level, "xp": xp, "streak": streak])
        _ = try? await URLSession.shared.data(for: r)
    }

    // MARK: Friends

    func searchUser(username: String) async throws -> SiloProfile {
        let enc = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        guard let r = req("/profiles?username=eq.\(enc)") else { throw e("Config error") }
        let (data, _) = try await URLSession.shared.data(for: r)
        let results = try JSONDecoder().decode([SiloProfile].self, from: data)
        guard let found = results.first else { throw e("User '\(username)' not found") }
        guard found.id != sbUID else { throw e("That's you!") }
        return found
    }

    func sendFriendRequest(toUserId: String) async throws {
        guard let myId = sbUID,
              var r = req("/friendships", method: "POST", prefer: "return=minimal") else { throw e("Not logged in") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["requester_id": myId, "addressee_id": toUserId])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 201 else {
            throw e(parseMsg(data) ?? "Request failed — already friends?")
        }
    }

    func acceptRequest(friendshipId: String) async throws {
        guard var r = req("/friendships?id=eq.\(friendshipId)", method: "PATCH") else { return }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "accepted"])
        _ = try? await URLSession.shared.data(for: r)
        await loadFriends()
    }

    func declineRequest(friendshipId: String) async {
        guard let r = req("/friendships?id=eq.\(friendshipId)", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: r)
        await loadFriends()
    }

    func loadFriends() async {
        guard let uid = sbUID else { return }
        guard let r = req("/friendships?or=(requester_id.eq.\(uid),addressee_id.eq.\(uid))&status=eq.accepted") else { return }
        guard let (data, _) = try? await URLSession.shared.data(for: r),
              let ships = try? JSONDecoder().decode([FriendshipRaw].self, from: data) else { return }

        var loaded: [SiloProfile] = []
        for ship in ships {
            let fid = ship.requester_id == uid ? ship.addressee_id : ship.requester_id
            if let r2 = req("/profiles?id=eq.\(fid)"),
               let (d, _) = try? await URLSession.shared.data(for: r2),
               let arr = try? JSONDecoder().decode([SiloProfile].self, from: d),
               let p = arr.first { loaded.append(p) }
        }
        friends = loaded

        guard let r2 = req("/friendships?addressee_id=eq.\(uid)&status=eq.pending") else { return }
        guard let (data2, _) = try? await URLSession.shared.data(for: r2),
              let pending = try? JSONDecoder().decode([FriendshipRaw].self, from: data2) else { return }

        var reqs: [PendingRequest] = []
        for ship in pending {
            if let r3 = req("/profiles?id=eq.\(ship.requester_id)"),
               let (d, _) = try? await URLSession.shared.data(for: r3),
               let arr = try? JSONDecoder().decode([SiloProfile].self, from: d),
               let p = arr.first {
                reqs.append(PendingRequest(id: ship.id, friendshipId: ship.id, profile: p))
            }
        }
        pendingRequests = reqs
    }

    // MARK: Reminders

    func sendReminder(toUserId: String, message: String) async throws {
        guard let myId = sbUID,
              var r = req("/study_reminders", method: "POST", prefer: "return=minimal") else { throw e("Not logged in") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["from_id": myId, "to_id": toUserId, "message": message])
        _ = try? await URLSession.shared.data(for: r)
    }

    func checkReminders() async {
        guard let uid = sbUID,
              let r = req("/study_reminders?to_id=eq.\(uid)&read_at=is.null&select=id,from_id,message") else { return }
        guard let (data, _) = try? await URLSession.shared.data(for: r),
              let reminders = try? JSONDecoder().decode([ReminderRaw].self, from: data) else { return }

        for reminder in reminders {
            var senderName = "A friend"
            if let r2 = req("/profiles?id=eq.\(reminder.from_id)&select=username"),
               let (d, _) = try? await URLSession.shared.data(for: r2),
               let arr = try? JSONDecoder().decode([[String: String]].self, from: d),
               let name = arr.first?["username"] { senderName = name }

            let content = UNMutableNotificationContent()
            content.title = "\(senderName) says: study! 📚"
            content.body = reminder.message
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "reminder_\(reminder.id)", content: content, trigger: nil))

            if var mr = req("/study_reminders?id=eq.\(reminder.id)", method: "PATCH") {
                mr.httpBody = try? JSONSerialization.data(withJSONObject: ["read_at": ISO8601DateFormatter().string(from: Date())])
                _ = try? await URLSession.shared.data(for: mr)
            }
        }
    }

    // MARK: Polling

    func startPolling() {
        guard isLoggedIn else { return }
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await checkReminders()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    // MARK: Util

    private func e(_ msg: String) -> NSError {
        NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
    }
    private func parseMsg(_ data: Data) -> String? {
        struct E: Codable { let msg: String?; let message: String?; let error_description: String? }
        guard let e = try? JSONDecoder().decode(E.self, from: data) else { return nil }
        return e.error_description ?? e.msg ?? e.message
    }
}
