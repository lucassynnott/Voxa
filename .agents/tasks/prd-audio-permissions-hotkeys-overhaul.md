# PRD: WispFlow Audio, Permissions & Hotkeys Overhaul

## Introduction

This PRD defines a comprehensive overhaul of WispFlow's core systems based on proven patterns from Voquill (an open-source voice-to-text app). The goal is to fix critical reliability issues with audio capture, hotkey detection, and permission handling while adding a polished onboarding experience.

**Key Problems Being Solved:**
- Audio input not detecting from microphones
- Hotkeys not being recognized reliably
- Settings UI elements not clickable/visible
- No guided setup for permissions on first launch
- Clipboard content lost during text insertion

**Reference Implementation:** [Voquill](https://github.com/josiahsrc/voquill) - patterns ported to Swift equivalents.

---

## Goals

- Fix audio capture reliability across all macOS input devices
- Implement smart device selection that avoids low-quality inputs (Bluetooth, AirPods)
- Create robust global hotkey detection that works consistently
- Add guided onboarding wizard for permissions on first launch
- Preserve clipboard content during text insertion
- Improve Settings UI accessibility and interactivity
- Provide real-time audio level preview that actually works

---

## User Stories

### Phase 1: Audio System Overhaul

### [x] US-501: Smart Audio Device Selection
**Description:** As a user, I want WispFlow to automatically select the best available microphone so I don't have to manually configure audio settings.

**Acceptance Criteria:**
- [x] System ranks available input devices by quality score
- [x] Bluetooth devices (AirPods, Beats, etc.) deprioritized automatically
- [x] Devices with sample rate ≤16kHz deprioritized
- [x] Built-in microphone preferred over Bluetooth when both available
- [x] USB/external microphones given highest priority
- [x] Example: MacBook with AirPods connected → selects "MacBook Pro Microphone" not "AirPods Pro"
- [x] Negative case: Only Bluetooth mic available → uses it with warning toast
- [x] Device selection logged to console for debugging
- [x] Typecheck passes (`swift build` succeeds)

### [x] US-502: Audio Device Caching
**Description:** As a user, I want recording to start quickly without device enumeration delay on subsequent recordings.

**Acceptance Criteria:**
- [x] Last successfully used device cached in memory
- [x] Cache used for fast-path device selection on next recording
- [x] Cache invalidated when user manually changes device in Settings
- [x] Cache invalidated when cached device disconnected
- [x] First recording: full enumeration (~100-200ms)
- [x] Subsequent recordings: cached device (~10-20ms)
- [x] Typecheck passes

### [x] US-503: Robust Audio Engine Initialization
**Description:** As a developer, I need the audio engine to initialize reliably regardless of device state.

**Acceptance Criteria:**
- [x] Audio engine reset before each recording session
- [x] Engine prepared before setting input device
- [x] Input device set after engine preparation (audioUnit available)
- [x] Format queried after device is set
- [x] Invalid format (0 sample rate, 0 channels) throws clear error
- [x] Engine connected to muted mixer sink to ensure tap receives data
- [x] Example: Start recording → engine reset → prepare → set device → get format → install tap → start
- [x] Negative case: No input devices → clear error message, not silent failure
- [x] Typecheck passes

### [x] US-504: Audio Level Preview Fix
**Description:** As a user, I want the audio preview in Settings to show my actual microphone levels so I can verify my mic is working.

**Acceptance Criteria:**
- [x] "Start Preview" button triggers audio capture
- [x] Real-time level meter updates at ~20fps during preview
- [x] Level displayed in dB with color coding (green=good, yellow=quiet, red=loud)
- [x] Status text shows "Good", "Quiet", "Too Loud", or "Silent"
- [x] Preview stops cleanly when "Stop Preview" clicked
- [x] Preview stops automatically when leaving Audio settings tab
- [x] Console logs confirm tap callbacks received during preview
- [x] Typecheck passes

### [x] US-505: Low-Quality Device Warning
**Description:** As a user, I want to be warned if I'm using a potentially low-quality audio input so I can switch to a better device.

**Acceptance Criteria:**
- [x] Devices matching low-quality keywords flagged: "airpods", "bluetooth", "beats", "headset", "hfp"
- [x] Warning icon shown next to flagged devices in device picker
- [x] Tooltip explains why device may have poor quality
- [x] Toast notification when recording starts with flagged device
- [x] User can dismiss warning and continue
- [x] Warning does not block recording
- [x] Typecheck passes

---

### Phase 2: Permission System Overhaul

### [x] US-506: Permission Status Tracking
**Description:** As a developer, I need accurate real-time permission status so the UI reflects the current state.

**Acceptance Criteria:**
- [x] Microphone permission checked via `AVCaptureDevice.authorizationStatus`
- [x] Accessibility permission checked via `AXIsProcessTrusted()`
- [x] Permission status polled when app becomes active (user returns from System Settings)
- [x] Status enum: `.authorized`, `.denied`, `.notDetermined`, `.restricted`
- [x] Published properties trigger UI updates on change
- [x] Typecheck passes

### [x] US-507: Automatic Permission Prompting
**Description:** As a user, I want permission dialogs to appear automatically when needed so I don't have to find them in Settings.

**Acceptance Criteria:**
- [x] Microphone permission requested on first recording attempt if `.notDetermined`
- [x] Accessibility permission requested on first text insertion attempt if not trusted
- [x] System permission dialog shown (not custom alert)
- [x] If permission previously denied, open System Settings directly
- [x] Example: First launch → user presses hotkey → mic permission dialog appears
- [x] Typecheck passes

### [x] US-508: Open System Settings Helper
**Description:** As a user, I want to be taken directly to the correct System Settings pane when I need to grant permissions.

**Acceptance Criteria:**
- [x] "Open Settings" button opens Privacy & Security > Microphone pane
- [x] Accessibility settings opens Privacy & Security > Accessibility pane
- [x] Uses URL scheme: `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`
- [x] Works on macOS 13+ (Ventura and later)
- [x] Fallback to general Privacy settings if specific pane fails
- [x] Typecheck passes

### [x] US-509: Permission Status UI
**Description:** As a user, I want to see my current permission status in Settings with clear visual indicators.

**Acceptance Criteria:**
- [x] Microphone permission status shown with icon (✓ green / ✗ red)
- [x] Accessibility permission status shown with icon
- [x] "Grant Permission" button shown when permission not granted
- [x] Button opens appropriate System Settings pane
- [x] Status updates automatically when user grants permission and returns
- [x] Typecheck passes

---

### Phase 3: Hotkey System Overhaul

### [x] US-510: Global Event Tap for Hotkeys
**Description:** As a user, I want hotkeys to work reliably regardless of which app is focused.

**Acceptance Criteria:**
- [x] Global hotkey detection using CGEvent tap (not just Carbon RegisterEventHotKey)
- [x] Event tap installed at `kCGSessionEventTap` level
- [x] Modifier keys detected: Command, Shift, Option, Control
- [x] Default hotkey: Cmd+Shift+Space
- [x] Hotkey works when any application is focused
- [x] Hotkey works even when WispFlow window is not visible
- [x] Example: User in Safari, presses Cmd+Shift+Space → recording starts
- [x] Negative case: Hotkey pressed without accessibility permission → shows permission prompt
- [x] Typecheck passes

### [x] US-511: Hotkey Recording in Settings
**Description:** As a user, I want to customize my hotkey by pressing the key combination I want to use.

**Acceptance Criteria:**
- [x] "Record Hotkey" button in Settings enters recording mode
- [x] Recording mode shows pulsing indicator
- [x] Next key combination with modifier captured as new hotkey
- [x] Escape cancels recording without changing hotkey
- [x] Invalid combinations rejected (modifier-only, no modifier)
- [x] New hotkey persisted to UserDefaults
- [x] Hotkey display shows human-readable format (⌘⇧Space)
- [x] Typecheck passes

### [x] US-512: Hotkey Conflict Detection
**Description:** As a user, I want to be warned if my chosen hotkey conflicts with system shortcuts.

**Acceptance Criteria:**
- [x] Common system shortcuts detected: Cmd+Space (Spotlight), Cmd+Tab, etc.
- [x] Warning shown when conflicting hotkey recorded
- [x] User can proceed despite warning
- [x] "Reset to Default" button restores Cmd+Shift+Space
- [x] Typecheck passes

---

### Phase 4: Text Insertion Improvements

### [x] US-513: Clipboard Preservation
**Description:** As a user, I want my clipboard content preserved when WispFlow inserts text so I don't lose what I copied.

**Acceptance Criteria:**
- [x] Current clipboard content saved before text insertion
- [x] Transcribed text placed on clipboard
- [x] Cmd+V simulated to paste text
- [x] Original clipboard content restored after delay (800ms)
- [x] Restoration happens in background thread
- [x] Example: User has "important text" copied → WispFlow inserts transcription → clipboard returns to "important text"
- [x] Typecheck passes

### [x] US-514: Keyboard Event Simulation
**Description:** As a developer, I need reliable keyboard event simulation for paste operations.

**Acceptance Criteria:**
- [x] Uses CGEvent for key simulation (not AppleScript)
- [x] Key down event with Command modifier
- [x] Small delay between down and up (10ms)
- [x] Key up event with Command modifier
- [x] Events posted to HID event tap location
- [x] Works in all applications including Electron apps
- [x] Typecheck passes

### [x] US-515: Text Insertion Fallback
**Description:** As a user, I want text insertion to work even if keyboard simulation fails.

**Acceptance Criteria:**
- [x] Primary method: Cmd+V paste simulation
- [x] Fallback: Copy to clipboard and show notification to paste manually
- [x] Error logged with details when simulation fails
- [x] User shown toast: "Text copied - press Cmd+V to paste"
- [x] Typecheck passes

---

### Phase 5: Onboarding Wizard

### [x] US-516: First Launch Detection
**Description:** As a developer, I need to detect first launch to show the onboarding wizard.

**Acceptance Criteria:**
- [x] Check UserDefaults for `hasCompletedOnboarding` flag
- [x] First launch: flag is nil or false
- [x] Subsequent launches: flag is true
- [x] Flag only set to true after wizard completed or skipped
- [x] Typecheck passes

### [x] US-517: Onboarding Welcome Screen
**Description:** As a new user, I want a welcome screen that explains what WispFlow does.

**Acceptance Criteria:**
- [x] Welcome screen shown on first launch
- [x] App icon/logo displayed prominently
- [x] Brief description: "Voice-to-text for your Mac"
- [x] Key features listed (3-4 bullet points)
- [x] "Get Started" button advances to next step
- [x] "Skip Setup" link available (not prominent)
- [x] Typecheck passes

### [x] US-518: Microphone Permission Step
**Description:** As a new user, I want guided setup for microphone permission.

**Acceptance Criteria:**
- [x] Screen explains why microphone access is needed
- [x] Current permission status displayed
- [x] "Grant Access" button triggers system permission dialog
- [x] Status updates after permission granted
- [x] "Continue" enabled only after permission granted (or "Skip" always available)
- [x] Illustration/icon showing microphone
- [x] Typecheck passes

### [x] US-519: Accessibility Permission Step
**Description:** As a new user, I want guided setup for accessibility permission.

**Acceptance Criteria:**
- [x] Screen explains why accessibility access is needed (hotkeys + text insertion)
- [x] Current permission status displayed
- [x] "Open System Settings" button opens Accessibility pane
- [x] Instructions: "Enable WispFlow in the list"
- [x] Status updates when user returns to app
- [x] "Continue" enabled only after permission granted (or "Skip" available)
- [x] Typecheck passes

### [x] US-520: Audio Test Step
**Description:** As a new user, I want to test my microphone during setup to ensure it works.

**Acceptance Criteria:**
- [x] Live audio level meter displayed
- [x] "Start Test" button begins audio capture
- [x] Visual feedback shows mic is working
- [x] Device selector dropdown if multiple devices
- [x] "Sounds Good!" button advances when user satisfied
- [x] "Having Issues?" link shows troubleshooting tips
- [x] Typecheck passes

### [x] US-521: Hotkey Introduction Step
**Description:** As a new user, I want to learn and optionally customize the recording hotkey.

**Acceptance Criteria:**
- [x] Current hotkey displayed prominently (⌘⇧Space)
- [x] "Try it now" prompt - user can test hotkey
- [x] Visual feedback when hotkey pressed
- [x] "Change Hotkey" option for customization
- [x] Default hotkey recommended for most users
- [x] Typecheck passes

### [x] US-522: Onboarding Completion
**Description:** As a new user, I want confirmation that setup is complete.

**Acceptance Criteria:**
- [x] Success screen with checkmarks for completed steps
- [x] Brief recap of how to use: "Press ⌘⇧Space to start recording"
- [x] "Start Using WispFlow" button closes wizard
- [x] `hasCompletedOnboarding` flag set to true
- [x] Menu bar icon visible and ready
- [x] Typecheck passes

---

### Phase 6: Settings UI Fixes

### [x] US-523: Fix Tab Visibility
**Description:** As a user, I want to see and click all tabs in the Settings window.

**Acceptance Criteria:**
- [x] All 6 tabs visible: General, Audio, Transcription, Text Cleanup, Text Insertion, Debug
- [x] Tab labels readable (proper contrast)
- [x] Tabs clickable and switch content
- [x] No ZStack/overlay blocking tab bar
- [x] Typecheck passes

### [ ] US-524: Fix Button Interactivity
**Description:** As a user, I want all buttons in Settings to be clickable and responsive.

**Acceptance Criteria:**
- [ ] All buttons respond to clicks
- [ ] Hover states visible on buttons
- [ ] Press animation on click
- [ ] No @State in ButtonStyle causing issues (use separate View)
- [ ] Console logs button actions for debugging
- [ ] Typecheck passes

### [ ] US-525: Fix ScrollView Interactions
**Description:** As a user, I want to scroll through settings and interact with all elements.

**Acceptance Criteria:**
- [ ] ScrollView scrolls smoothly
- [ ] All interactive elements inside cards clickable
- [ ] No hit testing issues with overlays
- [ ] Toggle switches work
- [ ] Dropdown menus open
- [ ] Typecheck passes

---

## Functional Requirements

### Audio System
- **FR-1:** AudioManager must reset engine before each recording session
- **FR-2:** AudioManager must prepare engine before setting input device
- **FR-3:** AudioManager must validate input format (sample rate > 0, channels > 0)
- **FR-4:** AudioManager must connect input to muted mixer sink for tap to receive data
- **FR-5:** AudioManager must cache last successful device for fast subsequent recordings
- **FR-6:** AudioManager must score devices: USB mics > built-in > Bluetooth
- **FR-7:** AudioManager must emit currentAudioLevel at 20Hz during capture

### Permissions
- **FR-8:** App must check microphone permission before recording
- **FR-9:** App must check accessibility permission before hotkey registration
- **FR-10:** App must open specific System Settings pane via URL scheme
- **FR-11:** App must re-check permissions when becoming active

### Hotkeys
- **FR-12:** HotkeyManager must use CGEvent tap for global detection
- **FR-13:** HotkeyManager must require accessibility permission
- **FR-14:** HotkeyManager must support Cmd+Shift+Space as default
- **FR-15:** HotkeyManager must persist custom hotkey to UserDefaults

### Text Insertion
- **FR-16:** TextInserter must save clipboard before insertion
- **FR-17:** TextInserter must restore clipboard after 800ms delay
- **FR-18:** TextInserter must use CGEvent for Cmd+V simulation
- **FR-19:** TextInserter must provide fallback notification on failure

### Onboarding
- **FR-20:** App must show onboarding wizard on first launch
- **FR-21:** Onboarding must guide through microphone permission
- **FR-22:** Onboarding must guide through accessibility permission
- **FR-23:** Onboarding must include audio test step
- **FR-24:** Onboarding must set completion flag in UserDefaults

---

## Non-Goals (Out of Scope)

- **No cross-platform support** - This PRD is macOS only
- **No Rust/Swift bridge** - Pure Swift implementation
- **No screen context extraction** - Advanced accessibility features deferred
- **No real-time transcription streaming** - Batch transcription only
- **No cloud-based audio processing** - Local Whisper only
- **No multi-language onboarding** - English only for now
- **No automatic updates** - Manual updates via GitHub releases

---

## Technical Considerations

### Audio Architecture
- Use `AVAudioEngine` with proper initialization sequence
- Install tap on input node with buffer size 4096
- Convert to 16kHz mono for Whisper
- Use `AVAudioMixerNode` as sink to ensure tap receives data

### Permission APIs
- `AVCaptureDevice.authorizationStatus(for: .audio)` for microphone
- `AXIsProcessTrusted()` for accessibility
- `AXIsProcessTrustedWithOptions()` with prompt for first request
- `NSWorkspace.shared.open(URL)` for System Settings

### Hotkey Implementation
- `CGEvent.tapCreate()` for global event monitoring
- `CGEventTapLocation.cgSessionEventTap` for user session events
- `CGEventMask` for key down events
- Run loop source for event processing

### SwiftUI Considerations
- Avoid `@State` directly in `ButtonStyle` - use wrapper View
- Use `contentShape(Rectangle())` for hit testing
- Avoid `ZStack` overlays that block interaction
- Test all UI interactions after each change

---

## Success Metrics

- **Audio capture success rate:** 95%+ of recordings capture actual audio
- **Hotkey reliability:** 99%+ of hotkey presses detected
- **Permission setup completion:** 80%+ of new users complete onboarding
- **Settings usability:** All buttons/toggles clickable on first try
- **Time to first transcription:** < 2 minutes for new users with onboarding

---

## Open Questions

1. Should we add a "Test Recording" feature in Settings (record → playback)?
2. Should onboarding include Whisper model download or defer to first use?
3. Should we add keyboard shortcut hints in the UI (tooltips)?
4. Should we persist audio device preference across app restarts?
5. Should we add a system tray notification when hotkey is pressed?

---

## Implementation Order

**Recommended sequence:**

1. **US-523, US-524, US-525** - Fix Settings UI first (unblocks testing)
2. **US-503, US-504** - Fix audio engine initialization and preview
3. **US-501, US-502** - Smart device selection and caching
4. **US-506, US-507, US-508** - Permission system
5. **US-510, US-511** - Hotkey overhaul
6. **US-513, US-514** - Clipboard preservation
7. **US-516 through US-522** - Onboarding wizard (last, uses all other systems)

---

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.

---

## Appendix: Voquill Reference Code

Key files analyzed from Voquill (Rust/Tauri):
- `platform/macos/permissions.rs` - Permission handling patterns
- `platform/macos/input.rs` - Keyboard simulation via CGEvent
- `platform/macos/accessibility.rs` - AX API usage
- `platform/audio.rs` - Audio device selection and recording
- `platform/keyboard.rs` - Global key event monitoring
- `domain/recording.rs` - Recording state management

All patterns to be ported to Swift equivalents using:
- AVFoundation for audio
- ApplicationServices for accessibility
- CoreGraphics for event simulation
- AppKit for UI and permissions
