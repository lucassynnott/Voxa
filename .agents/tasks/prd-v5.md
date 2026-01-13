# WispFlow v0.5 - Beautiful Modern Light Mode UI

## Overview

Transform WispFlow from a basic utility into a visually stunning, polished macOS application with a distinctive light mode aesthetic. The UI should feel premium, memorable, and delightful to use.

## Design Vision

### Aesthetic Direction: Refined Editorial Minimalism
- **Tone**: Clean, sophisticated, warm - like a beautifully designed magazine or premium productivity app
- **Inspiration**: Linear, Raycast, Things 3, Craft - apps known for exceptional UI polish
- **Differentiation**: Warm cream/ivory tones instead of harsh white, subtle textures, elegant typography, micro-interactions that delight

### Color Palette
- **Background**: Warm ivory/cream (#FEFCF8) - not harsh white
- **Surface**: Soft white (#FFFFFF) with subtle shadows
- **Primary Accent**: Warm coral/terracotta (#E07A5F) - distinctive, not generic blue
- **Secondary**: Muted sage green (#81B29A) for success states
- **Text Primary**: Warm charcoal (#2D3436) - not pure black
- **Text Secondary**: Warm gray (#636E72)
- **Borders**: Very subtle warm gray (#E8E4DF)

### Typography
- **Display/Headers**: SF Pro Rounded or similar soft geometric sans
- **Body**: SF Pro Text for readability
- **Monospace**: SF Mono for any code/technical elements
- **Style**: Generous letter-spacing for headers, comfortable line-height

### Visual Details
- **Shadows**: Soft, warm-toned shadows (not harsh gray)
- **Corners**: Generous border-radius (12-16px) for cards and buttons
- **Spacing**: Generous whitespace, breathing room
- **Textures**: Subtle noise/grain overlay for depth
- **Icons**: SF Symbols with custom tinting

## Core UI Components

### 1. Menu Bar Icon & Dropdown
- Custom-designed microphone icon (not generic SF Symbol)
- Elegant dropdown menu with rounded corners
- Smooth fade-in animation
- Recording state: Pulsing coral glow
- Hover states with subtle background shifts

### 2. Recording Indicator (Floating Pill)
- Frosted glass effect (NSVisualEffectView with custom tinting)
- Smooth slide-down animation on appear
- Live waveform visualization (not just bars)
- Warm coral recording indicator
- Elegant cancel button with hover state
- Audio level as flowing wave, not harsh bars

### 3. Settings Window
- Large, spacious window (600x500 minimum)
- Tab bar with elegant icons and labels
- Cards/sections with subtle shadows
- Toggle switches with custom coral accent
- Dropdown menus with smooth animations
- Progress bars with gradient fills
- Input fields with focus glow effects

### 4. Onboarding/Welcome Flow
- First-launch welcome screen
- Step-by-step permission grants with illustrations
- Progress indicators
- Celebration animation on completion

### 5. Notifications/Toasts
- Slide-in from top-right
- Frosted glass background
- Auto-dismiss with progress bar
- Success/error/info variants

## Routing Policy
- Commit URLs are invalid.
- Unknown GitHub subpaths canonicalize to repo root.

---

## MVP Scope (v0.5)

### [x] US-401: Design System Foundation
As a developer, I want a centralized design system so all UI components are consistent.
- [x] Create DesignSystem.swift with color definitions (Color.wispflow.background, .accent, etc.)
- [x] Define typography styles (Font.wispflow.title, .body, .caption)
- [x] Define spacing constants (Spacing.xs, .sm, .md, .lg, .xl)
- [x] Define corner radius constants
- [x] Define shadow styles
- [x] Create reusable button styles (WispflowButtonStyle)
- [x] Create reusable card style (WispflowCardStyle)

### [x] US-402: Refined Menu Bar Experience
As a user, I want an elegant menu bar presence that feels premium.
- [x] Custom microphone icon design (idle/recording states)
- [x] Redesigned dropdown menu with warm colors
- [x] Smooth fade-in/out animations
- [x] Recording state with coral pulsing glow
- [x] Hover states on menu items with subtle transitions
- [x] Consistent typography and spacing
- [x] Warm ivory background tint

### [x] US-403: Beautiful Recording Indicator
As a user, I want a stunning recording indicator that's a joy to look at.
- [x] Redesign as elegant floating pill with frosted glass effect
- [x] Smooth slide-down animation on appear, slide-up on dismiss
- [x] Live audio waveform visualization (smooth wave, not bars)
- [x] Warm coral recording dot with gentle pulse
- [x] Elegant cancel button (X) with hover glow
- [x] Show recording duration with elegant typography
- [x] Drop shadow for floating effect

### [x] US-404: Modern Settings Window
As a user, I want a settings window that feels like a premium app.
- [x] Increase window size (600x500+)
- [x] Custom tab bar with icons and labels
- [x] Warm ivory background
- [x] Card-based sections with soft shadows
- [x] Custom toggle switches with coral accent
- [x] Styled dropdown menus
- [x] Progress bars with gradient fills
- [x] Input fields with focus glow
- [x] Generous spacing throughout

### [x] US-405: General Settings Tab Polish
As a user, I want the General settings to look beautiful.
- [x] Hotkey recorder with elegant focus state
- [x] Launch at Login toggle with description
- [x] App version display with subtle styling
- [x] "About WispFlow" section with logo
- [x] Links styled as subtle buttons

### [x] US-406: Audio Settings Tab Polish
As a user, I want the Audio settings to be visually refined.
- [x] Device picker as elegant dropdown with device icons
- [x] Audio level preview with smooth animation
- [x] Input gain slider with custom styling
- [x] Visual meter showing current input level

### [x] US-407: Transcription Settings Tab Polish
As a user, I want the Transcription settings to look premium.
- [x] Model selector as elegant card-based picker
- [x] Download progress with gradient bar
- [x] Model status badges (Downloaded, Ready, Error)
- [x] Language selector with flag icons
- [x] Clear visual hierarchy

### [x] US-408: Text Cleanup Settings Tab Polish
As a user, I want the Text Cleanup settings beautifully designed.
- [x] Mode selector as segmented control
- [x] Enable/disable toggle with description
- [x] LLM model section as card
- [x] Preview of cleanup behavior

### [ ] US-409: Toast Notification System
As a user, I want elegant notifications for app events.
- Create WispflowToast view component
- Slide-in from top-right animation
- Frosted glass background
- Auto-dismiss with timer
- Success (sage green), Error (coral), Info (gray) variants
- Icon + message + optional action button

### [ ] US-410: Micro-interactions & Polish
As a user, I want delightful micro-interactions throughout the app.
- Button press animations (scale down slightly)
- Toggle switch animations
- Tab switching transitions
- Loading state animations
- Success checkmark animations
- Hover state transitions on all interactive elements

## Technical Implementation

### SwiftUI Design System
```swift
// Colors
extension Color {
    struct Wispflow {
        static let background = Color(hex: "FEFCF8")
        static let surface = Color.white
        static let accent = Color(hex: "E07A5F")
        static let success = Color(hex: "81B29A")
        static let textPrimary = Color(hex: "2D3436")
        static let textSecondary = Color(hex: "636E72")
        static let border = Color(hex: "E8E4DF")
    }
}

// Typography
extension Font {
    struct Wispflow {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)
    }
}
```

### Custom Components
- WispflowButton (primary, secondary, ghost variants)
- WispflowCard (with shadow and rounded corners)
- WispflowToggle (coral accent)
- WispflowTextField (with focus glow)
- WispflowDropdown (styled picker)
- WispflowProgressBar (gradient fill)

## Success Criteria

1. App feels premium and distinctive (not generic macOS)
2. Consistent warm light mode aesthetic throughout
3. Smooth animations on all interactive elements
4. Settings window is spacious and well-organized
5. Recording indicator is visually stunning
6. All components follow design system

## Acceptance Criteria

1. Color palette matches spec (warm ivory, coral accent)
2. Typography is consistent (SF Pro Rounded headers)
3. All buttons have hover/press states
4. Settings window is minimum 600x500
5. Recording indicator has waveform visualization
6. Toast notifications slide in smoothly
7. No harsh whites or generic blues anywhere
