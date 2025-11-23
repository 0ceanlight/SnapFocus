# SnapFocus Project Status

## 1. Current Implementation (Verified)

### Core Application
- **Type**: Menu Bar App (`LSUIElement`).
- **Entry Point**: `SnapFocusApp.swift`.
- **Global Hotkey**: `Cmd+Shift+S` (triggers Voice Overlay).
- **Window Management**:
  - `PreferencesView` (API Key configuration).
  - `RulerView` (Always-on-top floating timeline).
  - `VoiceOverlayView` (Transient floating interaction window).

### Features
1. **Agentic Scheduler (Gemini AI)**
   - **File**: `GeminiCalendarScheduler.swift`
   - **Status**: ✅ Implemented
   - **Function**: Takes natural language input (transcript), sends to Gemini `gemini-2.5-flash` (or pro-preview), parses JSON response, and creates events in "SnapFocus" calendar.
   - **Limit**: Currently only schedules for "today" based on immediate input. No context of past tasks.

2.  **Voice Assistant Interface**
    - **File**: `VoiceOverlayView.swift`, `SpeechRecognizer.swift`
    - **Status**: ✅ Implemented
    - **Function**: "Glowing Orb" UI that visualizes listening state. Uses `SFSpeechRecognizer` for real-time transcription.
    - **Flow**: Listen -> Transcribe -> Send to Gemini -> Update Calendar.

3.  **Calendar Management**
    - **File**: `CalendarManager.swift`
    - **Status**: ✅ Implemented
    - **Function**:
      - Syncs with Apple Calendar (EventKit).
      - Creates/Manages "SnapFocus" specific calendar.
      - **Smart Nudging**: Adjusts current task duration via Up/Down arrow keys on the Ruler (shifts subsequent connected tasks).
      - **Bulk Shift**: Capability to shift all remaining daily events (programmatic support exists).

4.  **Floating Ruler HUD**
    - **File**: `RulerView.swift`
    - **Status**: ✅ Implemented
    - **Function**: Visualizes the day's schedule on the side of the screen. Expands on hover.

5.  **Window Tiling (Rectangle)**
    - **File**: `RectangleManager.swift`
    - **Status**: ✅ Implemented (Helper only)
    - **Function**: Sends commands to Rectangle app via URL scheme (`rectangle://`).

---

## 2. Missing / Planned Features (Roadmap)

### Phase 1: Context & Intelligence (Immediate Next Steps)
- [ ] **Context-Aware Scheduling**: Fetch yesterday's uncompleted tasks and include them in the Gemini prompt.
- [ ] **Smart Rescheduling**: Handle "I'm running late" intent specifically (auto-shift current schedule).
- [ ] **Task Backlog/Inbox**: A place to store tasks that aren't scheduled for a specific time yet.

### Phase 2: UI/UX Improvements
- [ ] **Ruler Interactivity**:
  - Drag-and-drop events to reschedule.
  - Right-click context menu (Edit, Delete, Mark Complete).
- [ ] **Error Handling**: Better visual feedback when API keys are missing or requests fail.

### Phase 3: Advanced Tech
- [ ] **Local LLM Support**: Option to use on-device models instead of Gemini API.
- [ ] **Two-Way Sync**: More robust handling of external calendar changes affecting the schedule.

---

## 3. Known Issues
- **Permissions**: Requires explicit accessibility (for hotkey) and screen recording/microphone permissions.
- **Dependencies**: Relies on "Rectangle" app being installed for window management features.

