# Silo

A native macOS productivity app built with SwiftUI and SwiftData. Silo combines focus timers, task management, work tracking, and study analytics into one clean interface.

## Features

- **Focus Timer** — Pomodoro-style sessions with break intervals, subject tagging, and deep work intention tracking
- **Daily Tasks** — Task list with XP rewards, difficulty ratings, due times, and daily repeat
- **Work Log** — Clock in/clock out stopwatch with labeled sessions and history
- **Weekly Schedule** — Add recurring weekly events (classes, tutoring, etc.) by day
- **Study Schedule** — Manage subjects with daily time goals
- **Analytics** — Charts showing most-studied subjects and deep work topics over time
- **Stats & Rewards** — XP system, levels, streaks, and rank progression
- **General Notes** — Scratch pad for quick notes during sessions
- **AI Assistant** — Local AI chat powered by Ollama; ask anything, get task suggestions based on your subjects
- **Settings** — Custom timer durations, themes, notifications

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later

## Setup

1. Clone the repo
2. Open `Silo.xcodeproj` in Xcode
3. In the **Signing & Capabilities** tab, set your Team
4. Run with `⌘R`

## AI Assistant Setup (Ollama)

The AI Assistant tab requires [Ollama](https://ollama.com) running locally. No API keys or internet connection needed.

1. Download and install Ollama from [ollama.com](https://ollama.com)
2. Pull a model (llama3.2 recommended):
   ```bash
   ollama pull llama3.2
   ```
3. Start the Ollama server:
   ```bash
   ollama serve
   ```
4. Open the **AI Assistant** tab in Silo — models will appear automatically in the picker

Any model available in your local Ollama install works. The assistant receives your subjects and pending tasks as context automatically.

## Tech Stack

- SwiftUI
- SwiftData
- Swift Charts
- UserNotifications framework
- URLSession (Ollama local API)

## License

MIT
