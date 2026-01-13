# WispFlow v0.4 - Fix Audio Buffer Disconnect & Model Downloads

## Overview

Critical bugs remain in WispFlow preventing core functionality:
1. Audio level meter shows input, but buffer reports silence - fundamental disconnect in audio pipeline
2. Whisper and LLM models fail to download

## Problem 1: Audio Buffer Disconnect

### Current Behavior
- User speaks into microphone
- Audio level meter in UI shows green bars (activity detected)
- Recording stops
- App reports "No audio detected" / silence
- Transcription never occurs

### Root Cause Hypothesis
The level meter and the audio buffer are likely using DIFFERENT audio sources:
- Level meter may be reading from the audio tap callback directly (real-time)
- Audio buffer may be using a separate/broken accumulation path
- Buffer may be cleared/reset incorrectly
- Buffer may never receive the converted samples

### Investigation Required
1. Trace EXACT code path for level meter data source
2. Trace EXACT code path for transcription buffer data source
3. Find where they diverge
4. Ensure both use identical data

## Problem 2: Model Downloads Failing

### Current Behavior
- User selects Whisper model in settings
- Download button clicked
- Nothing happens / download fails silently
- Model status remains "Not Downloaded"

### Root Cause Hypothesis
- Network request may be failing silently
- Download URL may be incorrect or changed
- Progress callback may not be wired up
- File may download but not be saved correctly
- WhisperKit model download API may have changed

## Core Fixes

### 1. Unify Audio Data Path
- **Single source of truth** - One buffer that feeds BOTH level meter AND transcription
- **Remove any separate buffers** - Eliminate duplicate audio storage
- **Direct tap-to-buffer** - Audio tap callback writes directly to transcription buffer
- **Level meter reads from same buffer** - Calculate levels from transcription buffer

### 2. Debug Audio Pipeline Thoroughly
- **Log every audio callback** - Confirm tap is being called
- **Log buffer writes** - Confirm samples are being appended
- **Log buffer reads** - Confirm samples exist when reading
- **Compare counts** - Level meter sample count vs buffer sample count

### 3. Fix Model Downloads
- **Add explicit error handling** - Catch and display download errors
- **Add progress UI** - Show download progress percentage
- **Verify URLs** - Log actual download URLs being used
- **Test network** - Confirm app can reach Hugging Face
- **File verification** - Confirm model files exist after download

### 4. Fallback Audio Capture
- **Alternative capture method** - Try AVAudioRecorder as backup
- **Save to file** - Option to save audio to WAV for debugging
- **Play back** - Allow user to play recorded audio to verify capture

## Technical Implementation

### Audio Pipeline Fix
```swift
class AudioManager {
    // SINGLE buffer - used by both level meter and transcription
    private var masterBuffer: [Float] = []
    
    // Audio tap callback - ONLY place samples are captured
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let samples = convertToFloat32(buffer)
        
        // Append to master buffer
        masterBuffer.append(contentsOf: samples)
        
        // Calculate level from same samples (not separate source)
        let level = calculateLevel(samples)
        DispatchQueue.main.async {
            self.currentAudioLevel = level
        }
        
        // Log for debugging
        print("[AUDIO TAP] Received \(samples.count) samples, buffer now has \(masterBuffer.count)")
    }
    
    // Get buffer for transcription - returns the SAME buffer
    func getAudioBuffer() -> [Float] {
        print("[AUDIO] Returning buffer with \(masterBuffer.count) samples")
        return masterBuffer
    }
}
```

### Model Download Fix
```swift
func downloadModel(_ modelName: String) async throws {
    print("[MODEL] Starting download: \(modelName)")
    
    do {
        // Show progress
        await MainActor.run { downloadProgress = 0.0 }
        
        let pipe = try await WhisperKit(model: modelName) { progress in
            print("[MODEL] Download progress: \(progress * 100)%")
            Task { @MainActor in
                self.downloadProgress = progress
            }
        }
        
        print("[MODEL] Download complete!")
        await MainActor.run { 
            self.whisperPipe = pipe
            self.status = .ready
        }
    } catch {
        print("[MODEL] Download FAILED: \(error)")
        throw error
    }
}
```

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.

---

## MVP Scope (v0.4)

### [x] US-301: Unify Audio Buffer Architecture
As a user, I want the audio that shows in the level meter to be the same audio that gets transcribed.
- [x] Remove any duplicate/separate audio buffers in AudioManager
- [x] Create single masterBuffer that is the ONLY audio storage
- [x] Audio tap callback appends to masterBuffer
- [x] Level meter calculates from samples just added to masterBuffer
- [x] getAudioBuffer() returns masterBuffer directly
- [x] Log sample counts at every stage to verify data flow

### [ ] US-302: Audio Tap Verification
As a developer, I want to verify the audio tap is actually being called with real data.
- Add counter for number of tap callbacks received
- Log first callback with full details (format, sample count)
- Log every 10th callback with sample count
- Log if callback receives empty/zero data
- Alert if no callbacks received within 2 seconds of starting

### [ ] US-303: Buffer Integrity Logging
As a developer, I want to trace exactly where audio data goes.
- Log when masterBuffer is created/cleared
- Log every append with sample count and running total
- Log when buffer is read for transcription
- Log if buffer is empty when read
- Compare final buffer count to expected count (duration * 16000)

### [ ] US-304: Fix Whisper Model Downloads
As a user, I want Whisper models to download successfully.
- Add try/catch around WhisperKit initialization with error logging
- Show download progress bar in settings UI
- Log actual download URL being used
- Verify model directory exists after download
- Show clear error message if download fails
- Add retry button for failed downloads

### [ ] US-305: Fix LLM Model Downloads
As a user, I want LLM models to download successfully.
- Add try/catch around llama.cpp model download with error logging
- Show download progress percentage
- Log download URL and file size
- Verify model file exists after download
- Show clear error message if download fails
- Add manual model path option as fallback

### [ ] US-306: Audio Debug Export
As a user, I want to export my recorded audio to verify capture is working.
- Add "Export Last Recording" button in debug settings
- Save masterBuffer to WAV file in Documents folder
- Show file path after export
- Allow playback of exported file
- Log export success/failure

## Success Criteria

1. Level meter activity = buffer has samples (not disconnect)
2. Log shows tap callbacks being received with data
3. Log shows buffer growing during recording
4. Whisper model downloads with visible progress
5. LLM model downloads with visible progress
6. Exported WAV file contains audible speech

## Acceptance Criteria

1. Record 3 seconds -> log shows ~48000 samples in buffer
2. Log shows tap callback count > 0 after recording
3. Buffer sample count matches level meter sample count
4. Click download Whisper model -> progress bar moves -> model ready
5. Click download LLM model -> progress shows -> model ready
6. Export recording -> WAV file plays back speech correctly
