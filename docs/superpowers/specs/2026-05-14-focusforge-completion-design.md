# FocusForge — Completion Design

**Date:** 2026-05-14
**Status:** Approved
**Scope:** Fill all remaining gaps in the existing FocusForge macOS SwiftUI app

---

## Context

Prior session built ~80% of the app: all 6 views (FocusTimer, DailyTasks, StudyPlan, Stats, Rewards, Settings), all SwiftData models, TimerViewModel, UserProgressViewModel, CircularProgressRing, XPProgressBar, StatCard, TaskRowView, and MenuBarView. The app compiles and runs.

---

## Gaps to Fill

### 1. Shared TimerViewModel (Architecture — Critical)

**Problem:** `MenuBarView` creates its own `TimerViewModel` instance. The menu bar timer runs independently from the main window timer.

**Fix:** Make `TimerViewModel` a shared instance in `FocusForgeApp.swift` and inject through the SwiftUI environment. Both `ContentView` and `MenuBarView` receive the same instance.

- In `FocusForgeApp.body`, create `@State private var timerVM = TimerViewModel()`
- Pass via `.environment(timerVM)` to both `ContentView` and `MenuBarView`
- Remove `@State private var timerVM` from `ContentView` and `MenuBarView`
- Declare `@Environment(TimerViewModel.self) private var timerVM` in both

### 2. Settings → TimerViewModel Wiring (Critical)

**Problem:** `@AppStorage` duration values in `SettingsView` are stored but never read by `TimerViewModel`.

**Fix:** `TimerViewModel` gains `@AppStorage` properties for each duration. `resetTimer()` reads these instead of `currentMode.focusDuration` hardcoded values.

### 3. Edit Task (Critical)

**Problem:** No UI to modify an existing task after creation.

**Fix:**
- Add `.contextMenu` to `TaskRowView` with "Edit" and "Delete" actions
- `EditTaskSheet` — same form as `AddTaskSheet` pre-populated with the task's current values, "Save" button updates the model in place

### 4. Custom Timer Duration UI (Critical)

**Problem:** "Custom" appears in the mode picker but no controls to set the duration.

**Fix:** When `timerVM.currentMode == .custom && timerVM.state == .idle`, show two steppers below the mode picker (Focus: 10–120 min, Break: 1–30 min). Stepper changes trigger `timerVM.resetTimer()`.

### 5. Drag to Reorder Tasks (Important)

**Problem:** `DailyTasksView` has no drag-to-reorder.

**Fix:** Add `.onMove` to the `ForEach` in `taskList`. Move handler updates `sortOrder` on affected tasks and saves.

### 6. Ambient Audio — AVFoundation (Important)

**Problem:** Ambient sound UI exists but plays nothing.

**Fix:**
- New `AmbientAudioManager.swift` — `@Observable` class using `AVAudioPlayer`
- 4 looping bundled `.mp3` tracks: Rain, Library, White Noise, Fireplace
- `TimerViewModel` holds a reference; `FocusTimerView` calls play/stop
- Audio auto-stops when timer stops

### 7. Study Block Notifications (Important)

**Problem:** No notifications fire for planned study blocks.

**Fix:**
- `StudyBlock` gains `notificationID: String` field
- New `StudyNotificationManager.swift` — `schedule(block:)` and `cancel(id:)` functions
- `UNCalendarNotificationTrigger` fired at `block.startTime`
- Called on block creation; cancelled on block deletion

### 8. XP Awarded Without Reflection (Important)

**Problem:** XP only awarded if user taps "Save Reflection". Dismissing the sheet gives no XP.

**Fix:**
- `TimerViewModel` holds a weak reference to `UserProgressViewModel`
- `sessionComplete()` calls `progressVM.recordSessionComplete()` immediately
- `ReflectionSheet.saveReflection()` only saves the reflection metadata, no longer awards XP

### 9. Study Block Mark-Complete (Important)

**Problem:** `StudyBlock.isCompleted` exists but no UI to toggle it.

**Fix:** Add circular checkbox button at leading edge of `StudyBlockRow`. Tapping toggles `block.isCompleted` and saves.

### 10. Data Export (Minor)

**Problem:** `exportData()` writes a stub JSON string.

**Fix:** Define `Codable` export structs for tasks, sessions, and profile. Encode real data from `modelContext` to JSON.

### 11. Daily Task Progress Bar (Minor)

**Problem:** Header shows completed/total as text only.

**Fix:** Add slim `ProgressView` (linear) below the count in `DailyTasksView.header`.

---

## New Files

| File | Purpose |
|------|---------|
| `AmbientAudioManager.swift` | AVFoundation looping audio |
| `StudyNotificationManager.swift` | Schedule/cancel study block notifications |

---

## Modified Files

| File | Changes |
|------|---------|
| `FocusForgeApp.swift` | Shared timerVM via environment |
| `ContentView.swift` | Read timerVM from environment |
| `MenuBarView.swift` | Read timerVM from environment |
| `TimerViewModel.swift` | @AppStorage, custom duration, progressVM ref, audio ref |
| `FocusTimerView.swift` | Custom steppers, audio manager, XP fix |
| `DailyTasksView.swift` | Drag reorder, progress bar |
| `TaskRowView.swift` | Context menu: Edit + Delete |
| `StudyPlanView.swift` | Notification scheduling/cancelling, block complete |
| `StudyBlock.swift` | Add notificationID field |
| `SettingsView.swift` | Real JSON export |

---

## Success Criteria

- Menu bar timer and main window timer always in sync
- Settings timer durations affect the next session
- All tasks can be edited after creation
- Custom mode lets user set any duration
- Ambient sound plays when selected during a running session
- Study blocks trigger notifications at their start time
- Completing a session awards XP immediately
- Study blocks can be marked complete
- Export produces valid JSON
- No broken buttons or placeholder actions in the app
