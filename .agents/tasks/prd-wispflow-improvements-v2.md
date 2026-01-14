# PRD: WispFlow Improvements & Bugfixes v2

## Overview

**Product**: WispFlow - Local Voice-to-Text Transcription for macOS  
**Version**: 2.0  
**Date**: 2026-01-14  
**Status**: Ready for Implementation

## Executive Summary

This PRD outlines improvements, optimizations, and bugfixes for WispFlow, a privacy-focused macOS menu bar application for on-device voice-to-text transcription using WhisperKit. The focus is on stability, user experience polish, and production readiness.

---

## Phase 1: Audio System Hardening

### [x] US-601: Audio Device Hot-Plug Support
**Priority**: High  
**Estimate**: 3 points

**Description**: Handle audio device connection/disconnection gracefully without crashing or requiring app restart.

**Acceptance Criteria**:
- [x] Detect when selected audio device is disconnected during recording
- [x] Automatically fall back to system default device
- [x] Show toast notification when device changes
- [x] Re-select preferred device when it's reconnected
- [x] No crashes when devices are plugged/unplugged

**Technical Notes**:
- Use `AudioObjectAddPropertyListener` for `kAudioHardwarePropertyDevices`
- Store device UID preference, not just runtime device reference

---

### [x] US-602: Audio Format Negotiation Improvement
**Priority**: High  
**Estimate**: 2 points

**Description**: Improve compatibility with various audio devices by better format negotiation.

**Acceptance Criteria**:
- [x] Query device's supported formats before attempting capture
- [x] Prefer standard formats (44.1kHz, 48kHz stereo/mono)
- [x] Log detailed format information for debugging
- [x] Graceful error message if no compatible format found

**Technical Notes**:
- Use `kAudioDevicePropertyStreamConfiguration` to query supported formats
- Try multiple format combinations before failing

---

### [x] US-603: Recording Timeout Safety
**Priority**: Medium  
**Estimate**: 1 point

**Description**: Prevent runaway recordings that could fill disk space.

**Acceptance Criteria**:
- [x] Maximum recording duration of 5 minutes (configurable)
- [x] Warning toast at 4 minutes
- [x] Auto-stop and transcribe at limit
- [x] Show elapsed time in recording indicator

---

### US-604: Audio Level Calibration
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Allow users to calibrate microphone sensitivity for their environment.

**Acceptance Criteria**:
- [ ] "Calibrate" button in Audio settings
- [ ] Measure ambient noise level over 3 seconds
- [ ] Adjust silence threshold based on calibration
- [ ] Save calibration per-device
- [ ] Reset to defaults option

---

## Phase 2: Transcription Quality

### US-605: Whisper Model Selection
**Priority**: High  
**Estimate**: 3 points

**Description**: Allow users to choose between different Whisper model sizes for speed vs accuracy tradeoff.

**Acceptance Criteria**:
- [ ] Settings option for model size (tiny, base, small, medium)
- [ ] Show estimated transcription speed and accuracy for each
- [ ] Download progress indicator for model switching
- [ ] Persist model preference across restarts

**Technical Notes**:
- tiny: ~39MB, fastest, lower accuracy
- base: ~74MB, balanced
- small: ~244MB, good accuracy
- medium: ~769MB, best accuracy

---

### US-606: Language Selection
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Allow users to specify transcription language for better accuracy.

**Acceptance Criteria**:
- [ ] Language dropdown in Settings (Auto-detect + common languages)
- [ ] Pass language hint to WhisperKit
- [ ] Remember language preference
- [ ] "Auto-detect" as default

---

### US-607: Transcription Post-Processing
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Clean up transcription output for better usability.

**Acceptance Criteria**:
- [ ] Option to auto-capitalize first letter
- [ ] Option to add period at end of sentences
- [ ] Option to trim leading/trailing whitespace
- [ ] Configurable in Settings

---

### US-608: Retry Failed Transcriptions
**Priority**: Low  
**Estimate**: 1 point

**Description**: Allow retrying transcription if it fails or produces poor results.

**Acceptance Criteria**:
- [ ] Keep last audio buffer after transcription
- [ ] "Retry" option in error toast
- [ ] Clear buffer after successful insertion or timeout (30s)

---

## Phase 3: Hotkey System Improvements

### US-609: Custom Hotkey Configuration
**Priority**: High  
**Estimate**: 3 points

**Description**: Allow users to configure their own hotkey combination.

**Acceptance Criteria**:
- [ ] Hotkey recorder in Settings
- [ ] Support modifier keys (Cmd, Ctrl, Option, Shift) + any key
- [ ] Conflict detection with system shortcuts
- [ ] Default: Ctrl+Shift+Space (or current default)
- [ ] Reset to default button

**Technical Notes**:
- Store as dictionary: `["keyCode": Int, "modifiers": Int]`
- Validate hotkey doesn't conflict with common shortcuts

---

### US-610: Multiple Hotkey Modes
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Support different recording trigger modes.

**Acceptance Criteria**:
- [ ] Push-to-talk (hold to record, release to transcribe) - current behavior
- [ ] Toggle mode (press to start, press again to stop)
- [ ] Double-tap mode (double-press to start, single press to stop)
- [ ] Setting to choose mode

---

### US-611: Hotkey Feedback Sound
**Priority**: Low  
**Estimate**: 1 point

**Description**: Optional audio feedback when hotkey is pressed.

**Acceptance Criteria**:
- [ ] Subtle sound on recording start
- [ ] Different sound on recording stop
- [ ] Toggle in Settings (default: off)
- [ ] Use system sounds or bundled sounds

---

## Phase 4: Text Insertion Improvements

### US-612: Smart Punctuation Handling
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Intelligently handle punctuation and spacing when inserting text.

**Acceptance Criteria**:
- [ ] Detect if cursor is after a period/space
- [ ] Auto-capitalize if starting new sentence
- [ ] Add space before insertion if needed
- [ ] Don't double-space

---

### US-613: Undo Support
**Priority**: High  
**Estimate**: 2 points

**Description**: Allow undoing last text insertion.

**Acceptance Criteria**:
- [ ] Cmd+Z after insertion removes inserted text
- [ ] Restore original clipboard contents
- [ ] Only works within 10 seconds of insertion
- [ ] Works across applications

**Technical Notes**:
- Store inserted text length and target app
- Use accessibility API to select and delete

---

### US-614: Text Insertion Fallback
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Provide fallback when clipboard-based insertion fails.

**Acceptance Criteria**:
- [ ] Detect if paste failed (text not inserted)
- [ ] Try keyboard simulation fallback
- [ ] Show copy-to-clipboard option if all methods fail
- [ ] Toast with "Text copied to clipboard" message

---

## Phase 5: Premium UI Redesign

> **Design Philosophy**: Apply the `frontend-design` skill to create a distinctive, production-grade interface that avoids generic "AI slop" aesthetics. Every design choice must be intentional, bold, and memorable.

### US-615: Design System Foundation
**Priority**: High  
**Estimate**: 5 points

**Description**: Establish a cohesive, distinctive design system for WispFlow that feels premium and memorable.

**Aesthetic Direction**: Voice/audio apps suggest organic waveforms, but WispFlow should feel **refined and professional** - think high-end audio equipment meets editorial design. Consider: moody dark theme with warm accent colors, or crisp light theme with bold typographic choices.

**Acceptance Criteria**:
- [ ] Define distinctive color palette (NOT purple gradients, NOT generic blue)
  - Primary: A bold, unexpected choice (deep coral, electric teal, warm amber, etc.)
  - Background: Either rich dark (#0D0D0D range) or warm off-white (cream/ivory)
  - Accent: High-contrast complementary color
  - Semantic colors for success/warning/error
- [ ] Select memorable typography
  - Display font: Something with personality (NOT Inter, Roboto, SF Pro)
  - Consider: Söhne, GT Walsheim, Neue Haas Grotesk, Untitled Sans, or something unexpected
  - Body font: Highly legible but refined
- [ ] Define spacing scale (4px base, consistent rhythm)
- [ ] Define corner radius philosophy (sharp/brutalist OR soft/organic - commit to one)
- [ ] Create SwiftUI color/font extensions for consistency
- [ ] Document design tokens in code comments

**Technical Notes**:
- Update `Color.Wispflow` and `Font.Wispflow` extensions
- All components must use design tokens, no hardcoded values

---

### US-616: Settings Window Redesign
**Priority**: High  
**Estimate**: 5 points

**Description**: Complete redesign of Settings window as a showcase of the new design system.

**Acceptance Criteria**:
- [ ] Bold window chrome - consider custom title bar or distinctive header
- [ ] Tab navigation reimagined - vertical sidebar, icon-forward, or segmented control
- [ ] Card-based sections with clear visual hierarchy
- [ ] Generous whitespace OR intentional density (commit to direction)
- [ ] Micro-interactions on hover/focus states
- [ ] Custom-styled form controls (toggles, dropdowns, sliders)
- [ ] Audio level meter as a visual centerpiece with animated waveform
- [ ] Smooth transitions between tabs
- [ ] Window remembers position and size

**Design Details**:
- Consider asymmetric layouts, not just centered stacks
- Use scale contrast - large section headers, refined body text
- Add subtle texture or gradient to background
- Custom scrollbar styling if visible

---

### US-617: Recording Indicator Redesign
**Priority**: High  
**Estimate**: 3 points

**Description**: Transform the recording indicator into a beautiful, functional piece of UI.

**Acceptance Criteria**:
- [ ] Distinctive floating window design (not a generic rounded rect)
- [ ] Real-time waveform visualization with smooth animation
- [ ] Recording duration timer with refined typography
- [ ] Pulsing/breathing animation that feels alive
- [ ] Draggable with smooth physics (momentum, snap-to-edges optional)
- [ ] Subtle shadow/glow that suggests depth
- [ ] Position persistence across sessions
- [ ] Optional: glassmorphism/blur effect

**Animation Notes**:
- Waveform should feel organic, not mechanical
- Entry/exit animations (scale + fade, or slide)
- Consider particle effects or ambient motion

---

### US-618: Toast Notification System Redesign
**Priority**: Medium  
**Estimate**: 3 points

**Description**: Redesign toast notifications to be distinctive and delightful.

**Acceptance Criteria**:
- [ ] Unique visual style matching design system
- [ ] Smooth spring animations for enter/exit
- [ ] Icon + message + optional action button
- [ ] Different styles for: success, error, warning, info
- [ ] Stacking behavior for multiple toasts
- [ ] Click to dismiss with satisfying animation
- [ ] Configurable position (all corners + center options)
- [ ] Auto-dismiss with subtle progress indicator

**Design Details**:
- Consider: pill shape, sharp rectangle, or custom clip-path
- Subtle backdrop blur or solid with shadow
- Typography should be scannable at a glance

---

### US-619: Onboarding Wizard Redesign
**Priority**: Medium  
**Estimate**: 4 points

**Description**: Make first-launch experience memorable and confidence-inspiring.

**Acceptance Criteria**:
- [ ] Full-window immersive experience
- [ ] Bold hero typography on welcome screen
- [ ] Step indicator with personality (not generic dots)
- [ ] Illustrations or iconography that feel custom (not stock)
- [ ] Smooth page transitions with staggered content reveals
- [ ] Permission request screens that feel trustworthy
- [ ] Audio test step with engaging visualization
- [ ] Celebratory completion screen
- [ ] Overall flow should take ~60 seconds

**Animation Notes**:
- Each step should have choreographed entrance
- Consider parallax or layered depth effects
- Completion could have confetti, checkmark animation, or subtle celebration

---

### US-620: Menu Bar Experience
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Polish the menu bar icon and dropdown menu.

**Acceptance Criteria**:
- [ ] Icon states: idle, recording (animated pulse), loading, error
- [ ] Recording state should be immediately obvious (color change or animation)
- [ ] Dropdown menu with custom styling if possible
- [ ] Status information clearly displayed
- [ ] Quick actions easily accessible

---

### US-621: Transcription Result Display
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Show transcription results in a beautiful, scannable way.

**Acceptance Criteria**:
- [ ] Elegant toast or floating panel showing transcribed text
- [ ] Text appears with typewriter or fade-in effect
- [ ] Clear indication of where text was inserted
- [ ] Copy button with satisfying feedback
- [ ] Error states feel helpful, not alarming
- [ ] Long text truncates gracefully with expand option

---

### US-622: Dark/Light Mode Support
**Priority**: Low  
**Estimate**: 2 points

**Description**: Support both appearances with equally strong design.

**Acceptance Criteria**:
- [ ] Both modes feel intentional, not auto-generated
- [ ] Respect system preference with manual override option
- [ ] Smooth transition when switching modes
- [ ] Both modes maintain design personality
- [ ] Test all components in both modes

---

### US-623: Motion & Animation Polish
**Priority**: Low  
**Estimate**: 2 points

**Description**: Add cohesive motion design throughout the app.

**Acceptance Criteria**:
- [ ] Define animation curves (spring physics preferred)
- [ ] Consistent timing across similar interactions
- [ ] Button press states with scale/opacity feedback
- [ ] List items animate in with stagger
- [ ] Loading states feel alive (skeleton, shimmer, or spinner)
- [ ] Reduce motion option for accessibility

---

## Phase 6: Error Handling & Reliability

### US-624: Comprehensive Error Recovery
**Priority**: High  
**Estimate**: 3 points

**Description**: Graceful handling of all error conditions.

**Acceptance Criteria**:
- [ ] Audio capture errors: retry with default device
- [ ] Transcription errors: show error toast with details
- [ ] Permission errors: direct link to System Settings
- [ ] Model loading errors: offer re-download option
- [ ] All errors logged for debugging

---

### US-625: Crash Reporting & Logging
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Implement logging for debugging user issues.

**Acceptance Criteria**:
- [ ] Log file in `~/Library/Logs/WispFlow/`
- [ ] Configurable log level (error, warning, info, debug)
- [ ] Log rotation (keep last 5 files, max 10MB each)
- [ ] "Export Logs" button in Settings
- [ ] Include system info in logs (macOS version, device info)

---

### US-626: Health Check on Launch
**Priority**: Medium  
**Estimate**: 1 point

**Description**: Verify app components are working on launch.

**Acceptance Criteria**:
- [ ] Check audio system availability
- [ ] Check Whisper model integrity
- [ ] Check required permissions
- [ ] Show status in menu bar menu
- [ ] Alert if critical issues found

---

## Phase 7: Performance Optimization

### US-627: Memory Usage Optimization
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Reduce memory footprint for long-running operation.

**Acceptance Criteria**:
- [ ] Clear audio buffers after transcription
- [ ] Lazy-load Whisper model on first use
- [ ] Unload model after period of inactivity (optional)
- [ ] Memory usage under 200MB during idle

---

### US-628: Startup Time Optimization
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Reduce time from app launch to ready state.

**Acceptance Criteria**:
- [ ] App window visible within 1 second
- [ ] Model loading in background
- [ ] Show "Loading model..." status in menu
- [ ] Defer non-critical initialization

---

### US-629: Battery Impact Reduction
**Priority**: Low  
**Estimate**: 1 point

**Description**: Minimize battery impact when idle.

**Acceptance Criteria**:
- [ ] No CPU usage when idle (no polling)
- [ ] Use event-based device monitoring
- [ ] Efficient hotkey detection (no busy loops)
- [ ] App Nap compatible when possible

---

## Phase 8: Accessibility & Localization

### US-630: VoiceOver Support
**Priority**: Medium  
**Estimate**: 2 points

**Description**: Full VoiceOver accessibility for all UI elements.

**Acceptance Criteria**:
- [ ] All buttons have accessibility labels
- [ ] All status changes announced
- [ ] Keyboard navigation works everywhere
- [ ] Recording status announced

---

### US-631: Localization Preparation
**Priority**: Low  
**Estimate**: 2 points

**Description**: Prepare app for future localization.

**Acceptance Criteria**:
- [ ] All user-facing strings in Localizable.strings
- [ ] No hardcoded strings in UI code
- [ ] Date/number formatting uses locale
- [ ] UI layouts accommodate longer strings

---

## Summary

| Phase | Stories | Total Points |
|-------|---------|--------------|
| Phase 1: Audio System Hardening | 4 | 8 |
| Phase 2: Transcription Quality | 4 | 8 |
| Phase 3: Hotkey System | 3 | 6 |
| Phase 4: Text Insertion | 3 | 6 |
| **Phase 5: Premium UI Redesign** | **9** | **28** |
| Phase 6: Error Handling | 3 | 6 |
| Phase 7: Performance | 3 | 5 |
| Phase 8: Accessibility | 2 | 4 |
| **Total** | **31** | **71** |

## Priority Order for Implementation

### Must Have (P0) - Core Stability & Premium UI Foundation
- US-601: Audio Device Hot-Plug Support
- US-602: Audio Format Negotiation
- US-605: Whisper Model Selection
- US-609: Custom Hotkey Configuration
- US-613: Undo Support
- **US-615: Design System Foundation** ⭐ UI
- **US-616: Settings Window Redesign** ⭐ UI
- **US-617: Recording Indicator Redesign** ⭐ UI
- US-624: Comprehensive Error Recovery

### Should Have (P1) - Enhanced Features & UI Polish
- US-603: Recording Timeout Safety
- US-604: Audio Level Calibration
- US-606: Language Selection
- US-610: Multiple Hotkey Modes
- US-612: Smart Punctuation
- US-614: Text Insertion Fallback
- **US-618: Toast Notification System Redesign** ⭐ UI
- **US-619: Onboarding Wizard Redesign** ⭐ UI
- **US-620: Menu Bar Experience** ⭐ UI
- **US-621: Transcription Result Display** ⭐ UI
- US-625: Crash Reporting & Logging
- US-626: Health Check on Launch
- US-627: Memory Usage Optimization
- US-628: Startup Time Optimization

### Nice to Have (P2) - Final Polish
- US-607: Transcription Post-Processing
- US-608: Retry Failed Transcriptions
- US-611: Hotkey Feedback Sound
- **US-622: Dark/Light Mode Support** ⭐ UI
- **US-623: Motion & Animation Polish** ⭐ UI
- US-629: Battery Impact Reduction
- US-630: VoiceOver Support
- US-631: Localization Preparation

---

## Design Skill Reference

This PRD incorporates the **frontend-design** skill for Phase 5. Key principles:

1. **Bold Aesthetic Direction**: Commit to a distinct visual identity - refined/professional, moody/dark, or crisp/light
2. **No Generic AI Aesthetics**: Avoid Inter, Roboto, purple gradients, cookie-cutter layouts
3. **Typography First**: Display fonts with personality, refined body text, clear hierarchy
4. **Intentional Color**: Lead with dominant color, punctuate with sharp accents
5. **Motion & Delight**: Spring animations, staggered reveals, micro-interactions
6. **Spatial Composition**: Asymmetry, z-depth, generous whitespace OR intentional density

Every UI element should feel **distinctive, memorable, and production-grade**.
