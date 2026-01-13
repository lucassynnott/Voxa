# Implementation Plan - WispFlow v0.3

## Summary

WispFlow v0.2 (US-101 through US-106) is complete with debug audio capture, WhisperKit audio format fixes, model loading improvements, error handling, debug mode, and local LLM cleanup.

**v0.3 focuses on fixing two critical bugs** preventing WispFlow from working correctly:
1. **Accessibility permission detection** - App doesn't recognize when permission is granted (requires restart)
2. **Audio capture silence detection** - Audio is captured (level meter shows activity) but reported as silent for transcription

### Key Gaps to Address:
1. **Accessibility polling** - Current `AXIsProcessTrusted()` call returns cached value; no re-check mechanism after user grants permission
2. **Audio buffer pipeline integrity** - Level meter shows activity but same data may not reach transcription buffer
3. **Silence threshold** - Current -40dB may be too aggressive; PRD specifies -55dB
4. **Permission UX** - No polling timer, no app activation callback, no manual "Check Again" button
5. **Audio diagnostics** - Need to verify same buffer feeds both level meter AND transcription

### Priority Order:
1. US-201 (Accessibility Permission Detection) - Critical for text insertion to work
2. US-202 (Audio Buffer Pipeline) - Critical for transcription to work
3. US-205 (Silence Detection Fix) - Required to avoid false silence rejections
4. US-204 (Permission Flow UX) - Better user guidance
5. US-203 (Audio Capture Diagnostics) - Developer debugging

---

## Tasks

### US-201: Fix Accessibility Permission Detection
As a user, I want the app to correctly detect when I've granted accessibility permission so text insertion works.

- [x] Add NSApplication.didBecomeActiveNotification observer for permission re-check
  - Scope: Modify `Sources/WispFlow/TextInserter.swift` to add observer in init that calls `recheckPermission()` when app becomes active
  - Acceptance: After granting permission in System Settings and returning to app, `hasAccessibilityPermission` returns true
  - Verification: `swift build` passes; grant permission in System Settings, return to app, verify permission detected
  - **DONE**: Added `setupAppActivationObserver()` in init that listens to `NSApplication.didBecomeActiveNotification`

- [x] Add polling timer for permission status when not granted
  - Scope: Modify `Sources/WispFlow/TextInserter.swift` to add Timer that polls `AXIsProcessTrusted()` every 1 second when permission not yet granted
  - Acceptance: Timer starts when permission denied, polls until granted, then stops
  - Verification: `swift build` passes; start app without permission, grant permission in System Settings, verify detection within 2 seconds
  - **DONE**: Added 1-second interval polling timer `permissionPollingTimer` that starts automatically when permission not granted

- [x] Add "Check Again" button to Settings for manual permission re-check
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` `TextInsertionSettingsView` to add button that calls `recheckPermission()` and shows result
  - Acceptance: Button visible when permission not granted; clicking re-checks and updates UI
  - Verification: `swift build` passes; grant permission, click "Check Again", verify status updates to "Granted"
  - **DONE**: Added "Check Again" button that calls `textInserter.recheckPermission()`

- [x] Make hasAccessibilityPermission @Published for reactive UI updates
  - Scope: Modify `Sources/WispFlow/TextInserter.swift` to change `hasAccessibilityPermission` from computed property to `@Published` property updated by polling/notifications
  - Acceptance: Settings UI updates automatically when permission status changes
  - Verification: `swift build` passes; grant permission while Settings is open, verify UI updates automatically
  - **DONE**: Changed from computed property to `@Published private(set) var hasAccessibilityPermission: Bool = false`

- [x] Add real-time permission status indicator with checkmark/x
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` `TextInsertionSettingsView` to show ✓ (green) or ✗ (red) icon based on permission status
  - Acceptance: Visual indicator clearly shows current permission state
  - Verification: `swift build` passes; verify checkmark shows when granted, x shows when denied
  - **DONE**: Added `checkmark.circle.fill` (green) / `xmark.circle.fill` (red) SF Symbol icons

- [x] Stop polling once permission is granted
  - Scope: Modify `Sources/WispFlow/TextInserter.swift` polling timer logic to invalidate timer when permission is granted
  - Acceptance: No unnecessary CPU usage once permission is detected
  - Verification: `swift build` passes; grant permission, verify timer stops (check console logs)
  - **DONE**: `recheckPermission()` calls `stopPermissionPolling()` when permission status changes to granted

---

### US-202: Fix Audio Buffer Pipeline
As a user, I want my recorded audio to actually be captured so transcription works.

- [x] Verify AudioManager.audioBuffer is same data shown in level meter
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to add logging in tap callback confirming same buffer feeds both level meter calculation AND audioBuffers array
  - Acceptance: Logs show identical buffer objects for level meter and storage
  - Verification: `swift build` passes; record audio, verify console shows single buffer path
  - **DONE**: Added comment and logging confirming level meter and transcription buffer use THE SAME input buffer in tap callback

- [x] Fix dB calculation to handle zero values safely
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` `amplitudeToDecibels()` to use formula `20 * log10(max(peak, 1e-10))` instead of current implementation
  - Acceptance: dB calculation never returns NaN or -Infinity for valid audio
  - Verification: `swift build` passes; record silence, verify dB shows -100 not -Infinity
  - **DONE**: Updated `amplitudeToDecibels()` to use `max(amplitude, 1e-10)` floor, clamping output to [-100, 0] dB range

- [x] Add logging of actual sample values before silence check
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` `stopCapturing()` to log first 10 and last 10 sample values before silence check
  - Acceptance: Console shows actual sample values for debugging
  - Verification: `swift build` passes; record audio, verify sample values logged
  - **DONE**: Added logging of first 10 and last 10 samples, plus zero sample percentage in `combineBuffersToDataWithStats()`

- [x] Lower silence threshold from -40dB to -55dB
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` and `RecordingIndicatorWindow.swift` Constants.silenceThresholdDB
  - Acceptance: More permissive threshold allows quieter but valid audio to pass
  - Verification: `swift build` passes; record quiet speech, verify not rejected as silence
  - **DONE**: Changed threshold from -40dB to -55dB in both AudioManager and RecordingIndicatorWindow

- [x] Ensure convertedBuffer is being appended to audioBuffers correctly
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` tap callback to log buffer append confirmation with frame count
  - Acceptance: Each converted buffer is confirmed appended with sample count
  - Verification: `swift build` passes; record audio, verify buffer append logs match expected counts
  - **DONE**: Added logging of buffer append count and total frames (every 10th buffer to avoid spam)

- [x] Add buffer sample count verification after combining
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` `combineBuffersToDataWithStats()` to verify combined sample count matches sum of individual buffer frame lengths
  - Acceptance: Warning logged if sample count mismatch detected
  - Verification: `swift build` passes; record audio, verify no mismatch warnings
  - **DONE**: Added expected vs actual sample count verification with warning if mismatch occurs

---

### US-203: Audio Capture Diagnostics
As a developer, I want detailed audio diagnostics so I can debug capture issues.

- [x] Log buffer state immediately before transcription call
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` `processTranscription()` to log audioData.count, expected duration, sample rate before calling whisper.transcribe()
  - Acceptance: Full buffer state logged right before WhisperKit receives data
  - Verification: `swift build` passes; record and transcribe, verify pre-transcription log
  - **DONE**: WhisperManager.logAudioDiagnostics() logs full buffer state (byte count, sample count, duration, peak, RMS) immediately before transcription in Stage 5

- [x] Show sample count, duration, peak level, RMS level before transcription
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` or create helper to compute and log these stats from audioData before transcription
  - Acceptance: All four metrics visible in console before transcription attempt
  - Verification: `swift build` passes; verify all four values logged
  - **DONE**: WhisperManager.logAudioDiagnostics() shows all four metrics in Stage 5 box: Sample Count, Duration, Peak Level, RMS Level

- [x] Log first and last 10 samples to verify non-zero data
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` or WhisperManager to extract and log first 10 and last 10 Float32 samples from audioData
  - Acceptance: Console shows actual sample values, can verify if data is zeros or valid audio
  - Verification: `swift build` passes; record audio, verify sample values are non-zero
  - **DONE**: WhisperManager.logAudioDiagnostics() logs first 10 and last 10 samples in Stage 5; AudioManager.combineBuffersToDataWithStats() also logs them in Stage 4

- [x] Show percentage of zero vs non-zero samples
  - Scope: Create helper function to count zero samples (abs < 1e-7) vs total and compute percentage
  - Acceptance: Log shows "Zero samples: X% (Y/Z)" format
  - Verification: `swift build` passes; record audio, verify zero percentage < 50%
  - **DONE**: Both AudioManager (Stage 4) and WhisperManager (Stage 5) show zero sample percentage; AudioManager also shows non-zero percentage

- [x] Add console output for all audio pipeline stages
  - Scope: Add labeled log statements at: capture, conversion, buffer append, combine, transcription handoff
  - Acceptance: Console shows complete audio flow with timestamps
  - Verification: `swift build` passes; record audio, verify all stage markers visible
  - **DONE**: Added 5 clearly labeled stages with box headers:
    - Stage 1: CAPTURE START (AudioManager - permission, device, format setup, engine start)
    - Stage 2: TAP INSTALLED (AudioManager - audio conversion, buffer appends with level meter)
    - Stage 3: CAPTURE STOP (AudioManager - engine stop, duration calculation)
    - Stage 4: BUFFER COMBINE (AudioManager - buffer merge, sample values, statistics, silence check)
    - Stage 5: TRANSCRIPTION HANDOFF (WhisperManager - final audio diagnostics before WhisperKit)

---

### US-204: Permission Flow UX
As a user, I want clear guidance on granting permissions so I can set up the app correctly.

- [ ] Add step-by-step permission grant instructions in Settings
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` `TextInsertionSettingsView` to show numbered steps when permission not granted
  - Acceptance: Clear 1-2-3 steps visible explaining how to grant permission
  - Verification: `swift build` passes; view Settings without permission, verify instructions visible

- [ ] Show current permission state with colored indicator (red/green)
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` to use SF Symbol with red (denied) or green (granted) color
  - Acceptance: Color clearly indicates permission state at a glance
  - Verification: `swift build` passes; verify red when denied, green when granted

- [ ] Add direct "Open System Settings" button
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` to add button that opens System Settings > Privacy & Security > Accessibility
  - Acceptance: One-click access to correct System Settings pane
  - Verification: `swift build` passes; click button, verify correct System Settings pane opens

- [ ] Show "Permission Granted!" confirmation when detected
  - Scope: Modify `Sources/WispFlow/TextInserter.swift` or SettingsWindow to show temporary success message when permission transitions from denied to granted
  - Acceptance: User sees confirmation that permission was successfully detected
  - Verification: `swift build` passes; grant permission, verify success message appears

- [ ] Remember and skip permission prompts once granted
  - Scope: Verify current implementation doesn't repeatedly prompt after permission is granted; add check if needed
  - Acceptance: No permission prompts shown after permission is granted
  - Verification: `swift build` passes; grant permission, restart app, verify no prompt

---

### US-205: Silence Detection Fix
As a user, I want accurate silence detection so valid audio isn't rejected.

- [ ] Change silence threshold from -40dB to -55dB
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` `Constants.silenceThresholdDB` from -40.0 to -55.0
  - Acceptance: More permissive threshold allows quieter but valid audio to pass
  - Verification: `swift build` passes; record quiet speech, verify not rejected as silence

- [ ] Update RecordingIndicatorWindow level meter threshold to match
  - Scope: Modify `Sources/WispFlow/RecordingIndicatorWindow.swift` `Constants.silenceThreshold` from -40 to -55
  - Acceptance: Level meter visual threshold matches AudioManager threshold
  - Verification: `swift build` passes; verify level meter shows gray only below -55dB

- [ ] Fix peak level calculation to use actual max absolute value
  - Scope: Verify `Sources/WispFlow/AudioManager.swift` `calculateBufferStatistics()` correctly computes max(abs(minSample), abs(maxSample))
  - Acceptance: Peak level accurately reflects loudest sample in recording
  - Verification: `swift build` passes; verify peak level calculation is correct

- [ ] Add "Silence detected" only if ALL samples are near-zero
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` silence detection to check if >95% of samples are below threshold, not just peak
  - Acceptance: Recordings with brief speech surrounded by silence are not rejected
  - Verification: `swift build` passes; record short phrase, verify not marked as silence

- [ ] Show actual measured dB level in error message
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` `showSilenceWarning()` to include actual peak dB level in alert text
  - Acceptance: User can see what level was detected vs threshold
  - Verification: `swift build` passes; trigger silence warning, verify shows actual dB value

- [ ] Update all -40dB references in error messages to -55dB
  - Scope: Search and update all hardcoded -40dB strings in AppDelegate, SettingsWindow, WhisperManager
  - Acceptance: All user-facing messages reflect correct -55dB threshold
  - Verification: `swift build` passes; verify no -40dB references remain in user messages

---

## Notes

### Discoveries

1. **Accessibility permission issue** - `AXIsProcessTrusted()` returns a cached value. macOS doesn't provide a notification when accessibility permission changes, so polling or app activation callbacks are the only solutions.

2. **Audio buffer path verified** - Current code uses the same tap callback for both level meter updates AND buffer storage. The issue is likely in the dB calculation or threshold, not separate data paths.

3. **Current silence threshold** - The -40dB threshold in `AudioManager.swift` line 56 is too aggressive. Normal speech typically peaks at -20dB to -6dB, but quiet speakers or distant microphones can peak at -35dB to -45dB.

4. **Level meter vs transcription buffer** - Both use the same `audioBuffers` array populated in the tap callback. The level meter calculates from the raw input buffer, while transcription uses the converted 16kHz buffer. This is correct but worth verifying.

5. **Settings UI permission state** - Current implementation uses a computed property `hasAccessibilityPermission` which doesn't trigger SwiftUI updates when permission changes externally. Need to make it @Published.

### Risks

1. **Polling overhead** - 1-second polling timer for accessibility permission is minimal CPU cost but should be stopped once permission is granted.

2. **Threshold sensitivity** - Changing from -40dB to -55dB will allow more quiet audio through, potentially including environmental noise. This is acceptable per PRD requirements.

3. **Cached permission value** - macOS may cache `AXIsProcessTrusted()` result. The app activation callback should force a fresh check.

### Technical Notes

- `AXIsProcessTrusted()` is the standard API for checking accessibility permission
- `NSApplication.didBecomeActiveNotification` fires when app comes to foreground
- Audio dB calculation: `20 * log10(amplitude)` where amplitude is in [0.0, 1.0] range
- WhisperKit expects 16kHz mono Float32 audio with samples in [-1.0, 1.0] range
