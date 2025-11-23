# SnapFocus Project Status

## 🟢 Current Implementation
The core "MVP" of SnapFocus is functional. The application runs as a menu bar utility with an always-on-top floating ruler.

### 1. Agentic Scheduling (Voice & AI)
- **Voice Input:** Global hotkey triggers a floating "Orb" overlay (`VoiceOverlayView`) that records speech.
- **AI Processing:** Uses Google Gemini (`gemini-2.5-flash`) to parse natural language into structured schedule data (`GeminiCalendarScheduler`).
- **Calendar Sync:** Automatically creates a "SnapFocus" local calendar and saves generated events to Apple Calendar.
- **Feedback Loop:** Visual states for Listening, Processing, Success, and Error.

### 2. Visual Ruler (Timeline HUD)
- **Always-on-Top:** A vertical sidebar (`RulerView`) visualizes the day's schedule.
- **Dynamic Resizing:** Expands on hover to show details; collapses to a thin bar to save space.
- **Time Tracking:** A "Now" line moves in real-time.
- **Keyboard Interaction:**
  - **Nudge:** While hovering, `Up`/`Down` arrow keys adjust the duration of the *current* task (±5 mins).
- **Details:** Clicking an event block shows a popover with start/end times.

### 3. App Structure & Settings
- **Menu Bar App:** Runs in the background with no Dock icon.
- **Preferences:** Secure storage for the Gemini API Key via a dedicated settings window.
- **Permissions:** Handles Calendar and Microphone access.

---

## 🚀 Development Roadmap
We will add the following features step-by-step to evolve from a "scheduler" to a complete "focus OS".

### Step 1: Enhanced Ruler Interaction (UI Polish)
*Goal: Make the timeline fully interactive with the mouse.*
- [ ] **Drag & Drop:** Allow dragging event blocks vertically to reschedule them.
- [ ] **Context Menus:** Right-click an event to "Delete", "Edit Title", or "Mark Complete".
- [ ] **Visual Feedback:** Better animations when shifting time (e.g., ghost outlines).

### Step 2: Robustness & Error Handling
*Goal: Make the app fail gracefully and inform the user.*
- [ ] **API Validation:** Check if the Gemini API key is valid immediately upon saving.
- [ ] **Detailed Error UI:** Show specific errors in the Voice Overlay (e.g., "Calendar Access Denied" vs "AI Error").
- [ ] **Onboarding:** A welcome screen to guide the user through permissions and hotkey setup.

### Step 3: Intelligent Context (The "Agentic" Part)
*Goal: The AI should know more about you than just the current command.*
- [ ] **History Awareness:** Pass yesterday's uncompleted tasks to the prompt.
- [ ] **Smart Rescheduling:** Add a "I'm running late" command that shifts all future events by X minutes.
- [ ] **Conflict Resolution:** If the AI suggests a time that overlaps with an existing *locked* meeting, ask the user for clarification.

### Step 4: Task Management Integration
*Goal: Bridge the gap between a todo list and a calendar.*
- [ ] **Inbox / Backlog:** A side panel for tasks that aren't scheduled yet.
- [ ] **Draggable Tasks:** Drag items from the Inbox onto the Ruler to schedule them.

### Step 5: Local Processing (Privacy)
- [ ] **Local LLM Support:** Investigate running a small model (e.g., Llama 3 8B via MLX) for offline scheduling.
