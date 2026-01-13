# Implementation Plan

## Summary

WispFlow is a macOS voice-to-text application. **US-001 is complete**—the project has a working menu bar app foundation. The MVP requires building a native Swift/SwiftUI menu bar app with:

1. System tray presence and recording toggle (US-001)
2. Global hotkey activation (US-002)
3. Audio capture via AVAudioEngine (US-003)
4. Local Whisper transcription (US-004)
5. AI text cleanup via local LLM (US-005)
6. Text insertion via pasteboard (US-006)
7. Settings persistence (US-007)

The implementation should proceed in dependency order: project scaffolding → menu bar → hotkey → audio → transcription → cleanup → insertion → settings.

---

## Tasks

### US-001: Menu Bar App Foundation ✅

- [x] Create Xcode project structure
  - Scope: Create a new Swift Package or Xcode project at the repo root with SwiftUI app lifecycle targeting macOS 13.0+. Configure for both Apple Silicon and Intel.
  - Acceptance: Project compiles successfully, produces a .app bundle
  - Verification: `swift build` or `xcodebuild -scheme WispFlow build`
  - **Completed**: Package.swift with SPM, targets macOS 13.0+, builds successfully

- [x] Implement NSStatusItem menu bar presence
  - Scope: Create `AppDelegate.swift` or modify SwiftUI App to create NSStatusItem. Add microphone SF Symbol icon. Configure as agent/accessory app (no dock icon).
  - Acceptance: App appears only in menu bar with microphone icon, not in dock
  - Verification: Launch app and visually confirm menu bar icon; verify `LSUIElement` is set in Info.plist
  - **Completed**: StatusBarController.swift creates NSStatusItem, LSUIElement=true in Info.plist

- [x] Add recording state icon toggle
  - Scope: Create recording state enum (idle/recording). Update NSStatusItem icon based on state (outline mic for idle, filled mic for recording).
  - Acceptance: Icon visually changes between idle and recording states
  - Verification: Programmatically toggle state and observe icon change
  - **Completed**: RecordingState.swift with "mic" (idle) and "mic.fill" (recording) SF Symbols

- [x] Implement left-click toggle recording
  - Scope: Add button action to NSStatusItem that toggles recording state on left click.
  - Acceptance: Clicking menu bar icon toggles between idle/recording states
  - Verification: Click icon and observe state toggle
  - **Completed**: statusItemClicked handles left clicks, calls toggleRecording()

- [x] Implement right-click context menu
  - Scope: Add NSMenu to NSStatusItem with items: Settings, Quit. Wire up Quit to terminate app.
  - Acceptance: Right-clicking shows menu with Settings and Quit options
  - Verification: Right-click icon and verify menu appears; click Quit and verify app terminates
  - **Completed**: setupMenu() creates menu with Settings, Launch at Login, Quit items

- [x] Add launch at login capability
  - Scope: Use SMAppService (macOS 13+) to register/unregister launch at login. Add toggle in settings.
  - Acceptance: User can enable/disable launch at login; setting persists after app restart
  - Verification: Enable launch at login, restart Mac (or check System Settings > Login Items), verify app launches
  - **Completed**: SMAppService integration with register/unregister in StatusBarController.swift

---

### US-002: Global Hotkey Recording ✅

- [x] Implement global hotkey listener
  - Scope: Create `HotkeyManager.swift` using CGEvent tap or NSEvent.addGlobalMonitorForEvents. Default hotkey: Cmd+Shift+Space.
  - Acceptance: Hotkey triggers callback when pressed from any application
  - Verification: Focus different app (e.g., Finder), press hotkey, verify callback fires
  - **Completed**: HotkeyManager.swift using NSEvent.addGlobalMonitorForEvents and addLocalMonitorForEvents. Default hotkey: Cmd+Shift+Space (⌘⇧Space). Includes configurable hotkey support.

- [x] Connect hotkey to recording toggle
  - Scope: Wire hotkey callback to toggle recording state in the app's state management.
  - Acceptance: Pressing global hotkey toggles recording on/off
  - Verification: Press hotkey from various apps and observe recording state toggle
  - **Completed**: HotkeyManager.onHotkeyPressed callback connected to statusBarController.toggle() in AppDelegate.swift.

- [x] Create floating recording indicator
  - Scope: Create `RecordingIndicatorWindow.swift` as a floating NSPanel/NSWindow. Show pill-shaped overlay with recording icon and cancel button. Position near cursor or screen corner.
  - Acceptance: Indicator appears when recording starts, disappears when stopped
  - Verification: Start recording and verify indicator appears; stop and verify it disappears
  - **Completed**: RecordingIndicatorWindow.swift as NSPanel with pill-shaped overlay. Uses NSVisualEffectView for blur background. Positioned at top center of screen. Shows/hides with animation on recording state change.

- [x] Add cancel button to indicator
  - Scope: Add X button to recording indicator that stops recording and discards audio.
  - Acceptance: Clicking cancel stops recording without inserting text
  - Verification: Start recording, click cancel, verify recording stops and no text is inserted
  - **Completed**: Cancel button (xmark.circle.fill SF Symbol) with onCancel callback that sets recording state to idle.

---

### US-003: Audio Capture ✅

- [x] Implement microphone permission request
  - Scope: Create `AudioManager.swift`. Request microphone permission using AVCaptureDevice.requestAccess. Show appropriate UI if denied.
  - Acceptance: App prompts for microphone permission on first use; handles denial gracefully
  - Verification: Reset permissions (`tccutil reset Microphone com.wispflow.WispFlow`), launch app, verify permission prompt
  - **Completed**: AudioManager.swift with requestMicrophonePermission(), showMicrophonePermissionAlert(), and permissionStatus property. Shows NSAlert guiding user to System Settings if permission denied.

- [x] Set up AVAudioEngine for capture
  - Scope: Configure AVAudioEngine with input node. Set appropriate sample rate (16kHz for Whisper). Install tap on input node.
  - Acceptance: Audio engine captures microphone input when started
  - Verification: Log audio buffer levels to confirm capture is working
  - **Completed**: AVAudioEngine configured with input node, sample rate conversion to 16kHz mono Float32 for Whisper compatibility. Tap installed on input node with 4096 buffer size.

- [x] Implement audio buffer accumulation
  - Scope: Accumulate audio buffers during recording session. Convert to format required by Whisper (16kHz mono Float32).
  - Acceptance: Audio data is accumulated and available for transcription
  - Verification: Record audio, verify buffer contains expected duration of samples
  - **Completed**: Audio buffers accumulated in array during recording, with AVAudioConverter for sample rate/channel conversion. combineBuffersToData() converts to Data.

- [x] Add start/stop recording controls
  - Scope: Implement startRecording() and stopRecording() methods. Return accumulated audio data on stop.
  - Acceptance: Recording starts/stops cleanly; audio data is returned
  - Verification: Start recording, speak, stop recording, verify audio data is non-empty
  - **Completed**: startCapturing() and stopCapturing() methods. stopCapturing() returns AudioCaptureResult with audioData, duration, and sampleRate. cancelCapturing() discards audio.

- [x] Add audio input device selection
  - Scope: List available audio input devices. Allow user to select which microphone to use. Remember selection between sessions.
  - Acceptance: User can select audio input device from menu; selection persists
  - Verification: Open Audio Input submenu, verify devices listed, select a device, restart app, verify selection persisted
  - **Completed**: enumerateAudioInputDevices() using Core Audio APIs. selectDevice() method. Device selection stored in UserDefaults. Audio Input submenu in StatusBarController with device picker. Device change listener for hot-plug support.

---

### US-004: Local Whisper Transcription

- [ ] Integrate whisper.cpp Swift bindings
  - Scope: Add whisper.cpp as a Swift Package dependency (e.g., via SPM or vendored). Create `WhisperManager.swift` wrapper.
  - Acceptance: whisper.cpp compiles and links with the app
  - Verification: `swift build` succeeds with whisper.cpp dependency

- [ ] Implement model download manager
  - Scope: Create `ModelDownloader.swift` to download Whisper models from Hugging Face. Support tiny, base, small, medium sizes. Show download progress. Store models in Application Support.
  - Acceptance: User can download models; progress is shown; models persist
  - Verification: Trigger download, verify progress updates, verify model file exists after completion

- [ ] Create model management UI
  - Scope: Add Settings tab for model management. List available models with download/delete buttons. Show currently selected model.
  - Acceptance: User can view, download, delete, and select models
  - Verification: Open settings, download a model, select it, delete another model

- [ ] Implement transcription pipeline
  - Scope: Load selected model. Accept audio data. Run Whisper inference. Return transcribed text.
  - Acceptance: Audio input produces text output with >90% accuracy on clear speech
  - Verification: Record "Hello world, this is a test", verify transcription matches

- [ ] Add transcription progress/status
  - Scope: Update UI during transcription (e.g., "Transcribing..." indicator). Handle transcription errors gracefully.
  - Acceptance: User sees feedback during transcription; errors show helpful messages
  - Verification: Trigger transcription, verify status updates appear

---

### US-005: AI Text Cleanup

- [ ] Integrate local LLM for text processing
  - Scope: Add llama.cpp or MLX as dependency. Create `TextCleanupManager.swift`. Load small cleanup-focused model.
  - Acceptance: LLM loads and can process text
  - Verification: `swift build` succeeds; LLM responds to test prompt

- [ ] Implement filler word removal
  - Scope: Create prompt template for removing fillers ("um", "uh", "like", "you know", etc.). Process transcribed text through LLM.
  - Acceptance: Filler words are removed from output
  - Verification: Input "um so like you know the thing", verify fillers removed

- [ ] Implement grammar and punctuation fix
  - Scope: Extend cleanup prompt to fix grammar, add proper punctuation and capitalization.
  - Acceptance: Output has correct grammar, punctuation, and capitalization
  - Verification: Input "hello how are you im fine", verify output "Hello, how are you? I'm fine."

- [ ] Add cleanup toggle option
  - Scope: Add setting to enable/disable text cleanup. When disabled, insert raw transcription.
  - Acceptance: User can toggle cleanup on/off; setting persists
  - Verification: Disable cleanup, transcribe, verify raw text is inserted

---

### US-006: Text Insertion

- [ ] Implement accessibility permission request
  - Scope: Check and request accessibility permissions. Guide user to System Preferences if needed.
  - Acceptance: App prompts for accessibility permission; provides guidance if denied
  - Verification: Reset accessibility permissions, launch app, verify permission guidance

- [ ] Implement pasteboard text insertion
  - Scope: Create `TextInserter.swift`. Copy text to pasteboard. Simulate Cmd+V keystroke using CGEvent.
  - Acceptance: Text is inserted into active text field
  - Verification: Focus a text field, trigger insertion, verify text appears

- [ ] Add clipboard preservation option
  - Scope: Save current clipboard contents before insertion. Optionally restore after insertion (with short delay).
  - Acceptance: Original clipboard contents can be preserved
  - Verification: Copy something, trigger insertion, verify original clipboard restored

- [ ] Handle insertion errors gracefully
  - Scope: Detect and handle cases where insertion fails (no text field focused, permission denied).
  - Acceptance: Errors show helpful feedback; app doesn't crash
  - Verification: Try to insert with no text field focused, verify helpful error message

---

### US-007: Settings Persistence

- [ ] Create settings data model
  - Scope: Create `Settings.swift` with properties: hotkey, selectedModel, launchAtLogin, cleanupEnabled, preserveClipboard.
  - Acceptance: Settings model compiles and holds all required properties
  - Verification: Instantiate Settings, verify all properties accessible

- [ ] Implement UserDefaults persistence
  - Scope: Add Codable conformance to Settings. Save/load from UserDefaults. Auto-save on changes.
  - Acceptance: Settings persist between app launches
  - Verification: Change setting, quit app, relaunch, verify setting persisted

- [ ] Create settings window UI
  - Scope: Create SwiftUI Settings view. Add sections: General (hotkey, launch at login), Transcription (model selection), Text (cleanup toggle, clipboard preservation).
  - Acceptance: User can view and modify all settings through UI
  - Verification: Open settings, change each setting, verify changes apply

- [ ] Add hotkey customization
  - Scope: Allow user to record custom hotkey combination. Validate hotkey doesn't conflict with system.
  - Acceptance: User can set custom hotkey; invalid hotkeys show warning
  - Verification: Set custom hotkey, verify it activates recording

---

## Notes

### Project Setup Decisions

- **Package Manager**: Recommend Swift Package Manager (Package.swift) over Xcode project for easier CI/CD and reproducibility. However, menu bar apps with NSStatusItem may benefit from traditional Xcode project structure.
- **Whisper Integration**: whisper.cpp has SPM support via [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp). Consider [argmaxinc/WhisperKit](https://github.com/argmaxinc/WhisperKit) as alternative (Apple-optimized).
- **LLM Integration**: llama.cpp has SPM support. Consider smaller models like TinyLlama or Phi-2 for cleanup tasks to minimize resource usage.

### Risks

1. **Accessibility Permissions**: CGEvent tap requires accessibility permissions which users may be reluctant to grant. Provide clear explanation of why it's needed.
2. **Model Size**: Whisper small/medium models are 500MB-1.5GB. Need good download UX and storage management.
3. **Performance**: Running both Whisper and LLM locally may strain older Macs. Consider model size recommendations based on hardware.
4. **Sandbox Limitations**: If distributing via App Store, some features (global hotkey, accessibility) may require entitlements or be restricted.

### Dependencies to Evaluate

- whisper.cpp or WhisperKit for transcription
- llama.cpp or MLX for text cleanup
- KeyboardShortcuts Swift package for hotkey handling (optional)

### Missing from PRD (potential additions)

- Error logging/reporting for debugging
- Onboarding flow for first-time users
- ~~Audio input device selection (if multiple mics)~~ - Implemented in US-003
- Keyboard shortcut conflicts handling
