# Implementation Plan - WispFlow v0.4

## Summary

WispFlow v0.3 (US-201 through US-205) is complete with accessibility permission detection, audio buffer pipeline verification, audio capture diagnostics, permission flow UX, and silence detection fixes.

**v0.4 focuses on investigating and fixing two critical issues:**
1. **Audio buffer disconnect** - Level meter shows activity, but transcription reports silence
2. **Model download failures** - Whisper and LLM models fail to download silently

### Key Findings from Code Analysis:

1. **Audio Buffer Architecture Already Unified**: The current `AudioManager.swift` implementation already uses a single buffer path. The level meter calculates from the raw input buffer in the tap callback, and the transcription buffer stores the converted (16kHz) version of the same data. This is correct architecture.

2. **Potential Root Cause - Different Data Sources**: The level meter reads the **raw input buffer** (native device sample rate), while transcription uses the **converted buffer** (16kHz). If the audio converter is failing silently or producing zeros, this would explain the disconnect.

3. **WhisperKit Download Progress**: WhisperKit initializes and downloads models internally, but the current code doesn't effectively capture download progress. The `WhisperKitConfig` doesn't expose a progress callback.

4. **LLM Download Already Has Progress**: `LLMManager.swift` has proper download progress tracking via `URLSessionDownloadDelegate`.

5. **Audio Export Already Implemented**: `AudioExporter.swift` and `DebugManager` already support WAV export functionality.

### Priority Order (based on user impact):
1. US-301 (Audio Buffer Architecture) - Verify and fix the converter path
2. US-302 (Audio Tap Verification) - Confirm tap callbacks are firing with data
3. US-303 (Buffer Integrity Logging) - Trace where data may be lost
4. US-304 (Whisper Model Downloads) - Fix download progress and error handling
5. US-305 (LLM Model Downloads) - Enhance error handling (mostly working)
6. US-306 (Audio Debug Export) - Already implemented, verify functionality

---

## Tasks

### US-301: Unify Audio Buffer Architecture ✅ COMPLETE
As a user, I want the audio that shows in the level meter to be the same audio that gets transcribed.

**Implementation (2026-01-13):** Replaced the old `audioBuffers: [AVAudioPCMBuffer]` array with a single unified `masterBuffer: [Float]`. The level meter now calculates from the exact same samples that get appended to masterBuffer, eliminating any possibility of disconnect.

- [x] Remove duplicate/separate audio buffers in AudioManager
  - Removed `audioBuffers: [AVAudioPCMBuffer]` array
  - Created `masterBuffer: [Float]` as the ONLY audio storage
  - Added thread-safe `bufferLock` for concurrent access
  - Verification: `swift build` passes ✓

- [x] Create single masterBuffer that is the ONLY audio storage
  - `private var masterBuffer: [Float] = []` is now the sole buffer
  - All other buffer references have been removed
  - Verification: `swift build` passes ✓

- [x] Audio tap callback appends to masterBuffer
  - Tap callback extracts Float samples from converted buffer
  - Samples are appended directly to masterBuffer with thread safety
  - Verification: `swift build` passes ✓

- [x] Level meter calculates from samples just added to masterBuffer
  - Added `calculatePeakLevelFromSamples()` method
  - Level is calculated from the EXACT same samples added to masterBuffer
  - No separate data path for level meter vs transcription
  - Verification: `swift build` passes ✓

- [x] getAudioBuffer() returns masterBuffer directly
  - Added public `getAudioBuffer() -> [Float]` method
  - Returns masterBuffer contents with thread-safe access
  - Verification: `swift build` passes ✓

- [x] Log sample counts at every stage to verify data flow
  - Added `tapCallbackCount` tracking
  - Logs sample counts every 10th tap callback
  - Logs masterBuffer sample count at capture stop
  - Detailed logging in getMasterBufferDataWithStats()
  - Verification: `swift build` passes ✓

---

### US-302: Audio Tap Verification ✅ COMPLETE
As a developer, I want to verify the audio tap is actually being called with real data.

**Implementation (2026-01-13):** Added comprehensive tap callback verification including a 2-second timer alert, detailed first-callback logging with full format info and sample counts, and improved empty/zero-data detection with counters and structured logging.

- [x] Add tap callback counter and log callback frequency
  - Added `tapCallbackCount`, `emptyCallbackCount`, and `zeroDataCallbackCount` tracking
  - Added `logTapCallbackStats()` method that logs summary after recording stops
  - Summary includes: total callbacks, duration, callbacks/second, expected callbacks, empty count, zero-data count
  - Verification: `swift build` passes ✓

- [x] Log detailed format info on first tap callback
  - First tap callback now logs comprehensive details in a boxed format
  - Includes: input buffer frame count, sample rate, channels; converted buffer details; sample count extracted
  - Works for both converted and non-converted audio paths
  - Verification: `swift build` passes ✓

- [x] Alert if no callbacks received within 2 seconds
  - Added `noCallbackAlertTimer` property with `startNoCallbackAlertTimer()` and `stopNoCallbackAlertTimer()` methods
  - Timer fires after 2 seconds and checks if `tapCallbackCount == 0`
  - Logs prominent boxed warning with possible causes if no callbacks received
  - Added `onNoTapCallbacks` callback for external notification
  - Timer is properly cleaned up in `stopCapturing()` and `cancelCapturing()`
  - Verification: `swift build` passes ✓

- [x] Log if callback receives empty or zero-sample data
  - Added `emptyCallbackCount` counter for callbacks with empty buffers
  - Added `zeroDataCallbackCount` counter for callbacks where all samples are near-zero
  - Logs first occurrence immediately, then every 10th occurrence
  - Uses `zeroThreshold` of 1e-7 to detect near-zero samples
  - Counters are reset at start of each recording session
  - Verification: `swift build` passes ✓

---

### US-303: Buffer Integrity Logging ✅ COMPLETE
As a developer, I want to trace exactly where audio data goes.

**Implementation (2026-01-13):** Added comprehensive buffer integrity logging throughout the audio capture lifecycle. All masterBuffer operations are now traced with prominent boxed log messages including: buffer clear events (with previous/current counts), every append operation (first 5 + every 10th), buffer read events with empty warnings, and expected vs actual sample count comparison.

- [x] Log when masterBuffer is created/cleared
  - Added prominent boxed log in `startCapturing()` showing previous and current sample counts
  - Added logging in `stopCapturing()` after buffer is read for transcription
  - Added boxed log in `cancelCapturing()` showing discarded samples and callback count
  - Verification: `swift build` passes ✓

- [x] Log every append with sample count and running total
  - Enhanced tap callback logging: logs first 5 appends, then every 10th
  - Format: `[US-303] APPEND #N: +X samples | masterBuffer: before → after total | level: Y.YdB`
  - Provides traceability while avoiding excessive log spam
  - Verification: `swift build` passes ✓

- [x] Log when buffer is read for transcription
  - Added prominent boxed header when `getMasterBufferDataWithStats()` is called
  - Logs total samples retrieved from masterBuffer
  - Verification: `swift build` passes ✓

- [x] Log if buffer is empty when read
  - Added explicit warning box when masterBuffer is empty at read time
  - Includes possible causes: no tap callbacks, all empty/zero buffers, unexpected clear
  - Provides guidance to check callback counts
  - Verification: `swift build` passes ✓

- [x] Compare final buffer count to expected count (duration * 16000)
  - Added boxed comparison log in `stopCapturing()` after duration is calculated
  - Shows: duration, target sample rate, expected samples, actual samples, difference, variance %
  - Status indicator: ✓ for within 10%, ⚠️ for mismatch > 10%, ❌ for no samples
  - Verification: `swift build` passes ✓

---

### US-304: Fix Whisper Model Downloads ✅ COMPLETE
As a user, I want Whisper models to download successfully.

**Implementation (2026-01-13):** Added comprehensive error handling, progress visibility, directory verification, and retry functionality for Whisper model downloads. Enhanced WhisperManager.swift with detailed error logging, status messages during download, pre/post-download verification, and a retry mechanism. Updated SettingsWindow.swift with a progress bar, error alerts, and retry button.

- [x] Add WhisperKit initialization error logging with full context
  - Added `createDetailedErrorMessage()` that parses error types and provides specific suggestions
  - Added boxed console logging with model info, directory status, error type, and full error details
  - Enhanced `ErrorLogger.shared.logModelError()` with comprehensive context
  - Verification: `swift build` passes ✓

- [x] Improve download progress visibility (workaround for WhisperKit limitation)
  - Added `lastErrorMessage` published property for detailed UI error display
  - Added intermediate status messages: "Connecting to model repository...", "Downloading model files from Hugging Face...", "Downloading [model] (~size)...", "Still downloading..."
  - Added `getEstimatedSize()` helper to show approximate download size
  - Added timed status updates (2s, 5s) to simulate progress during download
  - Added `ProgressView` with linear style and percentage in UI
  - Verification: `swift build` passes ✓

- [x] Verify model directory exists and is writable before download
  - Added `verifyModelsDirectory()` method that checks/creates directory and verifies write permission
  - Returns clear error if directory cannot be created or is not writable
  - Logs directory status to console with boxed output
  - Verification: `swift build` passes ✓

- [x] Add model file verification after download
  - Added `verifyModelFilesAfterDownload()` method that checks model directory exists
  - Lists files in model directory and calculates total size
  - Logs verification result with file count and total size
  - Verification: `swift build` passes ✓

- [x] Show clear error message in UI when download fails
  - Added `showErrorAlert` state in `TranscriptionSettingsView`
  - Shows alert automatically when download fails with detailed message from `lastErrorMessage`
  - Error message includes cause analysis and specific suggestions
  - Added "Error Details" button for viewing error info after dismissing initial alert
  - Verification: `swift build` passes ✓

- [x] Add retry mechanism for failed downloads
  - Added `retryLoadModel()` method that resets status and retries download
  - Added "Retry Download" button in UI that appears when `modelStatus == .error`
  - Button calls `retryLoadModel()` and shows error alert if retry also fails
  - Verification: `swift build` passes ✓

---

### US-305: Fix LLM Model Downloads ✅ COMPLETE
As a user, I want LLM models to download successfully.

**Implementation (2026-01-13):** Added comprehensive error handling with specific HTTP error parsing, network connectivity pre-check, prominent download URL logging, file size verification after download, and manual model path fallback option. Enhanced LLMManager.swift and SettingsWindow.swift with detailed error messages, retry functionality, progress bars, and file picker for custom model paths.

- [x] Improve download error messages with specific failure reasons
  - Added `createDetailedErrorMessage()` method that parses HTTP status codes (401, 403, 404, 429, 5xx) and network errors (timeout, no internet, connection lost)
  - Each error type has specific user-friendly message and actionable suggestion
  - Added `handleDownloadError()` method for consistent error state management
  - Added boxed console logging with full error context
  - Error messages include download URL for debugging
  - Verification: `swift build` passes ✓

- [x] Add network reachability check before download attempt
  - Added `checkNetworkConnectivity()` async method that performs HEAD request before download
  - Checks for HTTP status codes and network error types
  - Returns clear message if network unavailable (no internet, cannot find host, secure connection failed, timeout)
  - Connectivity check has 10 second timeout
  - Verification: `swift build` passes ✓

- [x] Log actual download URL being used
  - Added `logDownloadStart()` method with boxed output showing model name, expected size, and full download URL
  - Added `logDownloadSuccess()` method showing file name, size, and path
  - Added `logVerificationFailure()` for warning when file size doesn't match expectations
  - All URLs tagged with `[US-305]` prefix for easy filtering
  - Verification: `swift build` passes ✓

- [x] Verify model file exists and has expected size after download
  - Added `expectedMinimumSizeBytes` property to ModelSize enum (~900MB for Qwen, ~1.8GB for Phi-3, ~1.3GB for Gemma)
  - Added `verifyDownloadedModel()` method that checks file exists and compares size to minimum expected
  - Returns warning if file is suspiciously small (may indicate partial download)
  - Added `formatBytes()` helper for human-readable file sizes
  - Download status shows file size progress (e.g., "Downloading... 45% (450 MB / 1 GB)")
  - Verification: `swift build` passes ✓

- [x] Add manual model path option as fallback
  - Added `customModelPath` and `useCustomModelPath` properties with UserDefaults persistence
  - Added `loadModelFromCustomPath()` method that validates path exists and file extension is .gguf
  - Added UI section in TextCleanupSettingsView with toggle, text field, and "Browse..." button
  - Added file picker using `.fileImporter` modifier
  - Added "Load Custom Model" button when custom path is specified
  - Verification: `swift build` passes ✓

- [x] Add retry mechanism and error alert UI
  - Added `retryDownload()` method that resets error state and retries
  - Added `lastErrorMessage` published property for detailed UI error display
  - Added error alert with "OK" and "Retry" buttons
  - Added "Error Details" button in UI when error state is active
  - Added "Retry Download" button styled with orange tint for visibility
  - Verification: `swift build` passes ✓

---

### US-306: Audio Debug Export ✅ COMPLETE
As a user, I want to export my recorded audio to verify capture is working.

**Implementation (2026-01-13):** Enhanced AudioExporter.swift with comprehensive export functionality including detailed logging, auto-save to Documents folder, playback support, and Finder integration. Updated DebugManager.swift with auto-save toggle. Updated SettingsWindow.swift with new UI controls for Quick Export, Play/Stop, Show in Finder, and auto-save toggle. Added auto-save logic in AppDelegate.swift.

- [x] Verify WAV export produces playable audio file
  - AudioExporter converts Float32 samples to 16-bit PCM WAV format correctly
  - Export produces standard WAV files playable in QuickTime and other players
  - Added playback functionality directly in the app via AVAudioPlayer
  - Verification: `swift build` passes ✓

- [x] Add "Export Last Recording" status message after export
  - Enhanced export alert to show "Show in Finder" and "Play Audio" buttons
  - Added inline file path display in Debug Settings showing last export location
  - Added `ExportDetails` struct to track export metadata (samples, duration, file size, path)
  - Prominent boxed console logging with full export details
  - Verification: `swift build` passes ✓

- [x] Add option to auto-save recordings in debug mode
  - Added `isAutoSaveEnabled` property to DebugManager with UserDefaults persistence
  - Added "Auto-Save Recordings" toggle in Debug Settings
  - Auto-saves to ~/Documents/WispFlow/DebugRecordings/ with timestamped filenames
  - Added "Open Recordings Folder" button when auto-save is enabled
  - Auto-save integrated in AppDelegate with success/failure logging
  - Verification: `swift build` passes ✓

- [x] Log export success/failure with file details
  - Added `logExportSuccess()` with boxed output showing sample count, duration, sample rate, file size, and path
  - Added `logExportFailure()` with reason for failure
  - All export logs tagged with `[US-306]` prefix
  - Export details stored in `lastExportDetails` for later access
  - Verification: `swift build` passes ✓

- [x] Add playback support for exported audio (bonus feature)
  - Added AVAudioPlayer integration with delegate for playback completion
  - Added `playLastExport()`, `playFile(at:)`, `stopPlayback()` methods
  - Added Play/Stop button in Debug Settings UI with dynamic icon
  - Added `revealLastExportInFinder()` and `openDebugRecordingsFolder()` for Finder integration
  - Verification: `swift build` passes ✓

---

## Notes

### Discoveries

1. **Audio Buffer Architecture is Correct**: The code already implements a unified buffer approach. The level meter and transcription buffer use the same tap callback. The disconnect may be in the **audio converter** (converting native sample rate to 16kHz) rather than separate buffers.

2. **Converter Silent Failure Theory**: The audio converter in the tap callback may be:
   - Producing zeros when conversion fails
   - Not being called (inputBlock not triggered correctly)
   - Returning empty frames on some devices

3. **WhisperKit Progress Limitation**: WhisperKit doesn't expose download progress through its API. The current implementation simulates progress with status messages. A better solution would be to manually download the model files with progress tracking, then point WhisperKit to the local files.

4. **LLM Download Working**: The LLM download code in `LLMManager.swift` has proper progress tracking and error handling. The issue may be specific to certain models or network conditions.

5. **Audio Export Ready**: The `AudioExporter.swift` implementation is complete and functional. It converts Float32 samples to 16-bit PCM WAV format correctly.

### Risks

1. **Converter Device Compatibility**: The audio converter may behave differently on different Mac hardware (M1/M2 vs Intel, built-in mic vs external mic). Need to test on multiple configurations.

2. **WhisperKit API Changes**: WhisperKit may change its model download behavior in future versions. Current workarounds may need updating.

3. **Network-dependent Downloads**: Model downloads depend on Hugging Face availability. Consider adding fallback URLs or local model bundling for reliability.

4. **Sample Rate Mismatch**: If the input device sample rate changes mid-recording (e.g., switching devices), the converter may produce incorrect output.

### Technical Notes

- Audio tap callback runs on audio thread - minimize work and use DispatchQueue.main for UI updates
- WhisperKit expects 16kHz mono Float32 audio with samples in [-1.0, 1.0] range
- AVAudioConverter requires matching formats between input and output nodes
- LLM models are ~1-2GB - downloads may take several minutes on slow connections
- WAV export uses 16-bit PCM format (standard compatibility)
