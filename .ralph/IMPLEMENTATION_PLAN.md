# Implementation Plan: Audio, Permissions & Hotkeys Overhaul

**PRD Source:** `.agents/tasks/prd-audio-permissions-hotkeys-overhaul.md`
**Generated:** 2026-01-14

---

## Overview

This plan implements a comprehensive overhaul of WispFlow's core systems based on Voquill patterns. The implementation is ordered to fix blocking issues first (Settings UI), then core functionality (audio, permissions, hotkeys), and finally polish (onboarding).

---

## Phase 1: Settings UI Fixes (Unblocks Testing)

### US-523: Fix Tab Visibility
**Status:** pending
**Priority:** critical
**Estimated effort:** small

**Description:** Fix Settings window tabs being invisible/unclickable due to ZStack overlay.

**Tasks:**
- [ ] Remove ZStack with Color background that covers TabView
- [ ] Ensure all 6 tabs visible and clickable
- [ ] Verify tab switching works
- [ ] Test on macOS 14+

**Acceptance Criteria:**
- All 6 tabs visible: General, Audio, Transcription, Text Cleanup, Text Insertion, Debug
- Tab labels readable with proper contrast
- Tabs clickable and switch content
- Typecheck passes

---

### US-524: Fix Button Interactivity
**Status:** pending
**Priority:** critical
**Estimated effort:** small

**Description:** Fix buttons in Settings not responding to clicks due to @State in ButtonStyle.

**Tasks:**
- [ ] Refactor WispflowButtonStyle to use wrapper View for @State
- [ ] Move hover state tracking to WispflowButtonContent view
- [ ] Add console logging to button actions for debugging
- [ ] Test all buttons in Settings

**Acceptance Criteria:**
- All buttons respond to clicks
- Hover states visible
- Press animation works
- Console logs confirm button actions
- Typecheck passes

---

### US-525: Fix ScrollView Interactions
**Status:** pending
**Priority:** high
**Estimated effort:** small

**Tasks:**
- [ ] Verify ScrollView scrolls smoothly
- [ ] Test all interactive elements inside cards
- [ ] Add contentShape if needed for hit testing
- [ ] Test toggles, dropdowns, sliders

**Acceptance Criteria:**
- ScrollView scrolls smoothly
- All interactive elements clickable
- Toggle switches work
- Dropdown menus open
- Typecheck passes

---

## Phase 2: Audio System Overhaul

### US-503: Robust Audio Engine Initialization
**Status:** pending
**Priority:** critical
**Estimated effort:** medium

**Description:** Fix audio engine initialization sequence to ensure tap receives data.

**Tasks:**
- [ ] Reset audio engine before each recording
- [ ] Prepare engine before setting input device
- [ ] Set input device after preparation
- [ ] Query format after device is set
- [ ] Connect input to muted mixer sink
- [ ] Add detailed logging at each stage

**Acceptance Criteria:**
- Engine reset → prepare → set device → get format → install tap → start
- Invalid format throws clear error
- Tap callbacks logged during recording
- Typecheck passes

---

### US-504: Audio Level Preview Fix
**Status:** pending
**Priority:** critical
**Estimated effort:** medium

**Description:** Make audio preview in Settings actually show microphone levels.

**Tasks:**
- [ ] Add logging to togglePreview() function
- [ ] Verify permission callback fires
- [ ] Ensure startCapturing() succeeds
- [ ] Update currentLevel at 20fps
- [ ] Show proper status text

**Acceptance Criteria:**
- "Start Preview" triggers audio capture
- Level meter updates in real-time
- Level displayed in dB with color coding
- Status shows Good/Quiet/Loud/Silent
- Typecheck passes

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
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Description:** Cache last successful device for fast recording start.

**Tasks:**
- [ ] Store last device in memory
- [ ] Try cached device first on recording start
- [ ] Invalidate cache on manual device change
- [ ] Invalidate cache on device disconnect

**Acceptance Criteria:**
- Cached device used on subsequent recordings
- First recording ~100-200ms, subsequent ~10-20ms
- Cache invalidated appropriately
- Typecheck passes

---

### US-505: Low-Quality Device Warning
**Status:** pending
**Priority:** low
**Estimated effort:** small

**Description:** Warn users when using potentially low-quality audio input.

**Tasks:**
- [ ] Flag devices matching low-quality keywords
- [ ] Show warning icon in device picker
- [ ] Add tooltip explaining quality concern
- [ ] Show toast when recording with flagged device

**Acceptance Criteria:**
- Warning icon on flagged devices
- Tooltip explains quality concern
- Toast notification on recording start
- Warning doesn't block recording
- Typecheck passes

---

## Phase 3: Permission System Overhaul

### US-506: Permission Status Tracking
**Status:** pending
**Priority:** high
**Estimated effort:** small

**Description:** Accurate real-time permission status tracking.

**Tasks:**
- [ ] Check mic via AVCaptureDevice.authorizationStatus
- [ ] Check accessibility via AXIsProcessTrusted()
- [ ] Poll permissions when app becomes active
- [ ] Publish status changes to UI

**Acceptance Criteria:**
- Correct status enum returned
- Status updates on app activation
- Published properties trigger UI updates
- Typecheck passes

---

### US-507: Automatic Permission Prompting
**Status:** pending
**Priority:** high
**Estimated effort:** medium

**Description:** Show permission dialogs automatically when needed.

**Tasks:**
- [ ] Request mic permission on first recording if notDetermined
- [ ] Request accessibility on first text insertion
- [ ] Open System Settings if previously denied
- [ ] Add permission prompt to setupTextInserter

**Acceptance Criteria:**
- System permission dialog shown when appropriate
- Denied permissions open System Settings
- Typecheck passes

---

### US-508: Open System Settings Helper
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Description:** Open correct System Settings pane directly.

**Tasks:**
- [ ] Implement openMicrophoneSettings() with URL scheme
- [ ] Implement openAccessibilitySettings() with URL scheme
- [ ] Add fallback for older macOS versions
- [ ] Test on macOS 13+

**Acceptance Criteria:**
- Opens Privacy & Security > Microphone
- Opens Privacy & Security > Accessibility
- Works on macOS 13+
- Typecheck passes

---

### US-509: Permission Status UI
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Description:** Show permission status in Settings with visual indicators.

**Tasks:**
- [ ] Add status icon (✓/✗) for each permission
- [ ] Add "Grant Permission" button when not granted
- [ ] Button opens appropriate Settings pane
- [ ] Auto-update status when user returns

**Acceptance Criteria:**
- Green checkmark when granted
- Red X when denied
- Button opens Settings
- Status updates automatically
- Typecheck passes

---

## Phase 4: Hotkey System Overhaul

### US-510: Global Event Tap for Hotkeys
**Status:** pending
**Priority:** critical
**Estimated effort:** large

**Description:** Implement reliable global hotkey detection using CGEvent tap.

**Tasks:**
- [ ] Create CGEvent tap at session level
- [ ] Register for key down events
- [ ] Check for modifier keys (Cmd, Shift, Option, Control)
- [ ] Match against configured hotkey
- [ ] Trigger recording toggle on match
- [ ] Handle accessibility permission requirement

**Acceptance Criteria:**
- Hotkey works from any focused application
- Works when WispFlow window not visible
- Requires accessibility permission
- Typecheck passes

---

### US-511: Hotkey Recording in Settings
**Status:** pending
**Priority:** medium
**Estimated effort:** medium

**Description:** Allow users to customize hotkey by recording key combination.

**Tasks:**
- [ ] Add "Record Hotkey" button
- [ ] Show pulsing indicator during recording
- [ ] Capture next key combination with modifiers
- [ ] Validate combination has modifier
- [ ] Persist to UserDefaults
- [ ] Display human-readable format

**Acceptance Criteria:**
- Recording mode with visual indicator
- Key combination captured correctly
- Escape cancels recording
- Invalid combinations rejected
- Typecheck passes

---

### US-512: Hotkey Conflict Detection
**Status:** pending
**Priority:** low
**Estimated effort:** small

**Description:** Warn about conflicts with system shortcuts.

**Tasks:**
- [ ] Define list of common system shortcuts
- [ ] Check new hotkey against list
- [ ] Show warning if conflict detected
- [ ] Allow user to proceed anyway

**Acceptance Criteria:**
- Warning shown for conflicts
- User can proceed despite warning
- Reset to default available
- Typecheck passes

---

## Phase 5: Text Insertion Improvements

### US-513: Clipboard Preservation
**Status:** pending
**Priority:** high
**Estimated effort:** medium

**Description:** Preserve clipboard content during text insertion.

**Tasks:**
- [ ] Save clipboard before insertion
- [ ] Place transcription on clipboard
- [ ] Simulate Cmd+V paste
- [ ] Restore original clipboard after 800ms
- [ ] Use background thread for restoration

**Acceptance Criteria:**
- Original clipboard saved
- Transcription pasted
- Original restored after delay
- Typecheck passes

---

### US-514: Keyboard Event Simulation
**Status:** pending
**Priority:** high
**Estimated effort:** medium

**Description:** Reliable keyboard simulation for paste operations.

**Tasks:**
- [ ] Use CGEvent for key simulation
- [ ] Create key down event with Cmd modifier
- [ ] Add 10ms delay between down and up
- [ ] Post to HID event tap location
- [ ] Test in various applications

**Acceptance Criteria:**
- CGEvent used (not AppleScript)
- Works in Electron apps
- Works in native apps
- Typecheck passes

---

### US-515: Text Insertion Fallback
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Description:** Fallback when keyboard simulation fails.

**Tasks:**
- [ ] Detect paste simulation failure
- [ ] Keep text on clipboard
- [ ] Show toast notification
- [ ] Log error details

**Acceptance Criteria:**
- Fallback to manual paste
- Toast shows "Press Cmd+V to paste"
- Error logged
- Typecheck passes

---

## Phase 6: Onboarding Wizard

### US-516: First Launch Detection
**Status:** pending
**Priority:** high
**Estimated effort:** small

**Tasks:**
- [ ] Check UserDefaults for hasCompletedOnboarding
- [ ] Show wizard if flag not set
- [ ] Set flag after completion

**Acceptance Criteria:**
- First launch detected correctly
- Flag persists across launches
- Typecheck passes

---

### US-517: Onboarding Welcome Screen
**Status:** pending
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [ ] Create OnboardingWindow view
- [ ] Design welcome screen with logo
- [ ] Add feature highlights
- [ ] Add "Get Started" and "Skip" buttons

**Acceptance Criteria:**
- Welcome screen shown on first launch
- Logo and description visible
- Navigation buttons work
- Typecheck passes

---

### US-518: Microphone Permission Step
**Status:** pending
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [ ] Create mic permission screen
- [ ] Show current status
- [ ] Add "Grant Access" button
- [ ] Update status after permission

**Acceptance Criteria:**
- Permission status displayed
- Button triggers system dialog
- Status updates on grant
- Typecheck passes

---

### US-519: Accessibility Permission Step
**Status:** pending
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [ ] Create accessibility permission screen
- [ ] Show current status
- [ ] Add "Open System Settings" button
- [ ] Show instructions for enabling

**Acceptance Criteria:**
- Status displayed
- Button opens Settings
- Instructions clear
- Status updates on return
- Typecheck passes

---

### US-520: Audio Test Step
**Status:** pending
**Priority:** medium
**Estimated effort:** medium

**Tasks:**
- [ ] Create audio test screen
- [ ] Add live level meter
- [ ] Add device selector
- [ ] Add "Sounds Good!" button

**Acceptance Criteria:**
- Level meter shows mic input
- Device selector works
- Can proceed when satisfied
- Typecheck passes

---

### US-521: Hotkey Introduction Step
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Tasks:**
- [ ] Create hotkey intro screen
- [ ] Display default hotkey
- [ ] Add "Try it now" prompt
- [ ] Add visual feedback on press

**Acceptance Criteria:**
- Hotkey displayed clearly
- Feedback on press
- Option to customize
- Typecheck passes

---

### US-522: Onboarding Completion
**Status:** pending
**Priority:** medium
**Estimated effort:** small

**Tasks:**
- [ ] Create completion screen
- [ ] Show success checkmarks
- [ ] Set hasCompletedOnboarding flag
- [ ] Close wizard and show menu bar

**Acceptance Criteria:**
- Success state shown
- Flag persisted
- App ready to use
- Typecheck passes

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
