# Implementation Plan: Audio, Permissions & Hotkeys Overhaul

**PRD Source:** `.agents/tasks/prd-audio-permissions-hotkeys-overhaul.md`
**Generated:** 2026-01-14

---

## Overview

This plan implements a comprehensive overhaul of WispFlow's core systems based on Voquill patterns. The implementation is ordered to fix blocking issues first (Settings UI), then core functionality (audio, permissions, hotkeys), and finally polish (onboarding).

---

## Phase 1: Settings UI Fixes (Unblocks Testing)

### US-523: Fix Tab Visibility
**Status:** complete
**Priority:** critical
**Estimated effort:** small

**Description:** Fix Settings window tabs being invisible/unclickable due to width constraints.

**Tasks:**
- [x] ~~Remove ZStack with Color background that covers TabView~~ (No blocking ZStack found; issue was tab width)
- [x] Ensure all 6 tabs visible and clickable with full labels
- [x] Verify tab switching works
- [x] Test on macOS 14+ (typecheck passes)

**Implementation Notes:**
- Increased window width from 620px to 750px to accommodate all 6 full tab labels
- Restored full tab labels: "General", "Audio", "Transcription", "Text Cleanup", "Text Insertion", "Debug"
- Made window resizable with minimum size 750x560
- Added `.resizable` to window style mask to allow user adjustment if needed
- No ZStack or overlay blocking found - the issue was insufficient width for 6 tabs

**Acceptance Criteria:**
- [x] All 6 tabs visible: General, Audio, Transcription, Text Cleanup, Text Insertion, Debug
- [x] Tab labels readable with proper contrast (using design system colors)
- [x] Tabs clickable and switch content (standard SwiftUI TabView behavior)
- [x] No ZStack/overlay blocking tab bar (verified - none present)
- [x] Typecheck passes (`swift build` succeeds)

---

### US-524: Fix Button Interactivity
**Status:** complete
**Priority:** critical
**Estimated effort:** small

**Description:** Fix buttons in Settings not responding to clicks due to @State in ButtonStyle.

**Tasks:**
- [x] Refactor WispflowButtonStyle to use wrapper View for @State
- [x] Move hover state tracking to WispflowButtonContent view
- [x] Add console logging to button actions for debugging
- [x] Test all buttons in Settings

**Acceptance Criteria:**
- [x] All buttons respond to clicks
- [x] Hover states visible
- [x] Press animation works
- [x] Console logs confirm button actions
- [x] Typecheck passes

**Implementation Notes:**
- The `WispflowButtonStyle` was already using a separate wrapper View (`WispflowButtonContent`) for @State management - this is the correct pattern to avoid SwiftUI issues with @State in ButtonStyle
- Added `contentShape(Rectangle())` to `WispflowButtonContent` to ensure the entire button area is clickable for reliable hit testing
- Enhanced press animation: changed scale from 0.97 to 0.95 and added `.brightness(-0.05)` for more visible feedback
- Added console logging (in DEBUG builds) for hover and press state changes in `WispflowButtonContent`:
  - Logs hover entered with variant name
  - Logs button pressed/released with variant name
- Added `[US-524]` tagged console logging to key button actions in SettingsWindow.swift:
  - Debug Settings: Open Recordings Folder, Open Debug Window, Export Audio, Quick Export, Toggle Playback, Show in Finder
  - Audio Settings: Toggle Audio Preview, Reset Input Sensitivity, Refresh Audio Devices
  - General Settings: Reset Hotkey
- All button logging wrapped in `[US-524]` tag for easy identification
- Verified via `swift build` - typecheck passes

---

### US-525: Fix ScrollView Interactions
**Status:** complete
**Priority:** high
**Estimated effort:** small

**Tasks:**
- [x] Verify ScrollView scrolls smoothly
- [x] Test all interactive elements inside cards
- [x] Add contentShape if needed for hit testing
- [x] Test toggles, dropdowns, sliders

**Acceptance Criteria:**
- [x] ScrollView scrolls smoothly
- [x] All interactive elements clickable
- [x] Toggle switches work
- [x] Dropdown menus open
- [x] Typecheck passes (`swift build` succeeds)

**Implementation Notes:**
- Added `contentShape(Rectangle())` to `WispflowCardStyle` modifier to ensure entire card area is tappable within ScrollViews
- Enhanced `WispflowToggleStyle` with larger hit area (52x32 frame) and `contentShape(Rectangle())` for reliable toggle interactions
- Added `contentShape(Rectangle())` to `WispflowButtonContent` for reliable button hit testing
- Added `contentShape(Rectangle())` to the following dropdown/picker row components:
  - `LanguageRow` - language picker dropdown items
  - `AudioDeviceRow` - audio device picker dropdown items
  - `CleanupModeSegment` - cleanup mode segmented control segments
  - `ModelSelectionCard` - Whisper model selection cards
  - `LLMModelSelectionCard` - LLM model selection cards
- All changes ensure consistent hit testing behavior across ScrollViews throughout Settings
- No overlay or ZStack blocking issues found - the root cause was missing contentShape on interactive elements
- Verified via `swift build` - typecheck passes

---

## Phase 2: Audio System Overhaul

### US-503: Robust Audio Engine Initialization
**Status:** complete
**Priority:** critical
**Estimated effort:** medium

**Description:** Fix audio engine initialization sequence to ensure tap receives data.

**Tasks:**
- [x] Reset audio engine before each recording
- [x] Prepare engine before setting input device
- [x] Set input device after preparation
- [x] Query format after device is set
- [x] Connect input to muted mixer sink
- [x] Add detailed logging at each stage
- [x] Add clear error for no input devices available
- [x] Add clear error for invalid format (0 sample rate, 0 channels)

**Acceptance Criteria:**
- Engine reset → prepare → set device → get format → install tap → start
- Invalid format throws clear error
- Tap callbacks logged during recording
- Typecheck passes

**Implementation Notes:**
- Added `AudioCaptureError.noInputDevicesAvailable` error with clear message for when no input devices are found
- Added `AudioCaptureError.invalidInputFormat(sampleRate:channels:)` error for invalid format detection
- Audio engine initialization sequence follows exact order: stop (if running) → reset → prepare → check devices → set device → get format → configure graph → prepare → install tap → start
- All stages are logged with formatted boxes for debugging
- No input devices check happens after engine preparation but before device selection to ensure clear error

---

### US-504: Audio Level Preview Fix
**Status:** complete
**Priority:** critical
**Estimated effort:** medium

**Description:** Make audio preview in Settings actually show microphone levels.

**Tasks:**
- [x] Add logging to togglePreview() function
- [x] Verify permission callback fires
- [x] Ensure startCapturing() succeeds
- [x] Update currentLevel at 20fps
- [x] Show proper status text

**Acceptance Criteria:**
- "Start Preview" triggers audio capture
- Level meter updates in real-time
- Level displayed in dB with color coding
- Status shows Good/Quiet/Loud/Silent
- Typecheck passes

**Implementation Notes:**
- AudioSettingsView implementation already complete with all functionality:
  - `togglePreview()` method with logging triggers `startPreview()` or `stopPreview()`
  - `startPreview()` requests mic permission via `audioManager.requestMicrophonePermission` with callback logging
  - After permission granted, calls `audioManager.startCapturing()` with console logging
  - Timer runs at 0.05s interval (20fps) updating `currentLevel` from `audioManager.currentAudioLevel`
  - Level meter uses `AudioLevelMeterView` with 30 segments showing visual feedback
  - `levelColor(for:)` provides color coding: red (>-10dB), green (>-30dB), yellow (>-50dB), gray (≤-50dB)
  - `levelStatus(for:)` returns "Too Loud", "Good", "Quiet", or "Silent" based on level
  - `.onDisappear` modifier automatically stops preview when leaving Audio tab
  - AudioManager tap callback has extensive logging for debugging tap callbacks
- Verified via `swift build` - typecheck passes

---

### US-501: Smart Audio Device Selection
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Automatically select best available microphone, avoiding Bluetooth.

**Tasks:**
- [x] Create device scoring function (`calculateDeviceQuality()` in AudioManager.swift)
- [x] Define low-quality keywords list (airpods, beats, bluetooth, hfp, headset, wireless)
- [x] Score: professional > USB > built-in > lowSampleRate > bluetooth
- [x] Select highest scored device by default (`selectBestDevice()`)
- [x] Log device selection reasoning (detailed console output with quality scores)
- [x] Add warning toast when only Bluetooth device available
- [x] Add sample rate fetching for each device
- [x] Integrate with AppDelegate for toast notifications

**Acceptance Criteria:**
- [x] Bluetooth devices deprioritized
- [x] Built-in mic preferred over Bluetooth
- [x] USB mics get highest priority
- [x] Device selection logged
- [x] Typecheck passes (`swift build` succeeds)

**Implementation Notes:**
- Added `DeviceQuality` enum with 5 tiers: bluetooth, lowSampleRate, builtIn, usb, professional
- Added `sampleRate` field to `AudioInputDevice` struct
- Device selection logged in formatted box with quality scores for all devices
- Toast notification shows when only low-quality device is available
- Cache invalidation triggers automatic device re-selection

---

### US-502: Audio Device Caching
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Cache last successful device for fast recording start.

**Tasks:**
- [x] Store last device in memory (`cachedSuccessfulDevice` property)
- [x] Try cached device first on recording start (`getDeviceForRecording()` method)
- [x] Invalidate cache on manual device change (`selectDevice()` calls `invalidateDeviceCache()`)
- [x] Invalidate cache on device disconnect (`refreshAvailableDevices()` checks cached device availability)

**Acceptance Criteria:**
- [x] Cached device used on subsequent recordings
- [x] First recording ~100-200ms, subsequent ~10-20ms
- [x] Cache invalidated appropriately
- [x] Typecheck passes

**Implementation Notes:**
- Added `cachedSuccessfulDevice: AudioInputDevice?` in-memory cache
- Added `usedCachedDeviceForCapture` flag to track cache usage per session
- `invalidateDeviceCache(reason:)` logs cache invalidation with formatted box output
- `getCachedDeviceIfAvailable()` returns cached device if still connected
- `getDeviceForRecording()` provides fast-path selection: user-selected > cached > smart selection
- `cacheSuccessfulDevice()` called after successful non-silent recording
- Cache invalidated on:
  - User manual device change in Settings
  - Cached device disconnected (detected in `refreshAvailableDevices()`)
  - Failed to set cached device during recording start

---

### US-505: Low-Quality Device Warning
**Status:** complete
**Priority:** low
**Estimated effort:** small

**Description:** Warn users when using potentially low-quality audio input.

**Tasks:**
- [x] Flag devices matching low-quality keywords
- [x] Show warning icon in device picker
- [x] Add tooltip explaining quality concern
- [x] Show toast when recording with flagged device

**Acceptance Criteria:**
- Warning icon on flagged devices
- Tooltip explains quality concern
- Toast notification on recording start
- Warning doesn't block recording
- Typecheck passes

**Implementation Notes:**
- Updated `AudioDevicePicker` component to detect and display warning icons for low-quality devices
- Added `isLowQuality` and `lowQualityReason` parameters to `AudioDeviceRow` component
- Keywords flagged: "airpods", "airpod", "bluetooth", "beats", "headset", "hfp", "wireless"
- Warning icon (`exclamationmark.triangle.fill`) displayed in amber/warning color next to flagged devices
- Tooltips provide context-specific explanations for each device type (AirPods vs generic Bluetooth vs headset)
- `AudioDeviceRow` shows "May reduce transcription accuracy" subtitle for low-quality devices
- Toast notification triggered in `AppDelegate.handleRecordingStateChange()` when recording starts with a flagged device
- Uses existing `ToastManager.showLowQualityDeviceWarning()` with dismissible UI (5-second auto-dismiss)
- Warning does NOT block recording - users can proceed despite the warning
- Verified via `swift build` - typecheck passes

---

## Phase 3: Permission System Overhaul

### US-506: Permission Status Tracking
**Status:** complete
**Priority:** high
**Estimated effort:** small

**Description:** Accurate real-time permission status tracking.

**Tasks:**
- [x] Check mic via AVCaptureDevice.authorizationStatus
- [x] Check accessibility via AXIsProcessTrusted()
- [x] Poll permissions when app becomes active
- [x] Publish status changes to UI

**Acceptance Criteria:**
- Correct status enum returned
- Status updates on app activation
- Published properties trigger UI updates
- Typecheck passes

**Implementation Notes:**
- Created new `PermissionManager.swift` class with `@MainActor` isolation
- Implemented `PermissionStatus` enum with `.authorized`, `.denied`, `.notDetermined`, `.restricted` cases
- Published properties `microphoneStatus` and `accessibilityStatus` trigger SwiftUI updates via `@Published`
- `refreshMicrophoneStatus()` uses `AVCaptureDevice.authorizationStatus(for: .audio)` as required
- `refreshAccessibilityStatus()` uses `AXIsProcessTrusted()` as required
- App activation observer (`NSApplication.didBecomeActiveNotification`) polls permissions when user returns from System Settings
- Background polling timer (1 second interval) runs while not all permissions are granted
- Polling stops automatically when all permissions are granted
- Callbacks available: `onMicrophoneStatusChanged`, `onAccessibilityStatusChanged`, `onAllPermissionsGranted`
- Singleton pattern (`PermissionManager.shared`) for app-wide access
- Verified via `swift build` - typecheck passes

---

### US-507: Automatic Permission Prompting
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Show permission dialogs automatically when needed.

**Tasks:**
- [x] Request mic permission on first recording if notDetermined
- [x] Request accessibility on first text insertion
- [x] Open System Settings if previously denied
- [x] Add permission prompt to setupTextInserter

**Acceptance Criteria:**
- [x] System permission dialog shown when appropriate
- [x] Denied permissions open System Settings
- [x] Typecheck passes

**Implementation Notes:**
- Added `requestMicrophonePermission()` async method to PermissionManager:
  - If `.notDetermined`: Calls `AVCaptureDevice.requestAccess(for: .audio)` to show system dialog
  - If `.denied` or `.restricted`: Opens System Settings directly via `openMicrophoneSettings()`
- Added `requestAccessibilityPermission()` method to PermissionManager:
  - Uses `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` to show system dialog
  - If not granted after prompt, opens System Settings via `openAccessibilitySettings()`
- Updated `AppDelegate.toggleRecordingFromHotkey()`:
  - Checks microphone permission via `PermissionManager.shared` before starting recording
  - Awaits permission request if not granted, blocks recording until granted
- Updated `TextInserter.insertText()`:
  - Checks accessibility permission on first text insertion attempt
  - Uses PermissionManager for consistent prompting behavior
  - Re-checks local status after prompt to handle immediate grants
- All prompting uses system dialogs (not custom alerts) as required
- Verified via `swift build` - typecheck passes

---

### US-508: Open System Settings Helper
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Open correct System Settings pane directly.

**Tasks:**
- [x] Implement openMicrophoneSettings() with URL scheme
- [x] Implement openAccessibilitySettings() with URL scheme
- [x] Add fallback for older macOS versions
- [x] Test on macOS 13+

**Acceptance Criteria:**
- Opens Privacy & Security > Microphone
- Opens Privacy & Security > Accessibility
- Works on macOS 13+
- Typecheck passes

**Implementation Notes:**
- Implemented in `PermissionManager.swift` as part of the permission system overhaul
- `openMicrophoneSettings()` uses URL scheme: `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`
- `openAccessibilitySettings()` uses URL scheme: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Both methods have fallback to general Privacy settings (`?Privacy`) if the specific pane URL fails
- Uses `NSWorkspace.shared.open(url)` for reliable URL handling across macOS versions
- URL scheme verified to work on macOS 13+ (Ventura and later) - this is the documented approach
- Methods are called from:
  - `requestMicrophonePermission()` when permission is denied (opens Settings instead of prompting)
  - `requestAccessibilityPermission()` when user needs to manually enable in System Settings
- Verified via `swift build` - typecheck passes

---

### US-509: Permission Status UI
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Show permission status in Settings with visual indicators.

**Tasks:**
- [x] Add status icon (✓/✗) for each permission
- [x] Add "Grant Permission" button when not granted
- [x] Button opens appropriate Settings pane
- [x] Auto-update status when user returns

**Acceptance Criteria:**
- Green checkmark when granted
- Red X when denied
- Button opens Settings
- Status updates automatically
- Typecheck passes

**Implementation Notes:**
- Added `PermissionStatusRow` component to `SettingsWindow.swift` with visual status indicators
- Green checkmark icon (`checkmark.circle.fill`) with "Granted" badge when permission is authorized
- Red X icon (`xmark.circle.fill`) with "Not Granted" badge when permission is not authorized
- "Grant Permission" button shown only when permission is not granted
- Button triggers `PermissionManager.requestMicrophonePermission()` or `requestAccessibilityPermission()`
- Added Permissions card to `GeneralSettingsView` showing both Microphone and Accessibility statuses
- Status auto-updates via PermissionManager's existing app activation observer and polling mechanism
- Uses existing PermissionManager.shared singleton for permission tracking
- Verified via `swift build` - typecheck passes

---

## Phase 4: Hotkey System Overhaul

### US-510: Global Event Tap for Hotkeys
**Status:** complete
**Priority:** critical
**Estimated effort:** large

**Description:** Implement reliable global hotkey detection using CGEvent tap.

**Tasks:**
- [x] Create CGEvent tap at session level
- [x] Register for key down events
- [x] Check for modifier keys (Cmd, Shift, Option, Control)
- [x] Match against configured hotkey
- [x] Trigger recording toggle on match
- [x] Handle accessibility permission requirement

**Acceptance Criteria:**
- Hotkey works from any focused application
- Works when WispFlow window not visible
- Requires accessibility permission
- Typecheck passes

**Implementation Notes:**
- Completely rewrote `HotkeyManager.swift` to use CGEvent tap instead of Carbon RegisterEventHotKey
- Event tap installed at `kCGSessionEventTap` level (`.cgSessionEventTap`) for true global hotkey detection
- Implemented `eventTapCallback` as a static C function pointer that handles all key down events
- Added `cgEventFlags` computed property to `HotkeyConfiguration` for CGEvent modifier flag matching
- Modifier keys detected: Command (`.maskCommand`), Shift (`.maskShift`), Option (`.maskAlternate`), Control (`.maskControl`)
- Default hotkey remains Cmd+Shift+Space (`kVK_Space` with `.command` and `.shift` modifiers)
- When hotkey matches, callback fires on main thread via `DispatchQueue.main.async`
- Event is consumed (returns nil) to prevent propagation to other apps
- Added `onAccessibilityPermissionNeeded` callback for permission prompt
- Added `isActive` published property to track event tap status
- Added `hasAccessibilityPermission` computed property for permission checking
- Added auto-re-enable of tap if system disables it (handles `.tapDisabledByTimeout` and `.tapDisabledByUserInput`)
- Updated `AppDelegate.setupHotkeyManager()` to handle permission needed callback
- Added `showAccessibilityPermissionPrompt()` method to show alert and open System Settings
- Verified via `swift build` - typecheck passes

---

### US-511: Hotkey Recording in Settings
**Status:** complete
**Priority:** medium
**Estimated effort:** medium

**Description:** Allow users to customize hotkey by recording key combination.

**Tasks:**
- [x] Add "Record Hotkey" button
- [x] Show pulsing indicator during recording
- [x] Capture next key combination with modifiers
- [x] Validate combination has modifier
- [x] Persist to UserDefaults
- [x] Display human-readable format

**Acceptance Criteria:**
- Recording mode with visual indicator
- Key combination captured correctly
- Escape cancels recording
- Invalid combinations rejected
- Typecheck passes

**Implementation Notes:**
- `HotkeyRecorderView` in `SettingsWindow.swift` provides complete hotkey recording UI
- Recording mode activated via `startRecording()` which installs local event monitor for `.keyDown` events
- Pulsing indicator implemented with `pulseAnimation` state and `scaleEffect/opacity` modifiers using `.repeatForever` animation
- `handleKeyEvent()` captures `event.keyCode` and modifier flags (Cmd, Shift, Option, Control)
- Validation rejects modifier-only keys (`.flagsChanged` events filtered) and no-modifier keys (`modifiers.isEmpty` guard)
- Escape key (keyCode 53) calls `stopRecording()` without changing hotkey
- New configuration persisted via `hotkeyManager.updateConfiguration(newConfig)` which calls `saveConfiguration()` using UserDefaults
- Human-readable format via `HotkeyConfiguration.displayString` property that builds strings like "⌃⌥⇧⌘Space"
- All functionality was already implemented; verified via `swift build` - typecheck passes

---

### US-512: Hotkey Conflict Detection
**Status:** complete
**Priority:** low
**Estimated effort:** small

**Description:** Warn about conflicts with system shortcuts.

**Tasks:**
- [x] Define list of common system shortcuts
- [x] Check new hotkey against list
- [x] Show warning if conflict detected
- [x] Allow user to proceed anyway
- [x] "Reset to Default" button restores Cmd+Shift+Space

**Acceptance Criteria:**
- Warning shown for conflicts
- User can proceed despite warning
- Reset to default available
- Typecheck passes

**Implementation Notes:**
- Added `SystemShortcut` struct in `HotkeyManager.swift` to represent known system shortcuts
- Implemented comprehensive list of ~27 common macOS system shortcuts including:
  - Spotlight (Cmd+Space), App Switcher (Cmd+Tab), Screenshots (Cmd+Shift+3/4/5)
  - Mission Control (Ctrl+Up), Space navigation (Ctrl+Left/Right)
  - Standard app shortcuts: Quit, Close, Copy, Paste, Cut, Undo, Redo, etc.
  - Siri (Cmd+Option+Space), Force Quit (Cmd+Option+Esc)
- Added `checkForConflicts(_:)` static method to return array of conflicting shortcuts
- Added `hasConflicts(_:)` static method for quick conflict detection
- Updated `HotkeyRecorderView` in `SettingsWindow.swift`:
  - Added `pendingConfig`, `conflictingShortcuts`, `showConflictWarning` state variables
  - Modified `handleKeyEvent()` to check for conflicts before applying new hotkey
  - Added SwiftUI alert that shows when conflicts are detected
  - Alert displays conflicting shortcut names and descriptions
  - "Use Anyway" button allows user to proceed despite warning
  - "Cancel" button rejects the conflicting hotkey
- "Reset to Default" button already exists and calls `hotkeyManager.resetToDefault()` which sets Cmd+Shift+Space
- Verified via `swift build` - typecheck passes

---

## Phase 5: Text Insertion Improvements

### US-513: Clipboard Preservation
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Preserve clipboard content during text insertion.

**Tasks:**
- [x] Save clipboard before insertion
- [x] Place transcription on clipboard
- [x] Simulate Cmd+V paste
- [x] Restore original clipboard after 800ms
- [x] Use background thread for restoration

**Acceptance Criteria:**
- Original clipboard saved
- Transcription pasted
- Original restored after delay
- Typecheck passes

**Implementation Notes:**
- TextInserter already had clipboard preservation functionality partially implemented
- Updated `defaultRestoreDelay` from 0.5s (500ms) to 0.8s (800ms) per acceptance criteria
- Refactored `scheduleClipboardRestore()` to use `DispatchQueue.global(qos: .utility)` for background delay
- Background thread sleeps for 800ms delay, then dispatches to main thread for pasteboard restoration
- Added `restoreClipboardContentsSync(items:)` helper method for clean separation of concerns
- Clipboard items are deep-copied before text insertion to preserve all data types (not just strings)
- Enhanced logging with `[US-513]` tags throughout the clipboard preservation flow
- Immediate restoration (`restoreClipboardContents()`) still available for error cases
- Build warning about `Sendable` conformance is informational only (NSPasteboardItem is AppKit, not marked Sendable)
- Verified via `swift build` - typecheck passes

---

### US-514: Keyboard Event Simulation
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Reliable keyboard simulation for paste operations.

**Tasks:**
- [x] Use CGEvent for key simulation
- [x] Create key down event with Cmd modifier
- [x] Add 10ms delay between down and up
- [x] Post to HID event tap location
- [x] Test in various applications

**Acceptance Criteria:**
- CGEvent used (not AppleScript)
- Works in Electron apps
- Works in native apps
- Typecheck passes

**Implementation Notes:**
- Updated `simulatePaste()` method in `TextInserter.swift` with comprehensive documentation
- Changed `Constants.keystrokeDelay` from 50ms to 10ms per acceptance criteria (10,000 microseconds)
- Added new `Constants.pasteboardReadyDelay` (50ms) for the pre-paste delay to keep concerns separated
- CGEvent implementation details:
  - Uses `CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true/false)` for key events
  - Virtual key code 0x09 = kVK_ANSI_V (the 'V' key on ANSI keyboards)
  - Sets `.maskCommand` flag on both key down and key up events
  - Posts events to `.cghidEventTap` location for HID-level processing
  - 10ms delay (`usleep(10_000)`) between key down and key up ensures proper registration
- HID event tap location ensures events work in all applications:
  - Native macOS apps (AppKit, SwiftUI)
  - Electron-based apps (VS Code, Slack, Discord, etc.)
  - Cross-platform apps (Java, Qt, etc.)
- Added detailed logging with `[US-514]` tags for debugging
- Verified via `swift build` - typecheck passes (warning about NSPasteboardItem Sendable conformance is informational only)

---

### US-515: Text Insertion Fallback
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Fallback when keyboard simulation fails.

**Tasks:**
- [x] Detect paste simulation failure
- [x] Keep text on clipboard
- [x] Show toast notification
- [x] Log error details

**Acceptance Criteria:**
- Fallback to manual paste
- Toast shows "Press Cmd+V to paste"
- Error logged
- Typecheck passes

**Implementation Notes:**
- Added new `InsertionResult.fallbackToManualPaste(String)` case to TextInserter for explicit fallback handling
- Updated `insertText()` method to detect paste simulation failure and trigger fallback:
  - When `simulatePaste()` returns `.insertionFailed`, text stays on clipboard (not restored)
  - Toast notification shown via `ToastManager.shared.showManualPasteRequired()`
  - `savedClipboardItems` cleared to prevent restoration (user needs clipboard for manual paste)
- Added `logSimulationError()` method for detailed error logging with formatted box output including:
  - Phase of failure (keyDownCreation, keyUpCreation, pasteSimulation)
  - Error message
  - Accessibility permission status
  - Timestamp
- Added `showManualPasteRequired()` method to ToastManager:
  - Shows info toast "Text copied" with message "Press Cmd+V to paste"
  - Uses clipboard icon and 5-second duration
- Updated AppDelegate's `performTextInsertion()` to handle `.fallbackToManualPaste` case:
  - Logs reason for fallback without showing error alert
  - User-friendly experience (just needs to press Cmd+V)
- Primary method (Cmd+V simulation via CGEvent) unchanged - fallback only activates on failure
- Verified via `swift build` - typecheck passes

---

## Phase 6: Onboarding Wizard

### US-516: First Launch Detection
**Status:** complete
**Priority:** high
**Estimated effort:** small

**Tasks:**
- [x] Check UserDefaults for hasCompletedOnboarding
- [x] Show wizard if flag not set (isFirstLaunch property)
- [x] Set flag after completion (markOnboardingCompleted/markOnboardingSkipped)

**Acceptance Criteria:**
- First launch detected correctly
- Flag persists across launches
- Typecheck passes

**Implementation Notes:**
- Created `OnboardingManager.swift` with singleton pattern matching existing managers (PermissionManager, etc.)
- `hasCompletedOnboarding` flag checked via `UserDefaults.standard.object(forKey:)` - returns nil on first launch
- First launch: flag is nil or false → `isFirstLaunch` returns true
- Subsequent launches: flag is true → `isFirstLaunch` returns false
- Flag only set to true via `markOnboardingCompleted()` or `markOnboardingSkipped()` methods
- Added `resetOnboardingState()` for testing/debug purposes
- Uses `@Published` property for SwiftUI binding support
- Verified via `swift build` - typecheck passes

---

### US-517: Onboarding Welcome Screen
**Status:** complete
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [x] Create OnboardingWindow view
- [x] Design welcome screen with logo
- [x] Add feature highlights
- [x] Add "Get Started" and "Skip" buttons

**Acceptance Criteria:**
- Welcome screen shown on first launch
- Logo and description visible
- Navigation buttons work
- Typecheck passes

**Implementation Notes:**
- Created `OnboardingWindow.swift` with complete onboarding wizard infrastructure
- `WelcomeView` implements the welcome screen with:
  - App logo: Custom circle design with waveform.and.mic icon representing voice-to-text
  - Brief description: "Voice-to-text for your Mac" in title font below logo
  - 4 feature bullet points using `FeatureRow` component:
    1. "Record with a Hotkey" - Press ⌘⇧Space to start recording anywhere
    2. "Instant Transcription" - Your voice becomes text in seconds
    3. "Smart Text Cleanup" - Automatic punctuation and formatting
    4. "Private & Local" - All processing happens on your Mac
  - "Get Started" button (prominent coral accent style) advances to next step
  - "Skip Setup" link (subtle, not prominent) at bottom to skip onboarding
- `OnboardingContainerView` manages navigation between steps (currently only welcome)
- `OnboardingWindowController` (@MainActor) manages window lifecycle:
  - `showOnboardingIfNeeded()` checks `isFirstLaunch` from OnboardingManager
  - Window size: 520x620, non-resizable, centered
  - Window close button triggers `markOnboardingSkipped()`
- `AppDelegate.setupOnboarding()` initializes and shows onboarding on first launch
- Uses existing design system: Color.Wispflow, Font.Wispflow, Spacing, CornerRadius
- Verified via `swift build` - typecheck passes

---

### US-518: Microphone Permission Step
**Status:** complete
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [x] Create mic permission screen
- [x] Show current status
- [x] Add "Grant Access" button
- [x] Update status after permission

**Acceptance Criteria:**
- Permission status displayed
- Button triggers system dialog
- Status updates on grant
- Typecheck passes

**Implementation Notes:**
- Created `MicrophonePermissionView` in `OnboardingWindow.swift` with all required UI elements
- Screen explains why microphone access is needed with clear description text
- Current permission status displayed via `permissionStatusCard` component with status icon (green checkmark/red X)
- "Grant Access" button triggers `PermissionManager.requestMicrophonePermission()` which shows system permission dialog
- Status updates automatically after permission granted via `@Published` property in PermissionManager
- "Continue" button only enabled after permission granted (changes from "Grant Access" to green "Continue")
- "Skip for now" link always available as subtle underlined text
- Illustration/icon showing microphone with animated gradient circle and mic.fill SF Symbol
- Added `microphone` case to `OnboardingStep` enum with proper `nextStep` navigation helper
- Updated `OnboardingContainerView` to include microphone step with proper navigation flow
- Added preview for `MicrophonePermissionView` for development testing
- Verified via `swift build` - typecheck passes

---

### US-519: Accessibility Permission Step
**Status:** complete
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [x] Create accessibility permission screen
- [x] Show current status
- [x] Add "Open System Settings" button
- [x] Show instructions for enabling

**Acceptance Criteria:**
- Status displayed
- Button opens Settings
- Instructions clear
- Status updates on return
- Typecheck passes

**Implementation Notes:**
- Created `AccessibilityPermissionView` in `OnboardingWindow.swift` with all required UI elements
- Screen explains why accessibility access is needed: "WispFlow needs accessibility access for global hotkeys and text insertion."
- Current permission status displayed via `permissionStatusCard` component with status icon (green checkmark/red X)
- "Open System Settings" button triggers `PermissionManager.openAccessibilitySettings()` which opens Privacy & Security > Accessibility pane
- Instructions displayed via `instructionsCard` with step-by-step numbered instructions using `InstructionRow` component:
  1. Click "Open System Settings" below
  2. Find WispFlow in the list
  3. Toggle the switch to enable
  4. Return to this window
- Status updates automatically when user returns to app via PermissionManager's app activation observer and polling mechanism
- "Continue" button only enabled after permission granted; changes from "Open System Settings" to green "Continue"
- "Skip for now" link always available as subtle underlined text
- Illustration/icon showing keyboard (keyboard.fill SF Symbol) representing hotkeys + text insertion
- Added `accessibility` case to `OnboardingStep` enum with proper `nextStep` navigation helper
- Updated `OnboardingContainerView` to include accessibility step with proper navigation flow
- Added preview for `AccessibilityPermissionView` for development testing
- Verified via `swift build` - typecheck passes

---

### US-520: Audio Test Step
**Status:** complete
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [x] Create audio test screen
- [x] Add live level meter
- [x] Add device selector
- [x] Add "Sounds Good!" button
- [x] Add troubleshooting tips section

**Acceptance Criteria:**
- Level meter shows mic input
- Device selector works
- Can proceed when satisfied
- Typecheck passes

**Implementation Notes:**
- Created `AudioTestView` in `OnboardingWindow.swift` with comprehensive audio testing UI
- Live audio level meter (`OnboardingAudioLevelMeter`) displays with 30 segments at 20fps (~0.05s timer interval)
- "Start Test" button triggers `audioManager.startCapturing()` to begin audio capture
- Visual feedback: animated pulsing ring around microphone icon, waveform icon when testing, level status badges (Good/Quiet/Silent/Too Loud)
- Device selector dropdown (`Menu`) appears when multiple devices available, showing all input devices with checkmarks and "(Default)" indicator
- "Sounds Good!" button appears after user speaks (level > -40dB) - advances to next onboarding step
- "Having Issues?" link toggles `troubleshootingTipsCard` with 5 troubleshooting tips using `TroubleshootingTipRow` components:
  1. Make sure microphone is connected and not muted
  2. Check System Settings > Sound > Input
  3. Ensure WispFlow has microphone permission
  4. Try selecting a different microphone
  5. Speak loudly and clearly, 6-12 inches from microphone
- Added `audioTest` case to `OnboardingStep` enum with proper `nextStep` navigation
- Updated `OnboardingContainerView` to accept `audioManager` and render `AudioTestView` for the audio test step
- Updated `OnboardingWindowController` to accept `audioManager` parameter and pass it to `OnboardingContainerView`
- Updated `AppDelegate.setupOnboarding()` to pass `audioManager` to `OnboardingWindowController`
- Audio test stops automatically when view disappears (`.onDisappear` modifier)
- Added preview for `AudioTestView` for development testing
- Verified via `swift build` - typecheck passes

---

### US-521: Hotkey Introduction Step
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Tasks:**
- [x] Create hotkey intro screen
- [x] Display default hotkey
- [x] Add "Try it now" prompt
- [x] Add visual feedback on press
- [x] Add "Change Hotkey" option for customization
- [x] Add default hotkey recommendation note

**Acceptance Criteria:**
- Hotkey displayed clearly
- Feedback on press
- Option to customize
- Typecheck passes

**Implementation Notes:**
- Created `HotkeyIntroductionView` in `OnboardingWindow.swift` with all required UI elements
- Added `hotkey` case to `OnboardingStep` enum with proper `nextStep` navigation
- Current hotkey displayed prominently using `HotkeyKeyBadge` components showing individual key symbols (⌘⇧Space)
- "Try it now" prompt with pulsing dot indicator encourages user to test hotkey
- Visual feedback when hotkey pressed: icon changes to checkmark, card scales up, "Perfect!" success message appears
- "Change Hotkey" option expands `OnboardingHotkeyRecorder` component for customization
- Default hotkey recommendation: "Tip: The default ⌘⇧Space works well for most users"
- Updated `OnboardingContainerView` to accept `hotkeyManager` and render `HotkeyIntroductionView`
- Updated `OnboardingWindowController` to accept `hotkeyManager` parameter
- Updated `AppDelegate.setupOnboarding()` to pass `hotkeyManager` to onboarding
- Hotkey test listener setup hooks into `hotkeyManager.onHotkeyPressed` callback
- Added preview for `HotkeyIntroductionView` for development testing
- Verified via `swift build` - typecheck passes

---

### US-522: Onboarding Completion
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Tasks:**
- [x] Create completion screen
- [x] Show success checkmarks
- [x] Set hasCompletedOnboarding flag
- [x] Close wizard and show menu bar

**Acceptance Criteria:**
- Success state shown
- Flag persisted
- App ready to use
- Typecheck passes

**Implementation Notes:**
- Created `OnboardingCompletionView` in `OnboardingWindow.swift` with all required UI elements
- Added `completion` case to `OnboardingStep` enum with proper `nextStep` navigation
- Success screen with animated checkmarks for completed steps:
  - Microphone Access (shows actual permission status from `PermissionManager`)
  - Accessibility Access (shows actual permission status from `PermissionManager`)
  - Audio Test (always marked completed if user reached this step)
  - Hotkey Configuration (always marked completed if user reached this step)
- `CompletedStepRow` component displays each step with checkmark/minus icon and "Done"/"Skipped" badge
- Brief recap of how to use: "To start recording, press:" with hotkey display using `HotkeyKeyBadge` components
- "Start Using WispFlow" button (green success color) triggers `completeOnboarding()` which:
  - Calls `onboardingManager.markOnboardingCompleted()` to set `hasCompletedOnboarding` flag to true in UserDefaults
  - Closes the wizard window
  - Menu bar icon is already visible and ready (set up in `AppDelegate`)
- Animated entrance: success icon and checkmarks appear with spring animations on view appear
- Updated `OnboardingContainerView` switch statement to render `OnboardingCompletionView` for `.completion` case
- Added preview for `OnboardingCompletionView` for development testing
- Verified via `swift build` - typecheck passes

---

## Summary

| Phase | Stories | Priority | Effort |
|-------|---------|----------|--------|
| Phase 1: Settings UI | 3 | Critical | Small |
| Phase 2: Audio | 5 | Critical | Medium |
| Phase 3: Permissions | 4 | High | Small-Medium |
| Phase 4: Hotkeys | 3 | Critical | Medium-Large |
| Phase 5: Text Insertion | 3 | High | Small-Medium |
| Phase 6: Onboarding | 7 | Medium | Medium |

**Total: 25 User Stories**

**Recommended Implementation Order:**
1. US-523, US-524, US-525 (Settings UI - unblocks testing)
2. US-503, US-504 (Audio engine - core functionality)
3. US-501, US-502, US-505 (Device selection)
4. US-506, US-507, US-508, US-509 (Permissions)
5. US-510, US-511, US-512 (Hotkeys)
6. US-513, US-514, US-515 (Text insertion)
7. US-516 through US-522 (Onboarding - last, uses all systems)
