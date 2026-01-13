# WispFlow v0.2 - Fix Transcription & Improve Local AI

## Overview

This PRD addresses critical transcription issues in WispFlow v0.1 and improves the local AI pipeline for reliable voice-to-text.

## Problem Statement

The current implementation has a critical bug: transcription returns "[BLANK_AUDIO]" instead of actual text. This indicates issues with:
1. Audio format/sample rate mismatch with Whisper requirements
2. Audio buffer not being properly passed to the transcription engine
3. Potential microphone permission or capture issues
4. WhisperKit model not properly loaded or configured

## Root Cause Analysis Required

### Audio Pipeline Issues
- Verify audio is being captured at correct sample rate (16kHz required for Whisper)
- Check audio buffer format (Float32 mono PCM)
- Ensure audio data is not empty or silent
- Validate audio levels/gain

### WhisperKit Integration Issues
- Model may not be downloaded/loaded before transcription
- Audio format conversion may be incorrect
- Transcription options may need tuning (language, task settings)

## Core Features

### 1. Fix Audio Capture Pipeline
- **Debug audio levels** - Add audio level meter to verify mic is capturing
- **Validate sample rate** - Ensure 16kHz conversion is working
- **Audio format verification** - Log audio buffer details before transcription
- **Minimum audio duration** - Require at least 0.5s of audio before transcribing
- **Silence detection** - Detect and warn if audio is silent/too quiet

### 2. Fix WhisperKit Integration
- **Model loading state** - Block transcription until model is fully loaded
- **Audio preprocessing** - Ensure proper Float32 array format for WhisperKit
- **Error handling** - Surface actual WhisperKit errors to user
- **Transcription options** - Configure language detection, decode options properly
- **Fallback behavior** - Show meaningful error instead of BLANK_AUDIO

### 3. Audio Level Indicator
- **Real-time level meter** - Show mic input level in recording indicator
- **Visual feedback** - User can verify mic is picking up sound
- **Gain warning** - Alert if input is too quiet

### 4. Improved Model Management
- **Download progress** - Show actual download progress percentage
- **Model validation** - Verify model files after download
- **Auto-load on launch** - Load last-used model automatically at startup
- **Model status in menu bar** - Show if model is ready/loading/error

### 5. Local LLM for Text Cleanup (llama.cpp)
- **Integrate llama.cpp** - Use MLX or llama.cpp for local text cleanup
- **Small model** - Use a small model (Phi-3, Gemma 2B, or similar)
- **Cleanup prompt** - Proper system prompt for grammar/filler removal
- **Fallback to rules** - Use rule-based cleanup if LLM unavailable

### 6. Debug/Diagnostic Mode
- **Audio debug view** - Show waveform of captured audio
- **Transcription logs** - Display raw Whisper output before cleanup
- **Export audio** - Option to save recorded audio for debugging
- **Console logging** - Detailed logs for troubleshooting

## Technical Requirements

### Audio Pipeline Fix
```
Required format for WhisperKit:
- Sample rate: 16000 Hz
- Channels: 1 (mono)
- Format: Float32 array normalized to [-1.0, 1.0]
- Minimum duration: 0.5 seconds
```

### WhisperKit Configuration
```swift
// Proper transcription setup
let options = DecodingOptions(
    language: "en",  // or nil for auto-detect
    task: .transcribe,
    temperatureFallbackCount: 3,
    sampleLength: 224,
    usePrefillPrompt: false,
    detectLanguage: true
)
```

### Dependencies
- WhisperKit (already integrated)
- MLX or llama.cpp Swift bindings (for LLM cleanup)
- Accelerate framework (for audio processing)

## MVP Scope (v0.2)

### [x] US-101: Debug Audio Capture
As a user, I want to verify my microphone is working so I can troubleshoot transcription issues.
- [x] Add real-time audio level meter to recording indicator
- [x] Log audio buffer statistics (sample count, duration, peak level)
- [x] Warn if audio appears silent (peak < -40dB)
- [x] Show audio duration after recording stops
- [x] Minimum 0.5s recording requirement

### [ ] US-102: Fix WhisperKit Audio Format
As a user, I want my audio properly converted for Whisper so transcription works correctly.
- Verify 16kHz sample rate conversion
- Ensure Float32 mono PCM format
- Normalize audio to [-1.0, 1.0] range
- Add audio preprocessing validation
- Log format details before transcription

### [ ] US-103: Improve Model Loading
As a user, I want the Whisper model to load reliably so I can transcribe immediately.
- Auto-load last-used model on app launch
- Show loading progress in menu bar
- Block recording until model ready
- Display clear error if model fails to load
- Add "Model Ready" indicator

### [ ] US-104: Better Error Handling
As a user, I want clear error messages instead of BLANK_AUDIO so I know what went wrong.
- Catch and display WhisperKit errors
- Show "No speech detected" for silent audio
- Show "Model not loaded" if model missing
- Add retry option for failed transcriptions
- Log errors to .ralph/errors.log for debugging

### [ ] US-105: Audio Debug Mode
As a developer, I want to debug audio capture so I can fix transcription issues.
- Add "Debug Mode" toggle in settings
- Show audio waveform visualization
- Display raw transcription before cleanup
- Option to export audio as WAV file
- Show detailed logs in a debug window

### [ ] US-106: Local LLM Text Cleanup
As a user, I want AI-powered text cleanup using a local model so my text is polished without cloud APIs.
- Integrate llama.cpp or MLX LLM
- Download small model (Phi-3-mini or similar)
- Create cleanup system prompt
- Process transcription through LLM
- Fallback to rule-based cleanup if LLM unavailable

## Success Criteria

1. Transcription produces actual text (not BLANK_AUDIO)
2. Audio level meter shows mic is capturing sound
3. Model loads automatically on app launch
4. Clear error messages for all failure modes
5. Debug mode allows audio export for troubleshooting
6. LLM cleanup improves text quality over rule-based

## Acceptance Criteria

1. Record 5 seconds of speech → get actual transcription
2. Audio level meter shows activity while speaking
3. App shows "Model Ready" after launch
4. Silent recording shows "No speech detected" error
5. Debug mode can export audio as WAV file
6. Text cleanup uses local LLM when available

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.
