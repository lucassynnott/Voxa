# WispFlow - Voice to Text Mac App

## Overview

WispFlow is a native macOS application that provides system-wide voice-to-text dictation with AI-powered transcription and auto-editing. It works in any application, turning natural speech into polished, formatted text.

## Problem Statement

Typing is slow (~45 WPM) compared to speaking (~150+ WPM). Existing voice dictation tools produce raw, unedited transcriptions full of filler words, poor punctuation, and formatting issues. Users need a tool that captures speech and intelligently transforms it into clean, professional text.

## Core Features

### 1. System-Wide Voice Dictation
- **Global hotkey activation** - Press a key combo (e.g., Cmd+Shift+Space) to start/stop recording from any app
- **Menu bar app** - Minimal UI, lives in the system tray
- **Works in any text field** - Slack, email, VS Code, browsers, Notes, etc.
- **Real-time audio capture** - Uses macOS microphone APIs

### 2. AI-Powered Transcription (Local)
- **Speech-to-text engine** - Local Whisper model (whisper.cpp or MLX Whisper)
- **Fully offline** - No cloud API calls, all processing on-device
- **High accuracy** - Support for natural speech patterns, pauses, corrections
- **Low latency** - Transcribe and insert text quickly after speaking
- **Model options** - Support tiny/base/small/medium models for speed vs accuracy tradeoff

### 3. Auto-Editing & Cleanup
- **Remove filler words** - "um", "uh", "like", "you know"
- **Fix grammar and punctuation** - Proper capitalization, periods, commas
- **Format naturally** - Convert rambling speech into clear sentences
- **Preserve intent** - Keep the user's meaning while cleaning up delivery

### 4. Personal Dictionary
- **Custom vocabulary** - Names, technical terms, company-specific words
- **Auto-learn** - Detect and remember frequently used unique words
- **Corrections** - Allow user to correct misheard words and learn from them

### 5. Snippet Library
- **Voice shortcuts** - Say "my calendar" and insert a full booking link
- **Templates** - Common responses, signatures, boilerplate text
- **Quick triggers** - Short phrases that expand to longer content

### 6. App-Aware Tone Adjustment
- **Context detection** - Know which app is active (Slack vs Email vs Code)
- **Tone matching** - Casual for chat, professional for email, technical for code comments
- **Configurable per-app** - User can customize tone rules

### 7. Multi-Language Support
- **Language detection** - Auto-detect spoken language
- **Multiple languages** - Support major languages (English, Spanish, French, German, etc.)
- **Seamless switching** - Handle mid-sentence language changes

## Technical Requirements

### Platform
- macOS 13.0+ (Ventura or later)
- Native Swift/SwiftUI application
- Apple Silicon and Intel support

### Architecture
- **Menu bar app** - NSStatusItem for system tray presence
- **Global hotkey** - CGEvent tap or NSEvent.addGlobalMonitorForEvents
- **Audio capture** - AVAudioEngine for microphone input
- **Text insertion** - Accessibility APIs or CGEventCreateKeyboardEvent
- **AI integration** - Local Whisper (whisper.cpp/MLX) for transcription, local LLM (llama.cpp/MLX) for text cleanup

### Permissions Required
- Microphone access
- Accessibility permissions (for text insertion)
- Optional: Screen recording (for app context detection)

### Data & Privacy
- **100% Local** - All audio and text processing happens on-device
- **No cloud calls** - Zero network requests for AI processing
- **No storage** - Audio deleted immediately after transcription
- **User data** - Dictionary and snippets stored locally

## User Interface

### Menu Bar
- Microphone icon (idle/recording states)
- Click to toggle recording
- Right-click for settings menu

### Settings Window
- **General** - Hotkey configuration, launch at login
- **Audio** - Input device selection (microphone picker)
- **Transcription** - Model selection, language preferences
- **Dictionary** - Manage custom words
- **Snippets** - Create/edit voice shortcuts
- **Apps** - Per-app tone settings

### Recording Indicator
- Floating pill/badge showing recording status
- Waveform visualization (optional)
- Cancel button

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.

---

## MVP Scope (v0.1)

### [x] US-001: Menu Bar App Foundation
As a user, I want the app to run as a menu bar application so I can access it without cluttering my dock.
- [x] App lives in the macOS system tray (NSStatusItem)
- [x] Microphone icon shows idle/recording states
- [x] Click to toggle recording
- [x] Right-click for settings menu
- [x] Launch at login option

### [x] US-002: Global Hotkey Recording
As a user, I want to press a global hotkey to start/stop recording so I can dictate from any application.
- [x] Global hotkey activation (default: Cmd+Shift+Space)
- [x] Hotkey works in any app (CGEvent tap or NSEvent.addGlobalMonitorForEvents)
- [x] Visual indicator when recording (floating pill/badge)
- [x] Cancel button on recording indicator

### [x] US-003: Audio Capture
As a user, I want the app to capture my microphone audio so it can transcribe my speech.
- [x] Use AVAudioEngine for microphone input
- [x] Real-time audio capture
- [x] Request microphone permissions gracefully
- [x] Audio buffering for transcription
- [x] **Audio input device selection** - Allow user to choose which microphone/input device to use
- [x] List available audio input devices in settings
- [x] Remember selected device between sessions

### [ ] US-004: Local Whisper Transcription
As a user, I want my speech transcribed locally using Whisper so my audio never leaves my device.
- Integrate whisper.cpp or MLX Whisper
- Support for multiple model sizes (tiny/base/small/medium)
- Model download and management UI
- High accuracy transcription
- Low latency processing

### [ ] US-005: AI Text Cleanup
As a user, I want my transcribed text cleaned up automatically so I get polished, professional output.
- Remove filler words ("um", "uh", "like", "you know")
- Fix grammar and punctuation
- Proper capitalization
- Format naturally while preserving intent
- Use local LLM (llama.cpp/MLX) for cleanup

### [ ] US-006: Text Insertion
As a user, I want the cleaned text inserted into my active application so I can dictate directly into any text field.
- Insert text via pasteboard (Cmd+V simulation)
- Works in any text field (Slack, email, VS Code, browsers, Notes)
- Request accessibility permissions
- Preserve clipboard contents (optional restore)

### [ ] US-007: Settings Persistence
As a user, I want my settings to persist between sessions so I don't have to reconfigure the app.
- Save/load hotkey configuration
- Save/load model selection
- Save/load launch at login preference
- Use UserDefaults or similar storage

## Future Enhancements (v0.2+)

- Personal dictionary with auto-learning
- Snippet library
- App-aware tone adjustment
- Real-time transcription (streaming)
- iPhone companion app with sync
- Usage analytics and history
- Multiple model size options (tiny/base/small/medium)

## Success Metrics

- Transcription accuracy > 95%
- End-to-end latency < 2 seconds for short utterances
- Text cleanup quality (measured by edit distance reduction)
- User retention and daily active usage

## Acceptance Criteria

1. User can activate recording with a global hotkey from any app
2. Speech is transcribed accurately using Whisper
3. Transcribed text is cleaned up (fillers removed, punctuation added)
4. Cleaned text is inserted into the active text field
5. App runs as a menu bar application
6. Settings persist between sessions
