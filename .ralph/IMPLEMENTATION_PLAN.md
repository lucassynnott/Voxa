# Implementation Plan - WispFlow v0.5

## Summary

WispFlow v0.4 (US-301 through US-306) is complete with unified audio buffer architecture, tap verification, buffer integrity logging, model download improvements, and audio debug export.

**v0.5 focuses on a comprehensive UI refresh to transform WispFlow into a polished, premium macOS application:**

1. **No Design System Exists**: The codebase has no centralized design tokens. All colors, fonts, spacing, and styles are hardcoded inline throughout `SettingsWindow.swift`, `RecordingIndicatorWindow.swift`, and `StatusBarController.swift`.

2. **Current UI State**:
   - Settings window: 520x580 pixels, uses default SwiftUI Form/Section styling
   - Recording indicator: NSPanel with NSVisualEffectView (.hudWindow material), standard SF Symbols
   - Menu bar: Standard NSStatusItem with system icons
   - No custom theming, no warm color palette, no custom animations

3. **Key Gaps vs PRD Requirements**:
   - Missing: DesignSystem.swift with color/typography/spacing tokens
   - Missing: Warm ivory/cream (#FEFCF8) background instead of default system colors
   - Missing: Coral accent (#E07A5F) instead of system blue
   - Missing: Custom button styles (WispflowButtonStyle)
   - Missing: Card-based section styling with soft shadows
   - Missing: Custom toggle switches with coral accent
   - Missing: Toast notification system
   - Missing: Live waveform visualization (current is simple bar meter)
   - Missing: Micro-interactions and button press animations
   - Missing: Welcome/onboarding flow (lower priority for MVP)

### Priority Order (based on design dependency graph):
1. **US-401 (Design System Foundation)** - All other stories depend on this
2. **US-404 (Modern Settings Window)** - Largest visual impact, uses design system
3. **US-403 (Beautiful Recording Indicator)** - High visibility during use
4. **US-402 (Refined Menu Bar Experience)** - AppKit/NSStatusItem changes
5. **US-405-408 (Settings Tab Polish)** - Incremental improvements per tab
6. **US-409 (Toast Notification System)** - New component
7. **US-410 (Micro-interactions & Polish)** - Final polish pass

---

## Tasks

### US-401: Design System Foundation
As a developer, I want a centralized design system so all UI components are consistent.

- [x] Create DesignSystem.swift with color definitions
  - Scope: Create new file `Sources/WispFlow/DesignSystem.swift`
  - Define `Color.Wispflow.background` (#FEFCF8 warm ivory)
  - Define `Color.Wispflow.surface` (white #FFFFFF)
  - Define `Color.Wispflow.accent` (#E07A5F warm coral)
  - Define `Color.Wispflow.success` (#81B29A muted sage)
  - Define `Color.Wispflow.textPrimary` (#2D3436 warm charcoal)
  - Define `Color.Wispflow.textSecondary` (#636E72 warm gray)
  - Define `Color.Wispflow.border` (#E8E4DF subtle warm gray)
  - Add NSColor equivalents for AppKit components
  - Acceptance: All colors defined as static properties with hex extension helper
  - Verification: `swift build` passes ✓

- [x] Define typography styles in DesignSystem.swift
  - Scope: Add `Font.Wispflow` namespace in `Sources/WispFlow/DesignSystem.swift`
  - Define `Font.Wispflow.largeTitle` (28pt, bold, rounded)
  - Define `Font.Wispflow.title` (20pt, semibold, rounded)
  - Define `Font.Wispflow.headline` (16pt, semibold, rounded)
  - Define `Font.Wispflow.body` (14pt, regular)
  - Define `Font.Wispflow.caption` (12pt, medium)
  - Define `Font.Wispflow.small` (11pt, regular)
  - Add NSFont equivalents for AppKit components
  - Acceptance: All font styles defined and use .rounded design where specified
  - Verification: `swift build` passes ✓

- [x] Define spacing constants in DesignSystem.swift
  - Scope: Add `Spacing` namespace in `Sources/WispFlow/DesignSystem.swift`
  - Define `Spacing.xs` (4pt), `Spacing.sm` (8pt), `Spacing.md` (12pt), `Spacing.lg` (16pt), `Spacing.xl` (24pt), `Spacing.xxl` (32pt)
  - Define `CornerRadius.small` (8pt), `CornerRadius.medium` (12pt), `CornerRadius.large` (16pt)
  - Define shadow styles: `ShadowStyle.card`, `ShadowStyle.floating`
  - Acceptance: All constants defined and documented
  - Verification: `swift build` passes ✓

- [x] Create WispflowButtonStyle view modifier
  - Scope: Add custom ButtonStyle in `Sources/WispFlow/DesignSystem.swift`
  - Primary style: coral background, white text, rounded corners
  - Secondary style: light gray background, coral text
  - Ghost style: transparent background, coral text
  - Include press animation (scale down 0.97)
  - Include hover state color change
  - Acceptance: Button styles work on SwiftUI buttons
  - Verification: `swift build` passes ✓

- [x] Create WispflowCardStyle view modifier
  - Scope: Add custom ViewModifier in `Sources/WispFlow/DesignSystem.swift`
  - White background with soft warm shadow
  - 12px corner radius
  - Generous internal padding (16pt)
  - Acceptance: Can wrap any view in card styling
  - Verification: `swift build` passes ✓

- [x] Create WispflowToggleStyle
  - Scope: Add custom ToggleStyle in `Sources/WispFlow/DesignSystem.swift`
  - Coral (#E07A5F) thumb when on
  - Smooth animation on toggle
  - Match system toggle size
  - Acceptance: Toggle shows coral accent when enabled
  - Verification: `swift build` passes ✓

**Implementation Notes (US-401):**
- Created comprehensive DesignSystem.swift with ~400 lines of code
- Added Color.Wispflow and NSColor.Wispflow namespaces with full color palette
- Added Font.Wispflow and NSFont.Wispflow namespaces with all typography styles
- Added Spacing enum with xs/sm/md/lg/xl/xxl constants
- Added CornerRadius enum with small/medium/large/extraLarge constants
- Added ShadowStyle enum with card/floating/subtle presets and .wispflowShadow() modifier
- Created WispflowButtonStyle with primary/secondary/ghost variants and press animations
- Created WispflowCardStyle ViewModifier with .wispflowCard() extension
- Created WispflowToggleStyle with coral accent and smooth animation
- Created WispflowTextFieldStyle for consistent text input styling
- Added WispflowAnimation presets for micro-interactions

---

### US-402: Refined Menu Bar Experience
As a user, I want an elegant menu bar presence that feels premium.

- [x] Update menu bar icon with custom tinting
  - Scope: Modify `Sources/WispFlow/StatusBarController.swift`
  - Use warm charcoal (#2D3436) tint for idle icon
  - Use coral (#E07A5F) tint for recording state
  - Keep existing SF Symbols but apply custom tinting
  - Acceptance: Menu bar icon uses warm colors instead of system defaults
  - Verification: `swift build` passes ✓

- [x] Redesign dropdown menu with warm styling
  - Scope: Modify `Sources/WispFlow/StatusBarController.swift` setupMenu()
  - Apply warm ivory background if possible via NSAppearance
  - Add subtle icons to menu items (gear for settings, speaker for audio, power for quit)
  - Improve menu item typography with proper spacing
  - Acceptance: Menu has consistent styling with design system colors
  - Verification: `swift build` passes ✓

- [x] Add recording state visual feedback
  - Scope: Modify `Sources/WispFlow/StatusBarController.swift` updateIcon()
  - Pulsing effect on menu bar icon during recording (via NSTimer animation)
  - Coral tint during active recording
  - Acceptance: Menu bar icon pulses/glows when recording is active
  - Verification: `swift build` passes ✓

**Implementation Notes (US-402):**
- Added warm color tinting to menu bar icon using NSColor.Wispflow palette
- Idle state uses warm charcoal (#2D3436) for ready icon, textSecondary for other states
- Recording state uses coral accent (#E07A5F) with pulsing animation
- Added icons to dropdown menu items: gear for Settings, mic for Audio Input, arrow.counterclockwise.circle for Launch at Login, power for Quit
- Implemented pulse animation using Timer at 0.05s intervals with sine wave oscillation
- Pulse varies alpha between 0.7-1.0 and adjusts coral brightness for glow effect
- Created helper methods: createTintedStatusIcon(), createMenuIcon(), startPulseAnimation(), stopPulseAnimation()
- Animation properly cleans up on state change and controller deallocation

---

### US-403: Beautiful Recording Indicator
As a user, I want a stunning recording indicator that's a joy to look at.

- [x] Update recording indicator colors to design system
  - Scope: Modify `Sources/WispFlow/RecordingIndicatorWindow.swift`
  - Use coral (#E07A5F) for recording dot instead of systemRed
  - Use warm charcoal (#2D3436) for text instead of labelColor
  - Update cancel button to warm gray with coral hover via HoverGlowButton
  - Acceptance: Recording indicator uses design system colors ✓
  - Verification: `swift build` passes ✓

- [x] Enhance frosted glass effect with warm tint
  - Scope: Modify `Sources/WispFlow/RecordingIndicatorWindow.swift` setupUI()
  - Apply warm ivory tint overlay to NSVisualEffectView
  - Increased corner radius to 26px for larger pill
  - Added warm drop shadow for floating effect
  - Acceptance: Floating pill has warmer appearance ✓
  - Verification: `swift build` passes ✓

- [x] Replace audio level meter with smooth waveform visualization
  - Scope: Created `LiveWaveformView` in `Sources/WispFlow/RecordingIndicatorWindow.swift`
  - Smooth, animated sine wave that responds to audio level
  - Uses design system colors: coral for active, sage green for normal levels
  - Organic multi-wave animation at 30fps
  - Acceptance: Waveform uses warm color palette with smooth animation ✓
  - Verification: `swift build` passes ✓

- [x] Add recording duration display
  - Scope: Added duration timer and label to RecordingIndicatorWindow
  - Shows elapsed time separately from status label (e.g., "0:05")
  - Uses semibold 14pt font for emphasis
  - Update label dynamically via 1-second timer
  - Acceptance: Recording duration shown in real-time ✓
  - Verification: `swift build` passes ✓

- [x] Enhance show/hide animations
  - Scope: Modified showWithAnimation()/hideWithAnimation() in RecordingIndicatorWindow
  - Added slide-down effect on appear (from above screen)
  - Added slide-up effect on dismiss
  - Animation duration 0.35s with easeOut/easeIn timing functions
  - Acceptance: Recording indicator slides in/out elegantly ✓
  - Verification: `swift build` passes ✓

- [x] Add coral pulsing recording dot
  - Scope: Replaced mic icon with circular dot that pulses
  - Smooth pulse animation varies opacity (0.8-1.0) and scale (0.9-1.1)
  - Uses warm coral (#E07A5F) from design system
  - Acceptance: Recording dot pulses gently ✓
  - Verification: `swift build` passes ✓

- [x] Create elegant cancel button with hover glow
  - Scope: Created `HoverGlowButton` class
  - Coral glow effect on hover with shadow
  - Scale animation on press (0.9x)
  - Uses design system colors
  - Acceptance: Cancel button has elegant hover/press states ✓
  - Verification: `swift build` passes ✓

**Implementation Notes (US-403):**
- Renamed LiveWaveformView to avoid conflict with existing AudioWaveformView (SwiftUI)
- Recording indicator window size increased from 200x44 to 240x52 for better proportions
- Added shadow view layer behind visual effect for floating appearance
- Timer-based animations for pulse and waveform provide smooth 30fps updates
- Duration timer starts/stops with show/hide to ensure accurate timing
- All timers properly cleaned up in deinit to prevent memory leaks

---

### US-404: Modern Settings Window
As a user, I want a settings window that feels like a premium app.

- [x] Increase settings window size to 600x500+
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` line ~66
  - Change `.frame(width: 520, height: 580)` to `.frame(width: 620, height: 560)`
  - Acceptance: Settings window is larger with more breathing room ✓
  - Verification: `swift build` passes ✓

- [x] Apply warm ivory background to settings window
  - Scope: Modify SettingsView in `Sources/WispFlow/SettingsWindow.swift`
  - Add `.background(Color.Wispflow.background)` to root view
  - Wrapped in ZStack for full coverage
  - Acceptance: Settings window has warm ivory (#FEFCF8) background ✓
  - Verification: `swift build` passes ✓

- [x] Redesign tab bar with icons and styling
  - Scope: Modify TabView in `Sources/WispFlow/SettingsWindow.swift`
  - Tab icons use design system colors via background styling
  - Warm ivory background applied to tab content
  - Acceptance: Tab bar has consistent warm styling ✓
  - Verification: `swift build` passes ✓

- [x] Replace Form sections with card-based layout
  - Scope: Replaced all Form/Section uses in `Sources/WispFlow/SettingsWindow.swift`
  - All tabs now use ScrollView with VStack and .wispflowCard() modifier
  - Each settings section is a distinct card with soft shadows
  - Used Spacing constants for consistent layout
  - Acceptance: Settings sections display as distinct cards with shadows ✓
  - Verification: `swift build` passes ✓

- [x] Update all buttons to use WispflowButtonStyle
  - Scope: Replaced all `.buttonStyle(.borderedProminent)` and `.buttonStyle(.bordered)` in SettingsWindow.swift
  - Use `.buttonStyle(WispflowButtonStyle.primary)` for main actions
  - Use `.buttonStyle(WispflowButtonStyle.secondary)` for secondary actions
  - Use `.buttonStyle(WispflowButtonStyle.ghost)` for tertiary actions
  - Acceptance: All buttons in settings use coral accent styling ✓
  - Verification: `swift build` passes ✓

- [x] Update all toggles to use WispflowToggleStyle
  - Scope: Replaced all `.toggleStyle(.switch)` in SettingsWindow.swift
  - Use `.toggleStyle(WispflowToggleStyle())` for coral accent
  - Acceptance: All toggles show coral when enabled ✓
  - Verification: `swift build` passes ✓

- [x] Update typography to use design system fonts
  - Scope: Replaced all `.font(.headline)`, `.font(.caption)` etc in SettingsWindow.swift
  - Use `Font.Wispflow.headline`, `Font.Wispflow.caption`, etc
  - Use `Color.Wispflow.textPrimary` and `Color.Wispflow.textSecondary` for text colors
  - Acceptance: All text uses design system typography ✓
  - Verification: `swift build` passes ✓

**Implementation Notes (US-404):**
- Increased window size from 520x580 to 620x560 for better breathing room
- Wrapped main SettingsView in ZStack with Color.Wispflow.background for warm ivory
- Converted all 5 settings tabs from Form/GroupBox to ScrollView + VStack + .wispflowCard()
- Updated all buttons to WispflowButtonStyle (primary, secondary, ghost variants)
- Updated all toggles to WispflowToggleStyle with coral accent
- Updated all text to use Font.Wispflow and Color.Wispflow typography
- Updated StatusBadge, LLMStatusBadge, CleanupStatusBadge to use design system colors
- Updated DebugFeatureRow, CleanupFeatureRow, InsertionFeatureRow to use design system
- Enhanced HotkeyRecorderView with coral focus glow and hover states
- Added custom gradient progress bars for download progress (coral gradient fill)
- Used Spacing and CornerRadius constants throughout for consistency

---

### US-405: General Settings Tab Polish
As a user, I want the General settings to look beautiful.

- [x] Style hotkey recorder with elegant focus state
  - Scope: Modify `HotkeyRecorderView` in `Sources/WispFlow/SettingsWindow.swift`
  - Add coral border glow on focus
  - Use design system colors for background/text
  - Rounded corners (12px)
  - Acceptance: Hotkey recorder looks polished with focus glow ✓
  - Verification: `swift build` passes ✓

- [x] Add About WispFlow section with logo
  - Scope: Modify `GeneralSettingsView` in `Sources/WispFlow/SettingsWindow.swift`
  - Add app icon/logo display using SF Symbol waveform.circle.fill with gradient
  - Show app name with design system largeTitle font
  - Show version number styled subtly with pill background
  - Acceptance: About section displays app branding ✓
  - Verification: `swift build` passes ✓

- [x] Style launch at login toggle
  - Scope: Modify `GeneralSettingsView` toggle for launch at login
  - Add helpful description text below toggle
  - Use WispflowToggleStyle
  - Acceptance: Toggle is styled consistently with description ✓
  - Verification: `swift build` passes ✓

- [x] Add links styled as subtle buttons
  - Scope: Created SubtleLinkButton component
  - GitHub, Website, Support links with hover effects
  - Uses design system colors and hover animations
  - Acceptance: Links appear as elegant buttons with hover state ✓
  - Verification: `swift build` passes ✓

**Implementation Notes (US-405):**
- Completely redesigned GeneralSettingsView with hero About section at top
- Created app logo representation using SF Symbol waveform.circle.fill with gradient overlay
- App name displayed in largeTitle font (28pt, bold, rounded)
- Version number displayed with subtle pill-style background
- Created SubtleLinkButton component with hover animations for GitHub/Website/Support links
- Enhanced HotkeyRecorderView with:
  - Pulsing coral dot animation when recording
  - Command symbol icon with hover color change
  - Coral glow shadow on focus/recording
  - Scale animation on recording state
  - Increased corner radius to medium (12px)
- Launch at Login section now has icon header and indented description text
- Global Hotkey section has keyboard icon header
- All sections use consistent card styling with wispflowCard() modifier

---

### US-406: Audio Settings Tab Polish
As a user, I want the Audio settings to be visually refined.

- [x] Create dedicated AudioSettingsView tab
  - Scope: Add new `AudioSettingsView` struct in `Sources/WispFlow/SettingsWindow.swift`
  - Move audio device selection from menu bar to settings
  - Add audio level preview with real-time meter
  - Add input gain slider (if supported by Core Audio)
  - Acceptance: Audio settings has its own tab with device picker and level preview ✓
  - Verification: `swift build` passes ✓

- [x] Style device picker as elegant dropdown
  - Scope: Create device picker in AudioSettingsView
  - Use Picker with custom styling
  - Add device icons (speaker.wave.2 for each device)
  - Show current device clearly
  - Acceptance: Device picker uses design system styling ✓
  - Verification: `swift build` passes ✓

- [x] Add live audio level meter in settings
  - Scope: Add real-time level meter component in AudioSettingsView
  - Connect to AudioManager.currentAudioLevel publisher
  - Use design system colors (sage green for normal, coral for loud)
  - Acceptance: Audio level displays in real-time when settings open ✓
  - Verification: `swift build` passes ✓

**Implementation Notes (US-406):**
- Created AudioSettingsView struct with 4 polished cards: Device Selection, Audio Level Preview, Input Sensitivity, and Audio Info
- Created AudioDevicePicker component with elegant dropdown animation and device-specific icons (AirPods, laptop, USB, etc.)
- Created AudioDeviceRow for individual device items with hover states and checkmark for selection
- Created AudioLevelMeterView with 30-segment visual meter that shows coral/green/red based on level
- Added live preview functionality that starts/stops audio capture for testing microphone
- Created CustomSlider with coral accent gradient and animated thumb with hover/drag states
- Input Sensitivity slider allows users to adjust visual meter display gain (0.5x-2.0x)
- Level indicator shows real-time dB value and status (Good/Quiet/Silent/Too Loud) with color-coded badges
- All components use design system colors, fonts, spacing, and corner radius constants
- Updated SettingsWindowController to accept AudioManager parameter
- Updated AppDelegate to pass audioManager to SettingsWindowController
- Audio tab added to TabView with speaker.wave.2 icon

---

### US-407: Transcription Settings Tab Polish
As a user, I want the Transcription settings to look premium.

- [ ] Redesign model selector as card-based picker
  - Scope: Modify `TranscriptionSettingsView` Picker in SettingsWindow.swift
  - Replace radio group with card-based selection
  - Each model as a card with name, size, and download status
  - Selected card has coral border
  - Acceptance: Model selection uses elegant card UI
  - Verification: `swift build` passes

- [ ] Style progress bar with gradient fill
  - Scope: Modify download progress ProgressView in TranscriptionSettingsView
  - Use coral gradient fill instead of system blue
  - Add percentage text styled with design system
  - Acceptance: Download progress shows coral gradient
  - Verification: `swift build` passes

- [ ] Improve model status badges
  - Scope: Modify `StatusBadge` in SettingsWindow.swift
  - Use design system colors: coral for error, sage for ready
  - Improve badge styling with proper padding
  - Acceptance: Status badges use design system colors
  - Verification: `swift build` passes

---

### US-408: Text Cleanup Settings Tab Polish
As a user, I want the Text Cleanup settings beautifully designed.

- [ ] Style mode selector as segmented control
  - Scope: Modify `TextCleanupSettingsView` Picker in SettingsWindow.swift
  - Use segmented picker style with coral accent for selection
  - Clear visual distinction between modes
  - Acceptance: Cleanup mode uses segmented control styling
  - Verification: `swift build` passes

- [ ] Improve LLM settings panel styling
  - Scope: Modify LLM settings section in TextCleanupSettingsView
  - Use card-based layout for LLM model selection
  - Consistent styling with Transcription settings
  - Acceptance: LLM settings match overall design system
  - Verification: `swift build` passes

- [ ] Add cleanup preview panel
  - Scope: Add preview section showing example cleanup
  - Show "Before" and "After" text comparison
  - Use subtle background differentiation
  - Acceptance: Users can see cleanup effect preview
  - Verification: `swift build` passes

---

### US-409: Toast Notification System
As a user, I want elegant notifications for app events.

- [ ] Create WispflowToast view component
  - Scope: Create new file `Sources/WispFlow/ToastView.swift` or add to DesignSystem.swift
  - Frosted glass background using Visual Effect (SwiftUI)
  - Icon + message + optional action button layout
  - Success (sage green), Error (coral), Info (gray) variants
  - Auto-dismiss timer with progress indicator
  - Acceptance: Toast component renders correctly
  - Verification: `swift build` passes

- [ ] Implement toast presentation manager
  - Scope: Create `ToastManager` class (ObservableObject)
  - Queue system for multiple toasts
  - Slide-in from top-right animation
  - Auto-dismiss after configurable duration
  - Acceptance: Toasts can be triggered and displayed
  - Verification: `swift build` passes

- [ ] Integrate toast notifications
  - Scope: Modify `AppDelegate.swift` to use ToastManager
  - Show toast on successful transcription
  - Show toast on transcription error
  - Show toast on model download complete
  - Acceptance: App events trigger appropriate toasts
  - Verification: `swift build` passes

---

### US-410: Micro-interactions & Polish
As a user, I want delightful micro-interactions throughout the app.

- [ ] Add button press animations
  - Scope: Ensure WispflowButtonStyle includes scale animation
  - Press: scale to 0.97
  - Release: spring back to 1.0
  - Duration: 0.1s ease-out
  - Acceptance: Buttons visually respond to press
  - Verification: `swift build` passes

- [ ] Add toggle switch animations
  - Scope: Ensure WispflowToggleStyle has smooth transition
  - Thumb slides smoothly
  - Color transition is animated
  - Acceptance: Toggles animate smoothly
  - Verification: `swift build` passes

- [ ] Add tab switching transitions
  - Scope: Modify TabView in SettingsWindow.swift
  - Add subtle fade/slide between tabs (if SwiftUI supports)
  - At minimum ensure tabs switch without jarring
  - Acceptance: Tab switching feels smooth
  - Verification: `swift build` passes

- [ ] Add hover states on all interactive elements
  - Scope: Audit all buttons, toggles, cards in SettingsWindow.swift
  - Add `.onHover` modifiers for color changes
  - Subtle background shift on hover
  - Acceptance: Interactive elements respond to hover
  - Verification: `swift build` passes

- [ ] Add success checkmark animation
  - Scope: Create reusable animated checkmark component
  - Green checkmark that draws in
  - Use for successful operations (transcription, download complete)
  - Acceptance: Checkmark animation plays for success states
  - Verification: `swift build` passes

---

## Notes

### Discoveries

1. **No Existing Design System**: The codebase has no centralized color/font/spacing definitions. All styling is inline with system defaults. US-401 must be completed first as all other stories depend on it.

2. **AppKit + SwiftUI Mix**: The app uses both AppKit (NSPanel, NSStatusItem, NSVisualEffectView) and SwiftUI (Settings views). Design system must provide both Color/Font and NSColor/NSFont equivalents.

3. **Settings Window Uses Form**: Current SettingsWindow.swift uses SwiftUI Form/Section which has limited customization. May need to replace with VStack/HStack for full design control.

4. **Recording Indicator is AppKit**: RecordingIndicatorWindow.swift is pure AppKit (NSPanel, NSView, NSTextField). Will need to update using NSColor equivalents from design system.

5. **Audio Level Meter Exists**: `AudioLevelMeterView` already exists with color-coded levels. Just needs color updates to use design system palette.

6. **No Toast System**: There is no existing notification/toast system. US-409 requires building from scratch.

7. **Onboarding Not in MVP**: The PRD mentions onboarding/welcome flow (section 4 under Core UI Components) but it's not in the MVP scope stories. Should be deferred to v0.6.

### Risks

1. **SwiftUI TabView Limitations**: SwiftUI's TabView has limited customization options. May not be able to fully style tab bar as desired without custom implementation.

2. **NSVisualEffectView Tinting**: Warm tinting of NSVisualEffectView may be limited. May need alternative approach for frosted glass with warm tint.

3. **Performance of Animations**: Need to ensure micro-interactions don't impact transcription performance. Animations should be lightweight.

4. **Consistency Across macOS Versions**: Need to test visual appearance on macOS 14.0 and later to ensure consistent rendering.

### Technical Notes

- Use `Color(red:green:blue:)` initializer with hex conversion for precise color matching
- SwiftUI `.shadow()` modifier for card shadows
- `NSColor(srgbRed:green:blue:alpha:)` for AppKit equivalents
- `.animation(.spring(response:dampingFraction:))` for micro-interactions
- Consider `@Environment(\.colorScheme)` for future dark mode support (not in v0.5 scope)
