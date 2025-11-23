# SnapFocus Implementation Plan

## 1. Current Implementation Status

### Core Features
- **Agentic Scheduler (Gemini AI)**
  - [x] Natural language processing for task scheduling via Google Gemini API (`GeminiCalendarScheduler.swift`).
  - [x] Generates structured JSON schedules based on user input and inferred learning style.
  - [x] Automatically creates/uses a local "SnapFocus" calendar.
  - [x] Saves generated events to Apple Calendar (EventKit).

- **Voice & Assistant Interface**
  - [x] **Voice-First Interaction**: Triggered via global hotkey (`Cmd+Shift+S`).
  - [x] **Glowing Orb UI**: Visual feedback for Listening, Processing, and Success states (`VoiceOverlayView.swift`).
  - [x] **Speech Recognition**: Uses native `SFSpeechRecognizer` for low-latency transcription.
  - [x] **Background App**: Runs as a Menu Bar app (`LSUIElement`) with no Dock icon.
  - [x] **Preferences Window**: Manually managed `NSWindow` accessible from Menu Bar for API Key configuration.

- **Calendar Management**
  - [x] Real-time synchronization with Apple Calendar (`CalendarManager.swift`).
  - [x] **Bulk Time Shift**: Shift all remaining events for the day.
  - [x] **Smart Nudging**: Adjust task duration via keyboard interaction on the Ruler.

- **UI / UX**
  - [x] **Floating Ruler HUD**: Always-on-top timeline visualization.
  - [x] **Window Management**: Integration with Rectangle app.

### Technical Foundation
- [x] **Tech Stack**: SwiftUI, AppKit, Speech, AVFoundation.
- [x] **Permissions**: Calendar, Speech Recognition, Microphone, Audio Input Entitlements.
- [x] **Architecture**: MVVM with `CalendarManager` as central store.

---

## 2. Feature Roadmap

### Phase 1: Robustness & UI Polish
- [x] **Preferences Window**: Fully implement `PreferencesView` for managing the Gemini API Key and other settings securely.
- [ ] **Error Handling**: Better UI feedback for AI generation failures or calendar permission issues.
- [ ] **Ruler Improvements**:
  - Drag-and-drop to move events directly on the ruler.
  - Context menu on events (Delete, Edit Title).

### Phase 2: Enhanced Intelligence
- [ ] **Context-Aware Scheduling**: Pass yesterday's uncompleted tasks to the AI prompt.
- [ ] **Smart Rescheduling**: "I'm running late" button or voice command.
- [ ] **Local LLM Support**: Option to use local models.

### Phase 3: Task & Project Management
- [ ] **Task Backlog**: A "Inbox" for tasks that aren't scheduled yet.
- [ ] **Two-Way Sync**: Robust bi-directional sync with Calendar.

## 3. Known Issues / Todos
- Global Hotkey requires Accessibility permissions (System Settings > Privacy & Security > Accessibility).
- Speech Recognition requires Microphone access and sandbox entitlements.
