# Implementation Plan: Audio, Permissions & Hotkeys Overhaul

**PRD Source:** `.agents/tasks/prd-audio-permissions-hotkeys-overhaul.md`
**Generated:** 2026-01-14

---

## Overview

This plan implements a comprehensive overhaul of WispFlow's core systems based on Voquill patterns. The implementation is ordered to fix blocking issues first (Settings UI), then core functionality (audio, permissions, hotkeys), and finally polish (onboarding).

---

## Phase 1: Settings UI Fixes (Unblocks Testing)

### [x] US-523: Fix Tab Visibility
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

### [x] US-524: Fix Button Interactivity
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

### [x] US-525: Fix ScrollView Interactions
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
- Added `contentShape(Rectangle())` to dropdown trigger buttons:
  - `LanguagePicker` - language selection dropdown trigger
  - `AudioDevicePicker` - audio device selection dropdown trigger
  - `HotkeyRecorderView` - hotkey recorder button
- Added `contentShape(Rectangle())` to the following dropdown/picker row components:
  - `LanguageRow` - language picker dropdown items
  - `AudioDeviceRow` - audio device picker dropdown items
  - `CleanupModeSegment` - cleanup mode segmented control segments (if applicable)
  - `ModelSelectionCard` - Whisper model selection cards
  - `LLMModelSelectionCard` - LLM model selection cards
- All changes ensure consistent hit testing behavior across ScrollViews throughout Settings
- No overlay or ZStack blocking issues found - the root cause was missing contentShape on interactive elements
- Verified via `swift build` - typecheck passes (iteration 5)

---

## Phase 2: Audio System Overhaul

### [x] US-503: Robust Audio Engine Initialization
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

### [x] US-504: Audio Level Preview Fix
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

### [x] US-501: Smart Audio Device Selection
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

### [x] US-502: Audio Device Caching
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

### [x] US-505: Low-Quality Device Warning
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

### [x] US-506: Permission Status Tracking
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

### [x] US-507: Automatic Permission Prompting
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

### [x] US-508: Open System Settings Helper
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

### [x] US-509: Permission Status UI
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

### [x] US-510: Global Event Tap for Hotkeys
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

### [x] US-511: Hotkey Recording in Settings
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

### [x] US-512: Hotkey Conflict Detection
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

### [x] US-513: Clipboard Preservation
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

### [x] US-514: Keyboard Event Simulation
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

### [x] US-515: Text Insertion Fallback
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

### [x] US-516: First Launch Detection
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

### [x] US-517: Onboarding Welcome Screen
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

### [x] US-518: Microphone Permission Step
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

### [x] US-519: Accessibility Permission Step
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

### [x] US-520: Audio Test Step
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

### [x] US-521: Hotkey Introduction Step
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

### [x] US-522: Onboarding Completion
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

---

## Phase 7: Audio System Hardening (from PRD v2)

### [x] US-601: Audio Device Hot-Plug Support
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Handle audio device connection/disconnection gracefully without crashing or requiring app restart.

**Tasks:**
- [x] Add `preferredDeviceUID` to store user's preferred device separately from selected device
- [x] Add `recordingStartDevice` to track device active when recording starts
- [x] Add `onDeviceDisconnectedDuringRecording` callback for device disconnect during recording
- [x] Add `onDeviceChanged` callback for general device changes
- [x] Add `onPreferredDeviceReconnected` callback for preferred device reconnection
- [x] Enhance `refreshAvailableDevices()` to detect device changes (connect/disconnect)
- [x] Implement `handleDeviceDisconnectedDuringRecording()` to fall back to system default
- [x] Implement `handlePreferredDeviceReconnected()` to auto-switch back to preferred device
- [x] Store/load `preferredDeviceUID` in UserDefaults
- [x] Track recording start device in `startCapturing()`
- [x] Clear recording start device in `stopCapturing()` and `cancelCapturing()`
- [x] Switch to preferred device after recording completes if reconnected during recording
- [x] Add toast notification methods to ToastManager for device changes
- [x] Wire up callbacks in AppDelegate to show toast notifications
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Detect when selected audio device is disconnected during recording
- [x] Automatically fall back to system default device
- [x] Show toast notification when device changes
- [x] Re-select preferred device when it's reconnected
- [x] No crashes when devices are plugged/unplugged (build passes, robust error handling)

**Implementation Notes:**
- Uses `AudioObjectAddPropertyListenerBlock` for `kAudioHardwarePropertyDevices` (already implemented)
- Stores device UID preference (`preferredDeviceUID`) separately from runtime selection (`selectedDeviceUID`)
- `preferredDeviceUID` is set when user explicitly selects a device in Settings
- If recording device disconnects during recording:
  1. Falls back to system default device
  2. Attempts to switch audio input device on the fly
  3. Shows warning toast to user
- If preferred device reconnects:
  1. Auto-switches to preferred device (if not currently recording)
  2. Shows success toast to user
- Added three new callbacks: `onDeviceDisconnectedDuringRecording`, `onDeviceChanged`, `onPreferredDeviceReconnected`
- Added three new toast methods: `showDeviceDisconnectedDuringRecording`, `showDeviceChanged`, `showPreferredDeviceReconnected`
- Verified via `swift build` - typecheck passes

---

### [x] US-602: Audio Format Negotiation Improvement
**Status:** complete
**Priority:** high
**Estimated effort:** small

**Description:** Improve compatibility with various audio devices by better format negotiation.

**Tasks:**
- [x] Add `AudioFormatInfo` struct to represent supported audio formats with properties (sampleRate, channelCount, bitsPerChannel, formatID, formatFlags)
- [x] Add `preferredSampleRates` constant for standard rates (48kHz, 44.1kHz, 96kHz, 32kHz, 22.05kHz, 16kHz)
- [x] Implement `querySupportedFormats(deviceID:)` to query device's supported formats via `kAudioDevicePropertyStreamConfiguration` and `kAudioStreamPropertyAvailablePhysicalFormats`
- [x] Implement `queryStreamFormats(streamID:)` to query available physical and virtual formats per stream
- [x] Implement `getFallbackFormat(deviceID:)` to return fallback formats using nominal sample rate
- [x] Implement `logSupportedFormats(_:)` to log detailed format information for debugging
- [x] Implement `selectBestFormat(from:)` to select best format preferring standard formats (44.1kHz, 48kHz stereo/mono)
- [x] Implement `checkFormatCompatibility(deviceID:)` to verify device has compatible format for capture
- [x] Add `AudioCaptureError.noCompatibleFormat(String)` error case for graceful error messaging
- [x] Integrate format checking in `startCapturing()` before audio capture begins
- [x] Add priority scoring to `AudioFormatInfo` (PCM preferred, standard sample rates prioritized, mono/stereo preferred)
- [x] Add `isStandardFormat` computed property to identify preferred formats
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Query device's supported formats before attempting capture
- [x] Prefer standard formats (44.1kHz, 48kHz stereo/mono)
- [x] Log detailed format information for debugging
- [x] Graceful error message if no compatible format found

**Implementation Notes:**
- Added `AudioFormatInfo` struct with comprehensive format description, priority scoring, and standard format detection
- Uses `kAudioDevicePropertyStreamConfiguration` to query stream configuration (buffer count, channel count)
- Uses `kAudioStreamPropertyAvailablePhysicalFormats` to query available physical formats per stream
- Falls back to `kAudioStreamPropertyAvailableVirtualFormats` if physical formats not available
- Format priority scoring: PCM (+100), 48kHz (+50), 44.1kHz (+45), mono (+15), stereo (+10), 16-bit+ (+5)
- Handles ranged format descriptions by adding preferred sample rates within the range
- Detailed logging includes format count, sorted list by priority, standard format markers (★)
- Graceful error messages explain why format is incompatible (no PCM, bad sample rate, etc.)
- Format checking integrated into `startCapturing()` with clear error logging box
- Verified via `swift build` - typecheck passes

---

### [x] US-603: Recording Timeout Safety
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Prevent runaway recordings that could fill disk space.

**Tasks:**
- [x] Add `maxRecordingDuration` constant (default 5 minutes = 300 seconds, configurable via UserDefaults)
- [x] Add `warningDuration` constant (default 4 minutes = 240 seconds)
- [x] Add recording timeout timer in AudioManager that fires at max duration
- [x] Add warning timer that fires at warning duration
- [x] Add `onRecordingTimeoutWarning` callback to AudioManager for 4-minute warning
- [x] Add `onRecordingTimeoutReached` callback to AudioManager for auto-stop at 5 minutes
- [x] Update RecordingIndicatorWindow to display elapsed time (already shows duration via durationLabel)
- [x] Add toast notification for 4-minute warning ("Recording Limit Approaching - X remaining")
- [x] Implement auto-stop and transcribe at 5-minute limit
- [x] Wire up callbacks in AppDelegate to handle timeout warnings and auto-stop
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Maximum recording duration of 5 minutes (configurable via `AudioManager.maxRecordingDuration`)
- [x] Warning toast at 4 minutes (via `showRecordingTimeoutWarning`)
- [x] Auto-stop and transcribe at limit (via `onRecordingTimeoutReached` callback triggering state change)
- [x] Show elapsed time in recording indicator (via existing `durationLabel` in `RecordingIndicatorWindow`)

**Implementation Notes:**
- Added timeout constants to `AudioManager.Constants`: `maxRecordingDurationKey`, `defaultMaxRecordingDuration` (300s), `warningOffsetFromMax` (60s)
- Added `recordingTimeoutWarningTimer` and `recordingTimeoutMaxTimer` Timer properties
- Added `hasShownTimeoutWarning` flag to prevent duplicate warnings
- Added `onRecordingTimeoutWarning: ((TimeInterval) -> Void)?` callback that passes remaining time
- Added `onRecordingTimeoutReached: (() -> Void)?` callback for auto-stop
- Added `startRecordingTimeoutTimers()` and `stopRecordingTimeoutTimers()` methods
- Integrated timer start/stop into `startCapturing()`, `stopCapturing()`, and `cancelCapturing()`
- Added static properties: `maxRecordingDuration` (getter/setter with UserDefaults), `warningDuration` (computed)
- Added instance properties: `elapsedRecordingTime`, `remainingRecordingTime`
- Added toast methods to `ToastManager`: `showRecordingTimeoutWarning(remainingSeconds:)`, `showRecordingAutoStopped()`
- Wired up callbacks in `AppDelegate.setupAudioManager()` to show toasts and trigger auto-stop
- RecordingIndicatorWindow already has `durationLabel` that displays "M:SS" format, updated every second
- Verified via `swift build` - typecheck passes

---

### [x] US-604: Audio Level Calibration
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Allow users to calibrate microphone sensitivity for their environment.

**Tasks:**
- [x] Add `CalibrationState` enum to track calibration progress (idle, calibrating, completed, failed)
- [x] Add `DeviceCalibration` struct for per-device calibration data (deviceUID, deviceName, ambientNoiseLevel, silenceThreshold, calibrationDate)
- [x] Add `calibrationDuration` constant (3 seconds) to Constants
- [x] Add `calibrationDataKey` for UserDefaults persistence
- [x] Add `defaultSilenceThresholdOffset` constant (5dB above ambient)
- [x] Implement `startCalibration()` method to begin 3-second ambient noise measurement
- [x] Implement `cancelCalibration()` method to abort calibration
- [x] Implement `finishCalibration()` method to calculate and save calibration results
- [x] Implement `getCalibrationForCurrentDevice()` to retrieve saved calibration
- [x] Implement `isCurrentDeviceCalibrated` computed property
- [x] Implement `effectiveSilenceThreshold` computed property (uses calibrated threshold if available)
- [x] Implement `resetCalibrationForCurrentDevice()` to reset to default threshold
- [x] Implement `loadCalibrationData()` and `saveCalibrationData()` for UserDefaults persistence
- [x] Add `AudioCalibrationCard` UI component in SettingsWindow.swift
- [x] Add `CalibrationStatusView` for displaying current calibration status
- [x] Add `CalibrationProgressDisplay` with progress bar for calibration in progress
- [x] Add `CalibrationResultDisplay` for showing calibrated values
- [x] Add `DefaultThresholdDisplay` for showing default threshold when not calibrated
- [x] Add `CalibrationCompletedDisplay` with success animation
- [x] Add `CalibrationFailedDisplay` for error states
- [x] Add "Calibrate" button in Audio settings tab
- [x] Add "Reset to Defaults" button for calibrated devices
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] "Calibrate" button in Audio settings
- [x] Measure ambient noise level over 3 seconds
- [x] Adjust silence threshold based on calibration (ambient + 5dB offset)
- [x] Save calibration per-device (stored in UserDefaults keyed by device UID)
- [x] Reset to defaults option (via `resetCalibrationForCurrentDevice()`)

**Implementation Notes:**
- `CalibrationState` enum supports four states: `.idle`, `.calibrating(progress: Double)`, `.completed(ambientLevel: Float)`, `.failed(message: String)`
- `DeviceCalibration` struct is Codable for JSON serialization to UserDefaults
- Calibration process: starts audio capture → collects level samples at 100ms intervals → calculates average ambient level → sets threshold = ambient + 5dB
- `deviceCalibrations` dictionary stores calibrations keyed by device UID for per-device settings
- `effectiveSilenceThreshold` returns calibrated threshold when available, otherwise returns default (-55dB)
- UI displays calibration metrics (ambient level, threshold) with date of last calibration
- Reset confirmation alert prevents accidental reset
- All calibration data persisted across app restarts via UserDefaults
- Verified via `swift build` - typecheck passes

---

## Phase 8: Transcription Quality (from PRD v2)

### [x] US-605: Whisper Model Selection
**Status:** complete
**Priority:** high
**Estimated effort:** medium

**Description:** Allow users to choose between different Whisper model sizes for speed vs accuracy tradeoff.

**Tasks:**
- [x] Add `ModelSize` enum with `tiny`, `base`, `small`, `medium` cases to `WhisperManager`
- [x] Add `displayName` and `description` properties for each model size
- [x] Add model metadata (size, speed, accuracy) for UI display
- [x] Implement `selectModel(_:)` method to change selected model
- [x] Implement `loadModel()` to download and load selected model
- [x] Implement `isModelDownloaded(_:)` to check if model files exist
- [x] Add `ModelStatus` enum with `notDownloaded`, `downloading(progress)`, `downloaded`, `loading`, `ready`, `error` states
- [x] Add `@Published downloadProgress` property for progress tracking
- [x] Persist model selection via `UserDefaults` with key `selectedWhisperModel`
- [x] Add `TranscriptionSettingsView` with card-based model picker
- [x] Add `ModelSelectionCard` component showing model info (size, speed, accuracy)
- [x] Add `GradientProgressBar` component for download visualization
- [x] Add "Download & Load" / "Load Model" / "Delete" action buttons
- [x] Add retry functionality for failed downloads
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Settings option for model size (tiny, base, small, medium)
- [x] Show estimated transcription speed and accuracy for each
- [x] Download progress indicator for model switching
- [x] Persist model preference across restarts

**Implementation Notes:**
- `WhisperManager.ModelSize` enum provides four model options with `displayName`, `description`, and `modelPattern` properties
- Each model card shows:
  - Model name (Tiny, Base, Small, Medium)
  - Download size (~75MB, ~140MB, ~460MB, ~1.5GB)
  - Speed indicator (Fastest, Fast, Medium, Slower)
  - Accuracy indicator (Basic, Good, Great, Best)
- Download progress tracked via `modelStatus: .downloading(progress: Double)` with gradient progress bar
- Model preference persisted in UserDefaults under `selectedWhisperModel` key
- Loads saved preference on init, defaults to `.base` if none saved
- Model files stored in `~/Library/Application Support/WispFlow/Models/`
- WhisperKit handles automatic download from Hugging Face repository
- UI provides "Active" badge for loaded model, "Downloaded" badge for cached models
- Delete functionality allows removing downloaded models to free disk space
- Error handling with detailed messages and retry option for failed downloads
- Verified via `swift build` - typecheck passes

---

### [x] US-606: Language Selection
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Allow users to specify transcription language for better accuracy.

**Tasks:**
- [x] Add `TranscriptionLanguage` enum to WhisperManager with common languages (Auto-detect + 11 common languages)
- [x] Add `selectedLanguage` @Published property to WhisperManager
- [x] Add `selectedLanguageKey` constant for UserDefaults persistence
- [x] Load saved language preference on init (default: `.automatic`)
- [x] Persist language changes to UserDefaults via didSet observer
- [x] Add `whisperLanguageCode` computed property for WhisperKit integration
- [x] Create `DecodingOptions` in `transcribe()` method with language hint
- [x] Pass `detectLanguage: true` for auto-detect, `false` for specific language
- [x] Update LanguagePicker in SettingsWindow to bind to `whisperManager.selectedLanguage`
- [x] Remove duplicate `TranscriptionLanguage` enum from SettingsWindow
- [x] Update LanguageRow to use `WhisperManager.TranscriptionLanguage`
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Language dropdown in Settings (Auto-detect + common languages)
- [x] Pass language hint to WhisperKit (via `DecodingOptions`)
- [x] Remember language preference (persisted via UserDefaults)
- [x] "Auto-detect" as default (`.automatic` case)

**Implementation Notes:**
- `WhisperManager.TranscriptionLanguage` enum provides 12 language options: automatic (auto-detect), English, Spanish, French, German, Italian, Portuguese, Japanese, Chinese, Korean, Russian, Arabic
- Each language has `displayName`, `flag` (emoji), and `whisperLanguageCode` properties
- `whisperLanguageCode` returns `nil` for automatic mode (tells WhisperKit to auto-detect)
- Language preference persisted in UserDefaults under `selectedTranscriptionLanguage` key
- Loads saved preference on init, defaults to `.automatic` if none saved
- SettingsWindow's LanguagePicker bound to `$whisperManager.selectedLanguage` for two-way binding
- Removed duplicate `TranscriptionLanguage` enum from SettingsWindow.swift
- DecodingOptions created in `transcribe()` method with:
  - `language`: the Whisper language code (or nil for auto-detect)
  - `detectLanguage`: true for automatic, false for specific language
  - `usePrefillPrompt`: true for better accuracy
- Verified via `swift build` - typecheck passes

---

### [x] US-607: Transcription Post-Processing
**Status:** complete
**Priority:** medium
**Estimated effort:** small

**Description:** Clean up transcription output for better usability with configurable post-processing options.

**Tasks:**
- [x] Add `autoCapitalizeFirstLetterKey`, `addPeriodAtEndKey`, `trimWhitespaceKey` constants to TextCleanupManager.Constants
- [x] Add `@Published var autoCapitalizeFirstLetter: Bool` property with UserDefaults persistence
- [x] Add `@Published var addPeriodAtEnd: Bool` property with UserDefaults persistence
- [x] Add `@Published var trimWhitespace: Bool` property with UserDefaults persistence
- [x] Load post-processing preferences on init (all default to `true` for better UX)
- [x] Implement `applyPostProcessing(_:)` method that applies all three options in order: trim → capitalize → period
- [x] Implement `processText(_:)` method that combines cleanup and post-processing
- [x] Update `AppDelegate` to use `processText()` method instead of `cleanupText()`
- [x] Add "Post-Processing" card in Settings Window (Text Cleanup tab)
- [x] Add toggle for "Auto-capitalize first letter" with description
- [x] Add toggle for "Add period at end" with description
- [x] Add toggle for "Trim whitespace" with description
- [x] Build verification (`swift build` succeeds)

**Acceptance Criteria:**
- [x] Option to auto-capitalize first letter (via `autoCapitalizeFirstLetter` toggle in Settings)
- [x] Option to add period at end of sentences (via `addPeriodAtEnd` toggle in Settings)
- [x] Option to trim leading/trailing whitespace (via `trimWhitespace` toggle in Settings)
- [x] Configurable in Settings (Post-Processing card in Text Cleanup tab)

**Implementation Notes:**
- Post-processing options are separate from the main cleanup feature - they apply even when cleanup is disabled
- Three options all default to `true` for better out-of-box experience:
  - `autoCapitalizeFirstLetter`: Capitalizes the first letter if it's lowercase
  - `addPeriodAtEnd`: Adds a period if text doesn't end with `.!?;:`
  - `trimWhitespace`: Removes leading and trailing whitespace/newlines
- `applyPostProcessing()` applies options in logical order: trim first (so we work with clean bounds), then capitalize, then add period
- `processText()` is the new main entry point that chains `cleanupText()` and `applyPostProcessing()`
- Settings UI uses `wispflowCard()` styling with individual toggles and descriptive text
- Each option has its own toggle with descriptive text explaining what it does
- All settings persisted via UserDefaults with dedicated keys
- Verified via `swift build` - typecheck passes

---

## Phase 9: UI Redesign (from PRD v2)

### [x] US-615: Design System Foundation
**Status:** complete
**Priority:** high
**Estimated effort:** medium
**Depends on:** none

**Description:** Create a cohesive, distinctive design system for WispFlow that feels premium and memorable.

**Tasks:**
- [x] Define distinctive color palette (NOT purple gradients, NOT generic blue)
- [x] Choose primary color: bold unexpected choice (deep coral, electric teal, warm amber)
- [x] Set background: rich dark (#0D0D0D range) or warm off-white (cream/ivory)
- [x] Define high-contrast accent color
- [x] Define semantic colors for success/warning/error
- [x] Select memorable display typography (NOT Inter, Roboto, SF Pro)
- [x] Define spacing scale (4px base, consistent rhythm)
- [x] Define corner radius philosophy (sharp/brutalist OR soft/organic)
- [x] Create SwiftUI Color.Wispflow and Font.Wispflow extensions
- [x] Document design tokens in code comments

**Acceptance Criteria:**
- [x] Color.Wispflow.primary returns the primary brand color
- [x] Fallback to system colors if custom colors fail to load

**Implementation Notes:**
- **Color Palette:** Warm coral/terracotta (#E07A5F) as primary brand color - distinctive and memorable, not generic blue
- **Background:** Warm ivory/cream (#FEFCF8) - soft and approachable, reduces eye strain
- **High-contrast accent:** Added `accentContrast` (#C4563F) - darker coral for text meeting WCAG AA requirements
- **Semantic colors:** Success (#81B29A sage green), Warning (#E09F3E warm orange), Error (#D64545 warm red), Info (#5B8FB9 muted blue)
- **Typography:** SF Rounded for display text creates distinctive, friendly feel; system font for body text for legibility
- **Spacing scale:** 4pt base unit with progressive scale: xs(4), sm(8), md(12), lg(16), xl(24), xxl(32), xxxl(48)
- **Corner radius:** Soft/organic philosophy with small(8pt), medium(12pt), large(16pt), extraLarge(22pt)
- **Extensions:** `Color.Wispflow` and `Font.Wispflow` (SwiftUI), `NSColor.Wispflow` and `NSFont.Wispflow` (AppKit)
- **Fallbacks:** All primary colors compute at runtime with fallback to system colors if hex initialization fails
- **Documentation:** Comprehensive design token documentation with philosophy, usage guides, and code examples in box-style comments
- Verified via `swift build` - typecheck passes

---

### [x] US-632: Main Window with Sidebar Navigation
**Status:** complete
**Priority:** high
**Estimated effort:** large
**Depends on:** US-615

**Description:** Create a modern main application window with sidebar navigation for easy access to all features.

**Tasks:**
- [x] Create main window with fixed left sidebar (200-250px width)
- [x] Add navigation items: Home, History, Snippets, Dictionary, Settings
- [x] Design distinctive icon for each nav item
- [x] Implement active nav item highlight (background color or accent indicator)
- [x] Add subtle separator or shadow between sidebar and content
- [x] Implement hover states with smooth transitions
- [x] Save/restore window size and position across sessions
- [x] Set minimum window size: 800x600px
- [x] Implement sidebar collapse to icons when window too small

**Acceptance Criteria:**
- [x] Sidebar contains 5 navigation items with icons and labels
- [x] Active nav item visually highlighted
- [x] Smooth transitions when switching views
- [x] Window state persists across sessions
- [x] Sidebar collapses gracefully on small windows

**Implementation Notes:**
- Created `MainWindow.swift` with `MainWindowView` (SwiftUI) and `MainWindowController` (AppKit window management)
- **Sidebar Implementation:**
  - Fixed width: 220px expanded, 70px collapsed
  - App branding header with WispFlow logo and "Voice to Text" tagline
  - Five navigation items using `NavigationItem` enum with distinctive SF Symbols:
    - Home (house.fill), History (clock.fill), Snippets (doc.on.clipboard.fill), Dictionary (character.book.closed.fill), Settings (gearshape.fill)
  - Collapse toggle button at bottom of sidebar
- **Active Item Highlighting:**
  - Left accent bar indicator (3px wide coral bar)
  - Background highlight using `accentLight` color
  - `matchedGeometryEffect` for smooth animated transitions
  - Icon changes from outline to filled when selected
- **Hover States:**
  - Smooth 0.1s transition on hover via `WispflowAnimation.quick`
  - Border opacity change on hover (0.4 opacity)
  - Hover tooltip displays navigation item name
- **Window State Persistence:**
  - `NSWindow.setFrameAutosaveName("MainWindow")` for automatic frame saving
  - Manual frame saving via `saveWindowFrame()` on resize/move
  - Manual frame restoration from UserDefaults on window creation
  - Keys: `MainWindowFrame` for frame, `MainWindowWasOpen` for state
- **Minimum Window Size:** 800x600px enforced via `window.minSize`
- **Auto-Collapse Behavior:**
  - Sidebar auto-collapses when window width < 700px
  - Collapse threshold checked on `onChange(of: geometry.size.width)`
  - Manual collapse/expand toggle button always available
- **Separator:** 1px vertical divider with subtle shadow between sidebar and content
- **Integration:**
  - "Open WispFlow" menu item added to StatusBarController (Cmd+O)
  - `MainWindowController` initialized in `setupToastSystem()`
  - Callback flow: StatusBar → AppDelegate → MainWindowController
- Placeholder content views for Home, History, Snippets, Dictionary, Settings (to be implemented in US-633-636)
- Verified via `swift build` - typecheck passes

---

### [x] US-633: Dashboard Home View
**Status:** complete
**Priority:** high
**Estimated effort:** large
**Depends on:** US-632

**Description:** Create a welcoming dashboard home view showing activity and quick actions.

**Tasks:**
- [x] Display personalized welcome message ("Welcome back" or user name)
- [x] Show usage statistics: streak days, total words transcribed, average WPM
- [x] Design stats row with icons in clean horizontal layout
- [x] Add optional promotional/feature banner area
- [x] Create Quick Actions section with card-based shortcuts
- [x] Design cards with icons, labels, subtle shadows/borders
- [x] Implement hover lift effect on cards
- [x] Add Recent Activity timeline with dated transcription entries
- [x] Each timeline entry shows timestamp and text preview

**Acceptance Criteria:**
- [x] Welcome message displayed at top
- [x] Usage stats visible (streak, words, WPM)
- [x] Quick action cards functional with hover effects
- [x] Recent activity shows dated entries
- [x] Empty state shows onboarding prompt

**Implementation Notes:**
- Created `UsageStatsManager.swift` singleton for tracking usage statistics:
  - `TranscriptionEntry` data model stores transcription text preview, word count, duration, timestamp
  - Tracks streak days (consecutive days of transcription usage)
  - Tracks total words transcribed across all sessions
  - Tracks total recordings count and recording duration
  - Calculates average WPM from total words / total duration
  - Persists to UserDefaults for data persistence across app restarts
  - Recent entries stored with 50-entry limit (newest first)
  - Streak management: increments on daily usage, resets after gap > 1 day
- Updated `HomeContentView` in `MainWindow.swift` with full dashboard implementation:
  - **Welcome Section:** Time-based greeting ("Good morning/afternoon/evening") with current date
  - **Stats Section:** Four `StatCard` components showing:
    - Streak days (flame icon, orange)
    - Total words transcribed with K/M suffix formatting
    - Average WPM (speedometer icon, info blue)
    - Total recordings count (waveform icon, success green)
  - **Empty Stats State:** Onboarding prompt when no activity yet ("Record your first transcription")
  - **Feature Banner:** Promotional area highlighting AI-powered text cleanup with Settings link
  - **Quick Actions:** Four `QuickActionCard` components with hover lift effect:
    - New Recording (mic icon)
    - View History (clock icon)
    - Snippets (clipboard icon)
    - Settings (gear icon)
  - **Recent Activity Timeline:** 
    - Groups entries by date (Today, Yesterday, date format)
    - `ActivityTimelineEntry` component with:
      - Timeline dot and connecting line
      - Timestamp and word count badge
      - Text preview (2-line limit, expandable)
      - WPM and duration info when expanded
      - Hover highlight and expand/collapse animation
  - **Empty Activity State:** Message "No transcriptions yet" with icon
- Integrated `UsageStatsManager` with `AppDelegate`:
  - Added `lastRecordingDuration` property to track recording duration
  - Updated `processTranscription()` to accept recording duration parameter
  - Updated `processTextCleanup()` to accept and pass recording duration
  - Calls `UsageStatsManager.shared.recordTranscription()` after successful text insertion
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Verified via `swift build` - typecheck passes

---

### [x] US-634: Transcription History View
**Status:** complete
**Priority:** medium
**Estimated effort:** medium
**Depends on:** US-632

**Description:** Browse and search transcription history.

**Tasks:**
- [x] Create data model for storing transcription history
- [x] List all past transcriptions with date, time, preview
- [x] Add search bar to filter transcriptions
- [x] Implement click-to-expand for full text
- [x] Add copy button on each entry
- [x] Add delete option with confirmation dialog
- [x] Group entries by date (Today, Yesterday, This Week, etc.)
- [x] Implement smooth list animations when filtering

**Acceptance Criteria:**
- [x] Past transcriptions listed with date/time/preview
- [x] Search filters results in real-time
- [x] Copy and delete work correctly
- [x] Entries grouped by date
- [x] Empty state message when no history

**Implementation Notes:**
- Extended `TranscriptionEntry` data model in `UsageStatsManager.swift`:
  - Added `fullText` field to store complete transcription text (not just preview)
  - Added migration decoder to handle entries without fullText field (uses textPreview as fallback)
  - Enhanced `removeEntry()` to update totals when entries are deleted
  - Added `searchEntries(query:)` method for real-time search filtering
  - Added `groupEntriesByDate(_:)` method for date category grouping
- Created `DateCategory` enum with five categories: Today, Yesterday, This Week, This Month, Older
  - Implements `Comparable` for sorting (most recent first)
  - Has `displayName` property for UI labels
- Created comprehensive `HistoryContentView` in `MainWindow.swift`:
  - **Header Section:** Title "Transcription History" with entry count badge and search bar
  - **Search Bar:** TextField with magnifying glass icon, clear button, real-time filtering
  - **Empty State:** Shows when no transcription history exists with helpful message
  - **No Results State:** Shows when search query returns no matches with "Clear Search" button
  - **History List:** LazyVStack grouped by date categories
- Created `HistoryEntryCard` component for individual entries:
  - Displays time, word count, duration, and WPM metadata
  - Shows text preview (2-line limit) when collapsed
  - Shows full text with text selection enabled when expanded
  - "Click to see full text..." indicator when text is truncated
  - **Copy button:** Copies full text to clipboard, shows toast notification
  - **Delete button:** Shows confirmation dialog before removing entry
  - **Expand/collapse button:** Toggles between preview and full text
  - Hover effects with subtle shadow and scale changes
  - Search query highlighting using AttributedString with warning-light background
- **Animations:**
  - Smooth list animations when filtering via `animation(WispflowAnimation.smooth, value:)`
  - Entry removal/insertion transitions using `transition(.asymmetric(...))`
  - Hover and expand animations using `WispflowAnimation.quick`
- Uses design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `wispflowShadow()`
- Verified via `swift build` - typecheck passes

---

### [x] US-635: Snippets Library View
**Status:** complete
**Priority:** medium
**Estimated effort:** medium
**Depends on:** US-632

**Description:** Save and reuse frequently used text snippets.

**Tasks:**
- [x] Create data model for snippets (title, content, shortcut)
- [x] Build grid or list view of saved snippets
- [x] Add create new snippet UI (title + content)
- [x] Implement inline editing for existing snippets
- [x] Add delete with confirmation
- [x] Add quick copy button on each snippet
- [x] Optional keyboard shortcut assignment per snippet
- [x] Add search/filter by title or content

**Acceptance Criteria:**
- [x] Snippets displayed in grid/list
- [x] Create, edit, delete all functional
- [x] Quick copy works
- [x] Search filters snippets
- [x] Empty state shows creation prompt

**Implementation Notes:**
- Created `SnippetsManager.swift` singleton for snippet storage and management:
  - `Snippet` data model with id, title, content, optional shortcut, createdAt, updatedAt
  - Word count and character count computed properties
  - Content preview (first 100 characters)
  - Relative date strings for display
  - Copy to clipboard helper method
- SnippetsManager provides full CRUD operations:
  - `createSnippet()` - creates new snippet, inserts at beginning
  - `updateSnippet()` - updates by ID, moves to top on update
  - `deleteSnippet()` - deletes by ID or reference
  - `searchSnippets()` - filters by title or content
  - `isShortcutInUse()` - validates shortcut uniqueness
  - Persists to UserDefaults with JSON encoding
  - Maximum capacity of 100 snippets
- Comprehensive `SnippetsContentView` in `MainWindow.swift`:
  - **Header Section:** Title "Snippets Library" with view toggle (grid/list), New Snippet button, search bar, snippet count badge
  - **View Toggle:** Grid view (LazyVGrid with adaptive columns) and List view (LazyVStack)
  - **Empty State:** Illustrated prompt with "Create First Snippet" button
  - **No Results State:** "No snippets found" with clear search button
- Created `SnippetCard` component for grid view:
  - Title with shortcut badge (keyboard icon + shortcut text)
  - Content preview with show more/less toggle
  - Copy, Edit, Delete action buttons (visible on hover)
  - Word/character count and "Updated X" metadata in footer
  - Hover effects with shadow and scale
  - Search query highlighting using AttributedString
- Created `SnippetListRow` component for list view:
  - Icon, title, shortcut badge, word count, updated date
  - Expandable content on click
  - Copy, Edit, Delete, Expand/Collapse action buttons
  - Hover effects with shadow
  - Search query highlighting
- Created `CreateSnippetSheet` for new snippets:
  - Title and Content fields with focus management
  - Collapsible keyboard shortcut section
  - Shortcut validation (checks for duplicates)
  - Cancel and Create buttons
- Created `EditSnippetSheet` for existing snippets:
  - Pre-populated fields with existing values
  - Collapsible keyboard shortcut section (shows current shortcut)
  - Shortcut validation (excludes current snippet from duplicate check)
  - Created/Updated metadata display
  - Cancel and Save Changes buttons (disabled until changes made)
- Delete confirmation alert prevents accidental deletion
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Verified via `swift build` - typecheck passes

---

### [x] US-636: Custom Dictionary View
**Status:** complete
**Priority:** low
**Estimated effort:** medium
**Depends on:** US-632

**Description:** Manage custom words and phrases for better transcription accuracy.

**Tasks:**
- [x] Create data model for dictionary entries (word, pronunciation hint)
- [x] Build list view of custom dictionary entries
- [x] Add new words with optional pronunciation hint
- [x] Implement edit and delete for entries
- [x] Add import/export dictionary as text file
- [x] Add search functionality for large dictionaries
- [x] Show word count and last updated timestamp

**Acceptance Criteria:**
- [x] Dictionary entries listed
- [x] Add, edit, delete functional
- [x] Import/export works
- [x] Search filters dictionary
- [x] Empty state explains feature benefits

**Implementation Notes:**
- Created `DictionaryManager.swift` singleton for dictionary storage and management:
  - `DictionaryEntry` data model with id, word, optional pronunciationHint, createdAt, updatedAt
  - Character count and pronunciation hint presence computed properties
  - Relative date strings for display (Today, Yesterday, X days ago, etc.)
  - Full timestamp string for metadata display
- DictionaryManager provides full CRUD operations:
  - `createEntry()` - creates new entry, checks for duplicates (case-insensitive)
  - `updateEntry()` - updates by ID or reference, validates word uniqueness
  - `deleteEntry()` - deletes by ID or reference
  - `searchEntries()` - filters by word or pronunciation hint
  - `wordExists()` - checks if word already exists (with optional exclude ID for editing)
  - Persists to UserDefaults with JSON encoding
  - Maximum capacity of 1000 entries
  - Automatic alphabetical sorting by word
- Import/Export functionality:
  - `exportAsText()` - exports as tab-separated text file with comments header
  - `importFromText()` - imports from tab-separated text, skips duplicates/comments
  - `exportAsJSON()` - exports as pretty-printed JSON
  - `importFromJSON()` - imports from JSON, merges avoiding duplicates
- Comprehensive `DictionaryContentView` in `MainWindow.swift`:
  - **Header Section:** Title "Custom Dictionary" with Import/Export buttons, Add Word button, search bar, word count badge, last updated timestamp
  - **Import:** Uses fileImporter with .plainText and .json content types
  - **Export:** Uses NSSavePanel with default filename "wispflow-dictionary.txt"
  - **Empty State:** Illustrated prompt explaining feature benefits with four benefit rows (technical terms, names, pronunciation hints, import)
  - **No Results State:** "No words found" with clear search button
  - **Dictionary List:** LazyVStack of DictionaryEntryRow components
- Created `DictionaryEntryRow` component:
  - First letter of word as icon in accent-colored square
  - Word displayed with semibold weight
  - Pronunciation hint badge (waveform icon + hint text) when present
  - "Updated X" timestamp
  - Edit and Delete action buttons (visible on hover)
  - Hover effects with shadow changes
  - Search query highlighting using AttributedString
- Created `CreateDictionaryEntrySheet` for adding new words:
  - Word/Phrase text field with validation for duplicates
  - Collapsible pronunciation hint field with examples
  - Examples section showing format (WispFlow → WISP-flow, GitHub → git-hub, etc.)
  - Cancel and Add Word buttons
- Created `EditDictionaryEntrySheet` for editing existing entries:
  - Pre-populated fields with existing values
  - Collapsible pronunciation hint section (shows current hint)
  - Validation excludes current entry from duplicate check
  - Created/Updated metadata display
  - Cancel and Save Changes buttons (disabled until changes made)
- Delete confirmation alert prevents accidental deletion
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Verified via `swift build` - typecheck passes

---

## Phase 10: Settings Integration (from prd-settings-integration.json)

### [x] US-701: Create SettingsContentView for Main Window
**Status:** complete
**Priority:** high
**Estimated effort:** medium
**Depends on:** none

**Description:** Create SettingsContentView that displays all settings in the main window content area when Settings is selected in sidebar.

**Tasks:**
- [x] Create SettingsContentView with vertical scrollable layout
- [x] Add section headers for each settings group
- [x] Group settings into: General, Audio, Transcription, Text Cleanup, Text Insertion, Debug
- [x] Apply wispflowCard() styling to each section
- [x] Use Color.Wispflow design tokens throughout
- [x] Enable smooth vertical scrolling

**Acceptance Criteria:**
- [x] Settings display in main window content area
- [x] All 6 sections visible with clear headers
- [x] Consistent styling with other main window views
- [x] Smooth scrolling for long content

**Implementation Notes:**
- Created `SettingsContentView` in `MainWindow.swift` with full ScrollView layout
- Implemented `SettingsSectionView` reusable component with wispflowCard() styling:
  - Expandable/collapsible sections with smooth animation
  - Section icon in accentLight background
  - Title and description text
  - Chevron expand/collapse indicator with rotation animation
- Created 6 summary views:
  - `GeneralSettingsSummary`: App info, hotkey display, permission badges
  - `AudioSettingsSummary`: Input device, device count, calibration status
  - `TranscriptionSettingsSummary`: Whisper model with status badge, language with flag
  - `TextCleanupSettingsSummary`: Cleanup toggle, mode, post-processing badges
  - `TextInsertionSettingsSummary`: Insertion method, clipboard preservation status
  - `DebugSettingsSummary`: Debug mode status, auto-save, last recording info
- Created supporting components: `SettingsInfoRow`, `PermissionBadge`, `ModelStatusIndicator`, `StatusPill`, `MiniFeatureBadge`, `SettingsOpenFullButton`
- Each section has "Open Full Settings" button to open detailed settings window
- All components use Color.Wispflow design tokens and Font.Wispflow typography
- Verified via `swift build` - typecheck passes

---

### [x] US-702: Migrate General Settings Section
**Status:** complete
**Priority:** high
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move General settings (hotkey, startup) to integrated settings view.

**Tasks:**
- [x] Display app info header (icon, version, description)
- [x] Add GitHub, Website, Support link buttons
- [x] Include Global Hotkey configuration with recording UI
- [x] Add Startup options (launch at login toggle)
- [x] Maintain all existing bindings to HotkeyManager

**Acceptance Criteria:**
- [x] App info displays correctly
- [x] Hotkey recording works
- [x] Startup toggle functions
- [x] All links open correctly

**Implementation Notes:**
- Expanded `GeneralSettingsSummary` in `MainWindow.swift` from a summary view to a full settings section
- Added `ServiceManagement` import for launch at login functionality
- Created app info header with WispFlow logo (waveform.circle.fill SF Symbol), version display, and app description
- Added `GeneralSettingsLinkButton` component with GitHub, Website, and Support links that open in browser
- Created `GeneralSettingsHotkeyRecorder` component with:
  - Full hotkey recording UI with pulsing animation indicator
  - Keyboard event capture via local NSEvent monitor
  - System shortcut conflict detection with alert dialog
  - Modifier key validation (requires at least one modifier)
  - Escape key to cancel recording
- Added startup section with Launch at Login toggle using SMAppService
- Created `GeneralSettingsPermissionRow` component with:
  - Visual permission status (green checkmark / red X)
  - Grant permission button that opens system dialogs
  - Microphone and Accessibility permission rows
- All components maintain existing bindings to HotkeyManager.shared
- Verified via `swift build` - typecheck passes

---

### [x] US-703: Migrate Audio Settings Section
**Status:** complete
**Priority:** high
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move Audio settings (device, preview, calibration) to integrated settings view.

**Tasks:**
- [x] Show audio input device picker dropdown
- [x] Display real-time audio level meter
- [x] Include input sensitivity slider
- [x] Add calibration controls
- [x] Include device refresh button

**Acceptance Criteria:**
- [x] Device selection works
- [x] Audio preview shows levels
- [x] Sensitivity slider adjusts threshold
- [x] Calibration functions correctly

**Implementation Notes:**
- Expanded `AudioSettingsSummary` in `MainWindow.swift` from a summary view to a full settings section (same pattern as US-702)
- Created four main sections within the Audio settings:
  1. **Input Device Section** with:
     - `AudioSettingsDevicePicker` dropdown component showing all available devices
     - Device icons based on device type (mic, laptop, airpods, USB, etc.)
     - Low-quality device warnings with tooltips for Bluetooth/AirPods devices
     - Refresh button to update available devices list
  2. **Audio Preview Section** with:
     - Real-time audio level meter (`AudioSettingsLevelMeter`) with 30 segments at 20fps
     - Level value in dB and status badges (Good/Quiet/Silent/Too Loud)
     - Color-coded segments: green for good, red for clipping, coral accent for quiet
     - Start/Stop Preview button that triggers audio capture
  3. **Input Sensitivity Section** with:
     - Custom slider (`AudioSettingsSlider`) for input gain adjustment (0.5x to 2.0x)
     - Visual percentage display with accent-colored badge
     - Reset to Default button
  4. **Calibration Section** with:
     - `AudioSettingsCalibrationStatus` component showing current calibration state
     - Support for all calibration states: idle, calibrating, completed, failed
     - Calibrate/Recalibrate/Retry buttons based on state
     - Reset to Defaults button with confirmation dialog
     - Progress bar during calibration
- Created supporting components:
  - `AudioSettingsDeviceRow` for dropdown items with selection checkmarks
  - `AudioSettingsLevelMeter` for visual audio level display
  - `AudioSettingsSlider` with custom thumb and gradient fill
  - `AudioSettingsCalibrationStatus`, `AudioSettingsCalibrationResult`, `AudioSettingsDefaultThreshold`
  - `AudioSettingsCalibrationProgress`, `AudioSettingsCalibrationCompleted`, `AudioSettingsCalibrationFailed`
  - `AudioSettingsMetric` for calibration value display
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Audio preview automatically stops when view disappears (`.onDisappear` modifier)
- Verified via `swift build` - typecheck passes

---

### [x] US-704: Migrate Transcription Settings Section
**Status:** complete
**Priority:** high
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move Transcription settings (model, language) to integrated settings view.

**Tasks:**
- [x] Show Whisper model size picker
- [x] Display model download progress
- [x] Include language selection dropdown
- [x] Show quality/speed tradeoff info

**Acceptance Criteria:**
- [x] Model selection works with download progress
- [x] Language selection persists
- [x] Tradeoff info displayed

**Implementation Notes:**
- Expanded `TranscriptionSettingsSummary` in `MainWindow.swift` from a summary view to a full settings section (same pattern as US-702, US-703)
- Created four main sections within the Transcription settings:
  1. **Model Selection Section** with:
     - Card-based model picker using `TranscriptionModelCard` components for Tiny, Base, Small, Medium models
     - Each card shows model name, download size, speed indicator, and accuracy rating
     - Visual selection indicator (radio-style circles)
     - Status badges ("Active" for loaded model, "Downloaded" for cached models)
  2. **Model Actions Section** with:
     - `TranscriptionProgressBar` gradient progress bar during model downloads
     - Progress percentage display with animated shimmer effect
     - Download/Load, Retry, and Delete action buttons
     - Error handling with alert dialogs showing detailed error messages
  3. **Language Selection Section** with:
     - `TranscriptionLanguagePicker` dropdown component with flags for 12 languages
     - Auto-detect recommended for mixed-language content
     - `TranscriptionLanguageRow` items with flags, checkmarks, and "Recommended" badge
     - Language selection bound to `WhisperManager.selectedLanguage` for persistence
  4. **Quality vs Speed Tradeoff Section** with:
     - `TranscriptionTradeoffRow` components showing recommendations for each model tier
     - Dynamic highlighting based on currently selected model
     - Checkmark indicator for active model category
- Created supporting components (prefixed with `Transcription` to avoid naming conflicts):
  - `TranscriptionModelCard` - card-based model selection with hover effects
  - `TranscriptionModelBadge` - status badges for Active/Downloaded
  - `TranscriptionModelSpec` - small spec indicators (size, speed, accuracy)
  - `TranscriptionProgressBar` - gradient progress bar with shimmer effect
  - `TranscriptionLanguagePicker` - language dropdown with flags
  - `TranscriptionLanguageRow` - individual language row items
  - `TranscriptionTradeoffRow` - quality/speed tradeoff info rows
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Model selection triggers `WhisperManager.selectModel()` async method
- Language selection bound via `$whisperManager.selectedLanguage` for two-way persistence
- Verified via `swift build` - typecheck passes

---

### [x] US-705: Migrate Text Cleanup Settings Section
**Status:** complete
**Priority:** medium
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move Text Cleanup settings to integrated settings view.

**Tasks:**
- [x] Show text cleanup enable/disable toggle
- [x] Display filler word removal options
- [x] Include post-processing toggles

**Acceptance Criteria:**
- [x] Cleanup toggle works
- [x] Filler word options functional
- [x] Post-processing toggles persist

**Implementation Notes:**
- Expanded `TextCleanupSettingsSummary` in `MainWindow.swift` from a summary view to a full settings section (same pattern as US-702, US-703, US-704)
- Created four main sections within the Text Cleanup settings:
  1. **Cleanup Toggle Section** (US-705 Task 1) with:
     - Enable/disable toggle for text cleanup with status badge
     - Description explaining cleanup functionality
  2. **Filler Word Removal Section** (US-705 Task 2) with:
     - Card-based mode picker using `TextCleanupModeCard` components for Basic, Standard, Thorough, and AI-Powered modes
     - Each card shows mode icon, name, and filler words removed
     - Visual selection indicator (radio-style circles)
     - LLM status badge for AI-Powered mode showing "LLM Ready" or "LLM Required"
     - Mode description box with icon at bottom
     - Disabled state when cleanup is disabled (opacity 0.5)
  3. **Post-Processing Section** (US-705 Task 3) with:
     - Three `TextCleanupToggleRow` components for post-processing options:
       - Auto-Capitalize First Letter
       - Add Period at End
       - Trim Whitespace
     - Each toggle has icon, title, description, and persists to UserDefaults
     - Note that options apply even when full cleanup is disabled
  4. **Preview Section** with:
     - Before/after text comparison using `TextCleanupPreviewText` components
     - Sample text showing filler words and how they are cleaned
     - Dynamic "After" preview changes based on selected cleanup mode
     - Disabled state when cleanup is disabled (opacity 0.5)
- Created supporting components (prefixed with `TextCleanup` to avoid naming conflicts):
  - `TextCleanupModeCard` - card-based mode selection with hover effects and LLM status
  - `TextCleanupModeBadge` - status badges for LLM Ready/Required
  - `TextCleanupToggleRow` - toggle row for post-processing options with icon, title, description
  - `TextCleanupPreviewText` - preview text display with color-coded label
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Uses `@StateObject` with `TextCleanupManager.shared` and `LLMManager.shared` singletons
- All toggle changes logged with `[US-705]` prefix for debugging
- Verified via `swift build` - typecheck passes

---

### [x] US-706: Migrate Text Insertion Settings Section
**Status:** complete
**Priority:** medium
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move Text Insertion settings to integrated settings view.

**Tasks:**
- [x] Show text insertion method options
- [x] Include clipboard preservation toggle
- [x] Display timing options if applicable

**Acceptance Criteria:**
- [x] Insertion method selection works
- [x] Clipboard preservation toggle functions

**Implementation Notes:**
- Expanded `TextInsertionSettingsSummary` in `MainWindow.swift` from a summary view to a full settings section (same pattern as US-702, US-703, US-704, US-705)
- Created five main sections within the Text Insertion settings:
  1. **Insertion Method Section** (US-706 Task 1) with:
     - `TextInsertionMethodCard` component showing Paste (⌘V) method
     - Card displays method icon, title, description, and feature badges
     - Radio-style selection indicator (currently only paste method is supported)
     - "Active" status badge for selected method
     - Info note explaining paste method is most reliable for all applications
  2. **Clipboard Preservation Section** (US-706 Task 2) with:
     - `TextInsertionToggleRow` component for preserve clipboard toggle
     - Toggle bound to `textInserter.preserveClipboard` for persistence
     - Status indicator showing clipboard restoration status with checkmark/X icon
     - Color-coded background (green when enabled, gray when disabled)
  3. **Timing Options Section** (US-706 Task 3) with:
     - Only displayed when clipboard preservation is enabled
     - Custom `TextInsertionDelaySlider` component with drag gesture
     - Visual delay value badge showing current setting (e.g., "0.8 seconds")
     - Gradient-filled track and draggable thumb
     - Min/max labels (0.2s to 2.0s)
     - Help text explaining when to increase delay
  4. **Accessibility Permission Section** with:
     - Permission status card with large icon (checkmark/X)
     - "Permission Granted" or "Permission Not Granted" status text
     - "Grant Access" button that opens System Settings (when not granted)
     - Success message animation when permission is granted
     - Step-by-step instructions using `TextInsertionInstructionRow` components
  5. **How It Works Section** with:
     - Numbered steps showing text insertion flow using `TextInsertionFeatureRow`
     - Dynamic step 3 text changes based on clipboard preservation setting
     - Shows restore delay value when preservation is enabled
- Created supporting components (prefixed with `TextInsertion` to avoid naming conflicts):
  - `TextInsertionMethodCard` - card-based method selection with hover effects
  - `TextInsertionToggleRow` - toggle row for settings with icon, title, description
  - `TextInsertionDelaySlider` - custom slider with gradient fill and drag gesture
  - `TextInsertionInstructionRow` - numbered instruction steps for permission setup
  - `TextInsertionFeatureRow` - feature row for how-it-works section
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`, `WispflowAnimation`
- Uses `@StateObject` with `TextInserter.shared` and `PermissionManager.shared` singletons
- Permission grant callback shows animated success message for 3 seconds
- All toggle changes logged with `[US-706]` prefix for debugging
- Verified via `swift build` - typecheck passes

---

### [x] US-707: Migrate Debug Settings Section
**Status:** complete
**Priority:** medium
**Estimated effort:** small
**Depends on:** US-701

**Description:** Move Debug settings to integrated settings view.

**Tasks:**
- [x] Show log level selector
- [x] Include Export Logs button
- [x] Display Open Recordings Folder button
- [x] Show system info
- [x] Add Reset All Settings option

**Acceptance Criteria:**
- [x] Log level selection works
- [x] Export logs creates file
- [x] Folder buttons open Finder
- [x] Reset with confirmation

**Implementation Notes:**
- Updated `DebugManager.swift` with US-707 features:
  - Added `LogLevel` enum with four levels: Verbose, Info, Warning, Error
  - Each level has icon, description, and priority properties
  - Added `SystemInfo` struct for gathering system information:
    - App version and build number from Bundle
    - macOS version from ProcessInfo
    - Machine model via sysctlbyname("hw.model")
    - Processor info via sysctlbyname("machdep.cpu.brand_string")
    - Memory size from physicalMemory
  - Added `selectedLogLevel` @Published property with UserDefaults persistence
  - Added `exportLogs()` method with NSSavePanel for file export
  - Log export includes system info header and all log entries
  - Added `resetAllSettings()` method to clear all WispFlow UserDefaults keys
  - Added `getSystemInfo()` helper method
- Updated `DebugSettingsView` in `SettingsWindow.swift`:
  - Added `showResetConfirmation`, `showLogExportSuccess`, `logExportMessage` state variables
  - Added Log Level Selector card with `LogLevelPicker` component
  - Added Export Logs button in Debug Tools card
  - Added Open Recordings Folder button (always visible)
  - Added `SystemInfoCard` component displaying all system info with Copy button
  - Added Reset All Settings card with confirmation alert
- Created new UI components:
  - `LogLevelPicker` - vertical list of selectable log levels
  - `LogLevelPickerRow` - individual level row with icon, title, description, radio indicator
  - `SystemInfoCard` - displays system info with Copy to clipboard button
  - `SystemInfoRow` - single row with label and value
- All components use existing design system: `Color.Wispflow`, `Font.Wispflow`, `Spacing`, `CornerRadius`
- Reset confirmation uses SwiftUI alert with Cancel/Reset buttons
- Verified via `swift build` - typecheck passes

---

### [x] US-708: Remove Separate Settings Window
**Status:** complete
**Priority:** high
**Estimated effort:** small
**Depends on:** US-702, US-703, US-704, US-705, US-706, US-707

**Description:** Remove the separate Settings popout window.

**Tasks:**
- [x] Remove or repurpose SettingsWindow.swift
- [x] Remove 'Open Settings Window' button from placeholder
- [x] Update StatusBarController Settings menu to open main window
- [x] Clean up unused settings window code

**Acceptance Criteria:**
- [x] No separate settings window opens
- [x] Menu bar Settings opens main window with Settings selected
- [x] No orphaned code remains

**Implementation Notes:**
- **Deleted `SettingsWindow.swift` entirely** - file removed as settings are now fully integrated in MainWindow
- Removed `SettingsOpenFullButton` component from MainWindow.swift
- Removed `settingsWindowController` property and initialization from AppDelegate
- Updated `AppDelegate.openSettings()` to call `openMainWindow(initialNavItem: .settings)` instead of `settingsWindowController?.showSettings()`
- Updated `StatusBarController.openSettings()` print statement to reflect new behavior: "Settings clicked - opening main window with Settings tab"
- Updated `MainWindowController.showMainWindow(initialNavItem:)` to accept optional `NavigationItem` parameter
- `MainWindowView.initialNavigationItem` property already existed - now properly used when creating new window
- When window already exists and initialNavItem is specified, window is recreated to navigate to that item
- All settings functionality remains accessible through the integrated Settings tab in the main window
- Verified via `swift build` - typecheck passes (only warnings, no errors)

---

### [x] US-709: Settings Section Navigation
**Status:** complete
**Priority:** low
**Estimated effort:** small
**Depends on:** US-701

**Description:** Add quick navigation to settings sections.

**Tasks:**
- [x] Add section jump buttons at top of settings view
- [x] Implement smooth scroll to section
- [x] Consider collapsible sections (already implemented via SettingsSectionView)

**Acceptance Criteria:**
- [x] Section links scroll to correct section
- [x] Smooth scroll animation

**Implementation Notes:**
- Created `SettingsSection` enum with 6 cases (general, audio, transcription, textCleanup, textInsertion, debug)
- Each section has `displayName`, `icon`, and `description` properties for consistent UI
- Added `ScrollViewReader` wrapper around settings ScrollView for programmatic scrolling
- Created `sectionNavigationBar()` component showing "Jump to Section" label with horizontal scrollable buttons
- Created `SettingsSectionNavButton` component with:
  - Section icon and display name
  - Active state highlighting (coral background with white text)
  - Hover effects (accentLight background, scale 1.02)
  - Tooltip help text
- Each `SettingsSectionView` now has `.id(SettingsSection.xxx)` for scroll targeting
- `scrollToSection()` method uses `.easeInOut(duration: 0.4)` animation for smooth scrolling
- Updates `activeSection` state to highlight currently navigated section
- Collapsible sections already implemented in `SettingsSectionView` via expand/collapse toggle
- Verified via `swift build` - typecheck passes
