# WispFlow v0.3 - Fix Accessibility Detection & Audio Capture

## Overview

This PRD addresses two critical bugs preventing WispFlow from working correctly:
1. Accessibility permission detection not recognizing when permission is granted
2. Audio capture reporting silence despite visible audio level meter activity

## Problem 1: Accessibility Permission Detection

### Current Behavior
- App prompts for accessibility permissions
- User grants permission in System Settings
- App still reports permission not granted
- Text insertion fails

### Root Cause Analysis
- `AXIsProcessTrusted()` may return cached value
- Permission check may not be refreshing after grant
- App may need restart after permission grant (undesirable)

### Required Fix
- Poll for permission changes or use proper callback
- Force re-check after user returns from System Settings
- Add manual "I've granted permission" button as fallback

## Problem 2: Audio Capture Silence Detection

### Current Behavior
- Audio level meter in UI shows activity (green bars)
- After recording stops, app reports "No audio detected"
- Error says audio was under -40dB threshold
- Transcription never happens

### Root Cause Analysis
- Audio level meter and transcription buffer may use different data paths
- Peak level calculation may be incorrect
- Audio buffer may not be accumulating correctly during recording
- Threshold calculation may be in wrong units (linear vs dB)

### Required Fix
- Ensure same audio data feeds both level meter and buffer
- Fix dB calculation: `20 * log10(abs(sample))`
- Verify buffer is actually accumulating samples
- Lower threshold or fix calculation

## Core Features

### 1. Fix Accessibility Permission Detection
- **Polling mechanism** - Check permission state every 1-2 seconds when settings open
- **App activation callback** - Re-check when app becomes active
- **Manual override** - "Check Again" button
- **Clear status display** - Show actual system state

### 2. Fix Audio Buffer Pipeline
- **Unified audio path** - Same buffer feeds level meter AND transcription
- **Correct dB calculation** - Fix formula: `20 * log10(max(abs(samples), 1e-10))`
- **Buffer verification** - Log sample count, duration, actual peak values
- **Lower silence threshold** - Change from -40dB to -55dB

### 3. Audio Capture Diagnostics
- **Pre-transcription logging** - Log exact buffer state before sending to Whisper
- **Sample inspection** - Show first/last N samples to verify data
- **Duration verification** - Confirm buffer duration matches recording time

## Technical Details

### Accessibility Permission Fix
```swift
// Re-check on app activation
NotificationCenter.default.addObserver(
    forName: NSApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main
) { _ in
    self.recheckPermissions()
}
```

### Audio dB Calculation Fix
```swift
// CORRECT:
let peak = samples.map { abs($0) }.max() ?? 0
let db = peak > 0 ? 20 * log10(peak) : -100
```

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.

---

## MVP Scope (v0.3)

### [x] US-201: Fix Accessibility Permission Detection
As a user, I want the app to correctly detect when I've granted accessibility permission so text insertion works.
- [x] Add NSApplication.didBecomeActiveNotification observer to re-check permissions
- [x] Add polling timer (1s interval) when permission not yet granted
- [x] Add "Check Again" button in settings for manual re-check
- [x] Use AXIsProcessTrusted() with fresh check (not cached)
- [x] Show real-time permission status with checkmark/x indicator
- [x] Stop polling once permission is granted

### [x] US-202: Fix Audio Buffer Pipeline
As a user, I want my recorded audio to actually be captured so transcription works.
- [x] Verify AudioManager.audioBuffer is same data shown in level meter
- [x] Fix dB calculation to handle zero values: `20 * log10(max(peak, 1e-10))`
- [x] Add logging of actual sample values before silence check
- [x] Lower silence threshold from -40dB to -55dB
- [x] Ensure convertedBuffer is being appended to audioBuffer correctly
- [x] Add buffer sample count verification

### [ ] US-203: Audio Capture Diagnostics
As a developer, I want detailed audio diagnostics so I can debug capture issues.
- Log buffer state immediately before transcription call
- Show sample count, duration, peak level, RMS level
- Log first and last 10 samples to verify non-zero data
- Show percentage of zero vs non-zero samples
- Add console output for all audio pipeline stages

### [ ] US-204: Permission Flow UX
As a user, I want clear guidance on granting permissions so I can set up the app correctly.
- Add step-by-step permission grant instructions in Settings
- Show current permission state with colored indicator (red/green)
- Add direct "Open System Settings" button
- Show "Permission Granted!" confirmation when detected
- Remember and skip permission prompts once granted

### [ ] US-205: Silence Detection Fix
As a user, I want accurate silence detection so valid audio isn't rejected.
- Fix peak level calculation to use actual max absolute value
- Change threshold from -40dB to -55dB (more permissive)
- Add "Silence detected" only if ALL samples are near-zero
- Show actual measured dB level in error message
- Allow user to disable silence detection in debug mode

## Success Criteria

1. Grant accessibility permission -> app detects it within 2 seconds
2. Speak into microphone -> audio is captured (not reported as silence)
3. Audio level meter activity -> matches actual captured buffer
4. Permission status -> accurately reflects system state

## Acceptance Criteria

1. Grant accessibility in System Settings -> return to app -> permission detected
2. Record 3 seconds of speech -> buffer contains >48000 samples
3. Audio with visible level meter -> peak level > -55dB
4. Permission granted -> green checkmark shown in settings
5. All audio stats logged before transcription attempt
