# US-053: Memory Usage Audit

## Overview

This document provides a comprehensive audit of memory usage in the Voxa application, identifying potential issues and implemented optimizations.

## Memory Usage Summary

### Typical Session Memory Baseline

| Component | Memory Usage | Notes |
|-----------|-------------|-------|
| Audio buffers (2-min recording) | ~8 MB | Unified master buffer (US-301) |
| Whisper model (Tiny) | ~75 MB | Loaded into memory during inference |
| Whisper model (Base) | ~145 MB | |
| Whisper model (Small) | ~485 MB | |
| Whisper model (Medium) | ~1.5 GB | |
| Whisper model (Large) | ~3 GB | |
| LLM models | 1-2 GB | Qwen 1.5B, Phi-3 Mini, Gemma 2B |
| Clipboard history (50 entries) | ~30 KB | Configurable 10-200 entries |
| UI components + observers | ~10-20 MB | |

**Total typical session:** 100-3050 MB (dominated by model size)

## Implemented Optimizations (US-053)

### 1. Audio Data Conversion Optimization

**Location:** `WhisperManager.swift`

**Issue:** Audio data was being converted from `Data` to `[Float]` multiple times during transcription:
- Once for validation (`validateAudioData`)
- Once for diagnostics (`logAudioDiagnostics`)
- Once for transcription (`transcribe`)
- Once for error analysis (`getAudioStats`)

**Solution:** Consolidated to single conversion with methods that accept pre-converted samples:
- `validateAudioSamples(_:sampleRate:)` - validates pre-converted samples
- `logAudioDiagnosticsOptimized(samples:sampleRate:byteCount:)` - logs using pre-converted samples

**Impact:** Reduced memory allocations from 4x to 1x during transcription (~30 MB savings for 2-minute recording)

### 2. Memory Pressure Response

**Location:** `AppDelegate.swift`

**Implementation:** Added `DispatchSource.makeMemoryPressureSource` observer that responds to:
- **Warning level:** Trims clipboard history to 50% of max
- **Critical level:**
  - Clears retained audio data immediately
  - Trims clipboard history to 10 entries
  - Clears undo stack

**Impact:** Allows app to reduce memory footprint under system pressure

### 3. Combine Subscription Cleanup

**Location:** `StatusBarController.swift`

**Issue:** `modelStatusObserver` and `hotkeyModeObservers` were not cancelled in deinit, risking memory leaks if the controller was deallocated while subscriptions were active.

**Solution:** Added proper cleanup in deinit:
```swift
deinit {
    stopPulseAnimation()
    stopProcessingAnimation()
    modelStatusObserver?.cancel()
    modelStatusObserver = nil
    hotkeyModeObservers.forEach { $0.cancel() }
    hotkeyModeObservers.removeAll()
}
```

### 4. Toast Timer Cleanup

**Location:** `ToastView.swift`

**Issue:** ToastManager's `dismissTimers` dictionary wasn't explicitly cleared on deallocation.

**Solution:** Added deinit to ToastManager:
```swift
deinit {
    for timer in dismissTimers.values {
        timer.invalidate()
    }
    dismissTimers.removeAll()
}
```

### 5. Clipboard History Memory Pressure Support

**Location:** `ClipboardHistoryManager.swift`

**New method:** `trimToCount(_:)` allows external callers (like memory pressure handler) to trim history to a specific count.

## Existing Memory Management (Good Practices)

### Already Implemented Well

1. **Unified Audio Buffer (US-301):** Single `masterBuffer` prevents duplicate audio storage
2. **Audio Buffer Timeout (US-608):** 30-second auto-clear of retained audio data
3. **Proper deinit in key classes:** LLMManager, AudioManager, HotkeyManager, TextInserter, PermissionManager
4. **Weak references in callbacks:** Consistent `[weak self]` pattern in timers and closures
5. **UndoStack cleanup:** 24-hour auto-cleanup of old entries
6. **Clipboard history cleanup:** Retention period-based cleanup

## Remaining Considerations

### Model Hot-Swap Memory Spike

During model switching (US-008), both old and new models may be in memory simultaneously. This is by design to ensure uninterrupted transcription capability but can cause temporary memory spikes.

**Mitigation:** Users should be aware that switching to larger models may temporarily require more memory.

### LLM Context Memory

LLM inference can temporarily allocate additional memory for context windows and batch processing. This is managed by llama.cpp and cleaned up after inference.

## Testing Recommendations

1. Use Instruments' Allocations tool to profile memory during:
   - Long recording sessions
   - Model hot-swap operations
   - Multiple transcription cycles

2. Monitor for memory pressure warnings in Console.app

3. Verify cleanup by checking memory after:
   - Closing settings windows
   - Stopping recordings
   - Dismissing toasts

## Related User Stories

- US-301: Unified audio buffer
- US-608: Audio buffer timeout
- US-051: Startup time optimization (deferred model loading)
- US-052: Lazy-load models
