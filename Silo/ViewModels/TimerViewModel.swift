import SwiftUI
import UserNotifications
import SwiftData
import AppKit

enum TimerState {
    case idle, running, paused, break_
}

@MainActor
@Observable
class TimerViewModel {
    var state: TimerState = .idle
    var currentMode: TimerMode = .pomodoro
    var timeRemaining: TimeInterval = 25 * 60
    var totalDuration: TimeInterval = 25 * 60
    var sessionCount: Int = 0
    var intention: String = ""
    var selectedSubject: String = "Miscellaneous"
    var brainDump: String = ""
    var autoStartBreaks: Bool = false
    var autoStartFocus: Bool = false
    var ambientSoundEnabled: Bool = false
    var currentAmbientSound: String = "None"
    var customFocusMinutes: Int = 25
    var customBreakMinutes: Int = 5
    var pendingReflection: FocusSession? = nil
    var showReflection: Bool = false
    var showIntention: Bool = false
    var audioManager = AmbientAudioManager()

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var currentSession: FocusSession?
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private weak var progressVM: UserProgressViewModel?

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalDuration)
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var isOnBreak: Bool { currentMode.isBreak }

    func setModelContext(_ ctx: ModelContext) {
        self.modelContext = ctx
    }

    func setProgressVM(_ vm: UserProgressViewModel) {
        self.progressVM = vm
    }

    func resetTimerIfIdle() {
        guard state == .idle else { return }
        resetTimer()
    }

    func selectMode(_ mode: TimerMode) {
        guard state == .idle else { return }
        currentMode = mode
        resetTimer()
    }

    func startSession() {
        if isOnBreak {
            beginTimer()
        } else {
            showIntention = true
        }
    }

    func confirmIntentionAndStart() {
        showIntention = false
        beginTimer()
    }

    private func beginTimer() {
        state = .running
        currentSession = FocusSession(
            startTime: Date(),
            duration: totalDuration,
            mode: currentMode,
            intention: intention,
            subjectName: isOnBreak ? "Break" : selectedSubject
        )
        if ambientSoundEnabled && currentAmbientSound != "None" {
            audioManager.resume()
        }
        startTicking()
    }

    func pause() {
        state = .paused
        timerTask?.cancel()
        timerTask = nil
        audioManager.pause()
    }

    func resume() {
        state = .running
        if ambientSoundEnabled && currentAmbientSound != "None" {
            audioManager.resume()
        }
        startTicking()
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        state = .idle
        currentSession = nil
        resetTimer()
    }

    func skipBreak() {
        guard isOnBreak else { return }
        switchToFocus()
    }

    private func startTicking() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.tick() }
            }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            sessionComplete()
            return
        }
        timeRemaining -= 1
    }

    private func sessionComplete() {
        timerTask?.cancel()
        timerTask = nil
        NSSound(named: NSSound.Name("Glass"))?.play()
        sendNotification()

        if !isOnBreak {
            sessionCount += 1
            if let session = currentSession, let ctx = modelContext {
                session.endTime = Date()
                session.wasCompleted = true
                session.xpEarned = 30
                ctx.insert(session)
                try? ctx.save()
                pendingReflection = session
                progressVM?.recordSessionComplete(duration: session.duration, context: ctx)
                showReflection = true
            }
            switchToBreak()
            if !autoStartBreaks { state = .idle }
        } else {
            switchToFocus()
            if autoStartFocus {
                beginTimer()
            } else {
                state = .idle
            }
        }
    }

    private func switchToBreak() {
        currentMode = sessionCount % 4 == 0 ? .longBreak : .shortBreak
        resetTimer()
        if autoStartBreaks { startTicking(); state = .running }
    }

    private func switchToFocus() {
        currentMode = .pomodoro
        resetTimer()
    }

    func resetTimer() {
        let d = UserDefaults.standard
        switch currentMode {
        case .pomodoro:
            let m = d.integer(forKey: "pomodoroDuration")
            totalDuration = TimeInterval((m > 0 ? m : 25) * 60)
        case .shortBreak:
            let m = d.integer(forKey: "shortBreakDuration")
            totalDuration = TimeInterval((m > 0 ? m : 5) * 60)
        case .longBreak:
            let m = d.integer(forKey: "longBreakDuration")
            totalDuration = TimeInterval((m > 0 ? m : 15) * 60)
        case .deepWork:
            let m = d.integer(forKey: "deepWorkDuration")
            totalDuration = TimeInterval((m > 0 ? m : 50) * 60)
        case .custom:
            totalDuration = TimeInterval(customFocusMinutes * 60)
        }
        timeRemaining = totalDuration
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = isOnBreak ? "Break Complete" : "Focus Session Complete"
        content.body = isOnBreak ? "Time to get back to work!" : "Great work! Take a break."
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
