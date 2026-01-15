import SwiftUI
import AppKit

// MARK: - Color Extension for Hex Initialization

extension Color {
    /// Initialize a Color from a hex string (e.g., "E07A5F" or "#E07A5F")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - NSColor Extension for Hex Initialization

extension NSColor {
    /// Initialize an NSColor from a hex string (e.g., "E07A5F" or "#E07A5F")
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

// MARK: - Voxa Color Palette
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - Minimalist Color Tokens                                 ║
// ║                                                                              ║
// ║ Design Philosophy:                                                           ║
// ║ - Editorial, minimalist aesthetic with warm undertones                       ║
// ║ - Primary muted terracotta (#D97058) - sophisticated, not generic            ║
// ║ - Light mode: Warm Alabaster (#F9F8F6) background                            ║
// ║ - Dark mode: Deep Charcoal (#121212) background                              ║
// ║ - Typography: Playfair Display (display), Manrope (body)                     ║
// ║                                                                              ║
// ║ Color Token Guide:                                                           ║
// ║ - primary: Muted Terracotta for CTAs and accents                             ║
// ║ - background: Adapts to light (#F9F8F6) / dark (#121212) mode                ║
// ║ - surface: White in light, dark surface (#1E1E1E) in dark mode               ║
// ║ - sidebar: Slightly darker in dark mode (#0A0A0A)                            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

extension Color {
    /// Voxa design system colors
    /// 
    /// Usage:
    /// ```swift
    /// Text("Hello")
    ///     .foregroundColor(Color.Voxa.primary)
    ///     .background(Color.Voxa.background)
    /// ```
    struct Voxa {
        // MARK: - Brand Colors
        
        /// Primary brand color - muted terracotta (#D97058)
        /// Use for: primary buttons, key interactive elements, brand accents
        static var primary: Color {
            Color(hex: "D97058")
        }
        
        /// Alias for primary - use for interactive element consistency
        static var accent: Color { primary }
        
        /// High-contrast accent - darker terracotta for text on light backgrounds (#C4563F)
        static let accentContrast = Color(hex: "C4563F")
        
        // MARK: - Background Colors (Light/Dark Adaptive)
        
        /// Warm Alabaster background for light mode (#F9F8F6)
        static let backgroundLight = Color(hex: "F9F8F6")
        
        /// Deep Charcoal background for dark mode (#121212)
        static let backgroundDark = Color(hex: "121212")
        
        /// Adaptive background - use this for automatic light/dark support
        static var background: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "121212")
                } else {
                    return NSColor(hex: "F9F8F6")
                }
            }))
        }
        
        /// Light mode surface (white)
        static let surfaceLight = Color.white
        
        /// Dark mode surface (#1E1E1E)
        static let surfaceDark = Color(hex: "1E1E1E")
        
        /// Adaptive surface for cards/panels
        static var surface: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "1E1E1E")
                } else {
                    return NSColor.white
                }
            }))
        }
        
        /// Sidebar background - darker in dark mode (#0A0A0A)
        static var sidebarBackground: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "0A0A0A")
                } else {
                    return NSColor.white.withAlphaComponent(0.5)
                }
            }))
        }
        
        /// Subtle warm gray for section backgrounds (#F5F3F0 light / #1E1E1E dark)
        static var surfaceSecondary: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "1E1E1E")
                } else {
                    return NSColor(hex: "F5F3F0")
                }
            }))
        }
        
        // MARK: - Text Colors (Light/Dark Adaptive)
        
        /// Primary text - #2D2D2D light / #E0E0E0 dark
        static var textPrimary: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "E0E0E0")
                } else {
                    return NSColor(hex: "2D2D2D")
                }
            }))
        }
        
        /// Secondary/subtle text - #888888 both modes
        static var textSecondary: Color {
            Color(hex: "888888")
        }
        
        /// Disabled/placeholder text (#A0A0A0)
        static let textTertiary = Color(hex: "A0A0A0")
        
        // MARK: - Border & Divider Colors (Light/Dark Adaptive)
        
        /// Subtle border - #E5E5E5 light / #333333 dark
        static var border: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "333333")
                } else {
                    return NSColor(hex: "E5E5E5")
                }
            }))
        }
        
        /// Very subtle line - #E5E5E5 light / #27272A dark
        static var line: Color {
            Color(NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(hex: "27272A")
                } else {
                    return NSColor(hex: "E5E5E5")
                }
            }))
        }
        
        /// Stronger border for focus states (#D0CCC7)
        /// Use for: focused input borders, selected state outlines
        static let borderStrong = Color(hex: "D0CCC7")
        
        // MARK: - Semantic Colors (Feedback States)
        
        /// Muted sage green for success states (#81B29A)
        /// Use for: success messages, confirmations, positive actions
        static var success: Color {
            let customColor = Color(hex: "81B29A")
            return customColor.description.isEmpty ? Color.green : customColor
        }
        
        /// Warm orange for warning states (#E09F3E)
        /// Use for: warnings, caution messages, requires attention
        static var warning: Color {
            let customColor = Color(hex: "E09F3E")
            return customColor.description.isEmpty ? Color.orange : customColor
        }
        
        /// Warm red for error states (#D64545)
        /// Use for: errors, destructive actions, critical alerts
        static var error: Color {
            let customColor = Color(hex: "D64545")
            return customColor.description.isEmpty ? Color.red : customColor
        }
        
        /// Muted blue for info states (#5B8FB9)
        /// Use for: informational messages, tips, neutral highlights
        static let info = Color(hex: "5B8FB9")
        
        // MARK: - Light Variants (for backgrounds)
        
        /// Accent color at lighter opacity for backgrounds
        static var accentLight: Color { primary.opacity(0.15) }
        
        /// Success color at lighter opacity for backgrounds
        static var successLight: Color { success.opacity(0.15) }
        
        /// Error color at lighter opacity for backgrounds
        static var errorLight: Color { error.opacity(0.15) }
        
        /// Warning color at lighter opacity for backgrounds
        static var warningLight: Color { warning.opacity(0.15) }
        
        /// Info color at lighter opacity for backgrounds
        static let infoLight = info.opacity(0.15)
    }
}

// MARK: - NSColor Voxa Equivalents (for AppKit components)
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - NSColor Tokens (AppKit)                             ║
// ║                                                                              ║
// ║ These colors mirror the SwiftUI Color.Voxa palette for AppKit usage.     ║
// ║ Use these when working with NSView, NSWindow, or other AppKit components.    ║
// ║ Each color falls back to system equivalents if custom colors fail to load.   ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

extension NSColor {
    /// Voxa design system colors for AppKit
    struct Voxa {
        // MARK: - Brand Colors
        
        /// Primary brand color - warm coral/terracotta (#E07A5F)
        /// Fallback: System control accent color
        static var primary: NSColor {
            return NSColor(hex: "E07A5F")
        }
        
        /// Alias for primary - use for interactive element consistency
        static var accent: NSColor { primary }
        
        /// High-contrast accent - darker coral for text on light backgrounds (#C4563F)
        static let accentContrast = NSColor(hex: "C4563F")
        
        // MARK: - Background Colors
        
        /// Warm ivory/cream background (#FEFCF8)
        /// Fallback: System window background color
        static var background: NSColor {
            return NSColor(hex: "FEFCF8")
        }
        
        /// Soft white surface
        static let surface = NSColor.white
        
        /// Subtle warm gray for section backgrounds (#F5F3F0)
        static let surfaceSecondary = NSColor(hex: "F5F3F0")
        
        // MARK: - Text Colors
        
        /// Warm charcoal text (#2D3436)
        /// Fallback: System label color
        static var textPrimary: NSColor {
            return NSColor(hex: "2D3436")
        }
        
        /// Warm gray secondary text (#636E72)
        /// Fallback: System secondary label color
        static var textSecondary: NSColor {
            return NSColor(hex: "636E72")
        }
        
        /// Disabled/placeholder text (#A0A0A0)
        static let textTertiary = NSColor(hex: "A0A0A0")
        
        // MARK: - Border & Divider Colors
        
        /// Very subtle warm gray border (#E8E4DF)
        static let border = NSColor(hex: "E8E4DF")
        
        /// Stronger border for focus states (#D0CCC7)
        static let borderStrong = NSColor(hex: "D0CCC7")
        
        // MARK: - Semantic Colors (Feedback States)
        
        /// Muted sage green for success states (#81B29A)
        /// Fallback: System green
        static var success: NSColor {
            return NSColor(hex: "81B29A")
        }
        
        /// Warm orange for warning states (#E09F3E)
        /// Fallback: System orange
        static var warning: NSColor {
            return NSColor(hex: "E09F3E")
        }
        
        /// Warm red for error states (#D64545)
        /// Fallback: System red
        static var error: NSColor {
            return NSColor(hex: "D64545")
        }
        
        /// Muted blue for info states (#5B8FB9)
        static let info = NSColor(hex: "5B8FB9")
    }
}

// MARK: - Voxa Typography
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - Typography Tokens                                   ║
// ║                                                                              ║
// ║ Typography Philosophy:                                                       ║
// ║ - Display fonts use SF Rounded for a friendly, approachable feel            ║
// ║ - Body text uses system font for optimal legibility                          ║
// ║ - Consistent type scale based on 4pt grid (11, 12, 14, 16, 20, 28)          ║
// ║ - Clear visual hierarchy through size and weight combinations                ║
// ║                                                                              ║
// ║ Font Selection Rationale:                                                    ║
// ║ SF Rounded was chosen for display text to create a distinctive, warm feel   ║
// ║ that complements the coral color palette while maintaining excellent         ║
// ║ readability on macOS. It's memorable without being gimmicky.                 ║
// ║                                                                              ║
// ║ Usage Guide:                                                                 ║
// ║ - largeTitle: Hero text, main window titles                                  ║
// ║ - title: Section headers, card titles                                        ║
// ║ - headline: Subsection headers, important labels                             ║
// ║ - body: Primary content text                                                 ║
// ║ - caption: Supporting text, metadata                                         ║
// ║ - small: Fine print, tertiary information                                    ║
// ║ - mono: Code snippets, technical values                                      ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

extension Font {
    /// Voxa design system fonts
    /// 
    /// Usage:
    /// ```swift
    /// Text("Hello World")
    ///     .font(Font.Voxa.headline)
    /// ```
    struct Voxa {
        // MARK: - Editorial Display Fonts (Serif) - US-801, US-808
        // These fonts use serif design for an editorial, elegant appearance
        // Inspired by Playfair Display - using system serif as fallback
        
        /// Display greeting font (52pt, regular, serif) - for time-based greetings
        /// Use for: Hero greeting text like "Good morning.", "Good afternoon."
        /// Design: Elegant serif similar to Playfair Display (~48-60pt)
        static var displayGreeting: Font {
            Font.system(size: 52, weight: .regular, design: .serif)
        }
        
        /// Display greeting italic (48pt, regular, serif, italic) - for italic greetings
        /// Use for: Italic section headers, editorial emphasis
        static var displayGreetingItalic: Font {
            Font.system(size: 48, weight: .regular, design: .serif).italic()
        }
        
        /// Section header italic (18pt, regular, serif, italic) - for section headers
        /// Use for: "Recent Transcriptions", "Daily Insights" section titles
        static var sectionHeaderItalic: Font {
            Font.system(size: 18, weight: .regular, design: .serif).italic()
        }
        
        /// Small uppercase label font (11pt, medium) - for labels like "DASHBOARD"
        /// Use for: Section labels with uppercase tracking-widest styling
        static let labelUppercase = Font.system(size: 11, weight: .medium)
        
        // MARK: - Display Fonts (SF Rounded)
        // These fonts use SF Rounded design for a distinctive, friendly appearance
        
        /// Large title (28pt, bold, rounded) - for main headers
        /// Use for: Hero text, main window titles, splash screens
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        
        /// Title (20pt, semibold, rounded) - for section headers
        /// Use for: Card titles, modal headers, prominent labels
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        /// Headline (16pt, semibold, rounded) - for subsection headers
        /// Use for: Group labels, form section titles, button labels
        static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
        
        // MARK: - Body Fonts (System Default)
        // These fonts use the system default for maximum legibility
        
        /// Body (14pt, regular) - for main content
        /// Use for: Primary paragraph text, descriptions, form fields
        static let body = Font.system(size: 14, weight: .regular)
        
        /// Body bold (14pt, semibold) - for emphasized body text
        /// Use for: Important inline text, labels that need emphasis
        static let bodyBold = Font.system(size: 14, weight: .semibold)
        
        /// Caption (12pt, medium) - for secondary text
        /// Use for: Supporting text, timestamps, metadata
        static let caption = Font.system(size: 12, weight: .medium)
        
        /// Small (11pt, regular) - for tertiary/fine print
        /// Use for: Legal text, footnotes, less important details
        static let small = Font.system(size: 11, weight: .regular)
        
        // MARK: - Monospace Fonts
        // For technical content and fixed-width display
        
        /// Monospace (13pt, regular, monospaced) - for code/technical
        /// Use for: Code snippets, file paths, technical values, hotkey display
        static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
        
        /// Monospace small (11pt, regular, monospaced) - for compact code
        /// Use for: Inline code, debug output, compact technical info
        static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}

// MARK: - NSFont Voxa Equivalents (for AppKit components)
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - NSFont Tokens (AppKit)                              ║
// ║                                                                              ║
// ║ These fonts mirror the SwiftUI Font.Voxa typography for AppKit usage.    ║
// ║ Use these when working with NSTextField, NSTextView, or other AppKit text.   ║
// ║                                                                              ║
// ║ Note: NSFont doesn't have a direct .rounded design option like SwiftUI Font. ║
// ║ For rounded fonts in AppKit, use the system font which adapts appropriately. ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

extension NSFont {
    /// Voxa design system fonts for AppKit
    struct Voxa {
        // MARK: - Display Fonts
        
        /// Large title (28pt, bold) - for main headers
        static let largeTitle = NSFont.systemFont(ofSize: 28, weight: .bold)
        
        /// Title (20pt, semibold) - for section headers
        static let title = NSFont.systemFont(ofSize: 20, weight: .semibold)
        
        /// Headline (16pt, semibold) - for subsection headers
        static let headline = NSFont.systemFont(ofSize: 16, weight: .semibold)
        
        // MARK: - Body Fonts
        
        /// Body (14pt, regular) - for main content
        static let body = NSFont.systemFont(ofSize: 14, weight: .regular)
        
        /// Body bold (14pt, semibold) - for emphasized body text
        static let bodyBold = NSFont.systemFont(ofSize: 14, weight: .semibold)
        
        /// Caption (12pt, medium) - for secondary text
        static let caption = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        /// Small (11pt, regular) - for tertiary/fine print
        static let small = NSFont.systemFont(ofSize: 11, weight: .regular)
        
        // MARK: - Monospace Fonts
        
        /// Monospace (13pt, regular) - for code/technical
        static let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        /// Monospace small (11pt, regular) - for compact code
        static let monoSmall = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    }
}

// MARK: - Spacing Constants
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - Spacing Tokens                                      ║
// ║                                                                              ║
// ║ Spacing Philosophy:                                                          ║
// ║ - 4pt base unit creates consistent visual rhythm                             ║
// ║ - All spacing values are multiples of 4pt for pixel-perfect alignment        ║
// ║ - Progressive scale: xs(4) → sm(8) → md(12) → lg(16) → xl(24) → xxl(32)     ║
// ║                                                                              ║
// ║ Usage Guide:                                                                 ║
// ║ - xs (4pt): Icon-text gaps, tight element clusters                           ║
// ║ - sm (8pt): Related element padding, list item spacing                       ║
// ║ - md (12pt): Default padding, input fields                                   ║
// ║ - lg (16pt): Card padding, section margins                                   ║
// ║ - xl (24pt): Section separation, major content breaks                        ║
// ║ - xxl (32pt): Page margins, hero sections                                    ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Voxa spacing constants for consistent layout
/// 
/// Usage:
/// ```swift
/// VStack(spacing: Spacing.md) {
///     Text("Hello")
///         .padding(Spacing.lg)
/// }
/// ```
enum Spacing {
    // MARK: - Base Unit
    /// The base spacing unit - all other spacing is a multiple of this
    static let unit: CGFloat = 4
    
    // MARK: - Spacing Scale
    
    /// Extra small spacing (4pt) - 1x base
    /// Use for: Icon-text gaps, tight element clusters
    static let xs: CGFloat = 4
    
    /// Small spacing (8pt) - 2x base
    /// Use for: Related element padding, list item spacing
    static let sm: CGFloat = 8
    
    /// Medium spacing (12pt) - 3x base
    /// Use for: Default padding, input fields
    static let md: CGFloat = 12
    
    /// Large spacing (16pt) - 4x base
    /// Use for: Card padding, section margins
    static let lg: CGFloat = 16
    
    /// Extra large spacing (24pt) - 6x base
    /// Use for: Section separation, major content breaks
    static let xl: CGFloat = 24
    
    /// Extra extra large spacing (32pt) - 8x base
    /// Use for: Page margins, hero sections
    static let xxl: CGFloat = 32
    
    /// Maximum spacing (48pt) - 12x base
    /// Use for: Large gaps, major section breaks
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius Constants
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - Corner Radius Tokens                                ║
// ║                                                                              ║
// ║ Corner Radius Philosophy: Soft & Organic                                     ║
// ║ - Rounded corners create a friendly, approachable aesthetic                  ║
// ║ - Consistent radii across similar component types                            ║
// ║ - Larger components use proportionally larger radii                          ║
// ║                                                                              ║
// ║ Design Decision: We chose soft/organic over sharp/brutalist because:         ║
// ║ - Complements the warm coral color palette                                   ║
// ║ - Creates a welcoming, non-intimidating UI for voice recording               ║
// ║ - Aligns with modern macOS design language                                   ║
// ║                                                                              ║
// ║ Usage Guide:                                                                 ║
// ║ - none (0pt): Sharp edges when needed (dividers, progress bars)              ║
// ║ - small (8pt): Buttons, badges, input fields, small interactive elements     ║
// ║ - medium (12pt): Cards, panels, sections, dropdown menus                     ║
// ║ - large (16pt): Modals, popovers, large floating elements                    ║
// ║ - extraLarge (22pt): Pills, floating action buttons, toast notifications     ║
// ║ - full: Fully rounded (circles, capsules)                                    ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Voxa corner radius constants
/// 
/// Usage:
/// ```swift
/// RoundedRectangle(cornerRadius: CornerRadius.medium)
/// .cornerRadius(CornerRadius.small)
/// ```
enum CornerRadius {
    /// No corner radius (0pt) - for sharp edges
    /// Use for: Dividers, progress bar backgrounds, full-bleed elements
    static let none: CGFloat = 0
    
    /// Small corner radius (8pt) - for buttons, badges
    /// Use for: Buttons, badges, input fields, small interactive elements
    static let small: CGFloat = 8
    
    /// Medium corner radius (12pt) - for cards, sections
    /// Use for: Cards, panels, sections, dropdown menus
    static let medium: CGFloat = 12
    
    /// Large corner radius (16pt) - for modals, large cards
    /// Use for: Modals, popovers, large floating elements
    static let large: CGFloat = 16
    
    /// Extra large corner radius (22pt) - for floating pills
    /// Use for: Pills, floating action buttons, toast notifications
    static let extraLarge: CGFloat = 22
    
    /// Capsule radius (half of height) - for fully rounded ends
    /// Use for: Pill buttons, capsule shapes - pass the height/2 for capsule effect
    /// Note: For true capsules, use Capsule() shape or .clipShape(Capsule())
    static func capsule(height: CGFloat) -> CGFloat {
        return height / 2
    }
}

// MARK: - Shadow Styles

/// Voxa shadow styles
enum ShadowStyle {
    /// Card shadow - soft, warm-toned for elevated content
    case card
    
    /// Floating shadow - more prominent for floating elements
    case floating
    
    /// Subtle shadow - very light for minimal elevation
    case subtle
    
    /// The shadow color (warm gray)
    var color: Color {
        switch self {
        case .card:
            return Color(hex: "2D3436").opacity(0.08)
        case .floating:
            return Color(hex: "2D3436").opacity(0.15)
        case .subtle:
            return Color(hex: "2D3436").opacity(0.04)
        }
    }
    
    /// The shadow radius
    var radius: CGFloat {
        switch self {
        case .card:
            return 8
        case .floating:
            return 16
        case .subtle:
            return 4
        }
    }
    
    /// The shadow X offset
    var x: CGFloat {
        return 0
    }
    
    /// The shadow Y offset
    var y: CGFloat {
        switch self {
        case .card:
            return 2
        case .floating:
            return 8
        case .subtle:
            return 1
        }
    }
}

// MARK: - Shadow View Modifier

extension View {
    /// Apply a Voxa shadow style to a view
    func voxaShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - Voxa Button Style

/// Custom button style for Voxa with press animation
struct VoxaButtonStyle: ButtonStyle {
    /// Button variant
    enum Variant {
        case primary    // Coral background, white text
        case secondary  // Light gray background, coral text
        case ghost      // Transparent background, coral text
    }
    
    let variant: Variant
    let isFullWidth: Bool
    
    init(variant: Variant = .primary, isFullWidth: Bool = false) {
        self.variant = variant
        self.isFullWidth = isFullWidth
    }
    
    func makeBody(configuration: Configuration) -> some View {
        VoxaButtonContent(
            configuration: configuration,
            variant: variant,
            isFullWidth: isFullWidth
        )
    }
    
    // Convenience static methods for easy access
    static var primary: VoxaButtonStyle {
        VoxaButtonStyle(variant: .primary)
    }
    
    static var secondary: VoxaButtonStyle {
        VoxaButtonStyle(variant: .secondary)
    }
    
    static var ghost: VoxaButtonStyle {
        VoxaButtonStyle(variant: .ghost)
    }
}

/// Internal view for button content with proper @State management
/// US-525: Added contentShape for reliable hit testing within ScrollViews
private struct VoxaButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let variant: VoxaButtonStyle.Variant
    let isFullWidth: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        configuration.label
            .font(Font.Voxa.body)
            .fontWeight(.medium)
            .foregroundColor(textColor(isPressed: configuration.isPressed))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle()) // US-525: Ensure entire button area is clickable
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            if isPressed {
                return Color.Voxa.accent.opacity(0.8)
            } else if isHovering {
                return Color.Voxa.accent.opacity(0.9)
            }
            return Color.Voxa.accent
            
        case .secondary:
            if isPressed {
                return Color.Voxa.border.opacity(0.8)
            } else if isHovering {
                return Color.Voxa.border
            }
            return Color.Voxa.border.opacity(0.5)
            
        case .ghost:
            if isPressed {
                return Color.Voxa.accent.opacity(0.15)
            } else if isHovering {
                return Color.Voxa.accent.opacity(0.08)
            }
            return Color.clear
        }
    }
    
    private func textColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return Color.Voxa.accent
        }
    }
}

// MARK: - Voxa Card Style (View Modifier)

/// Custom card style modifier for Voxa with soft shadow and rounded corners
/// US-525: Added contentShape for reliable hit testing within ScrollViews
struct VoxaCardStyle: ViewModifier {
    let padding: CGFloat
    let shadow: ShadowStyle
    
    init(padding: CGFloat = Spacing.lg, shadow: ShadowStyle = .card) {
        self.padding = padding
        self.shadow = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .contentShape(Rectangle()) // US-525: Ensure entire card area is tappable
            .voxaShadow(shadow)
    }
}

extension View {
    /// Apply Voxa card styling to a view
    func voxaCard(padding: CGFloat = Spacing.lg, shadow: ShadowStyle = .card) -> some View {
        self.modifier(VoxaCardStyle(padding: padding, shadow: shadow))
    }
}

// MARK: - Voxa Toggle Style

/// Custom toggle style with coral accent color
/// US-525: Enhanced hit area for reliable toggle interactions in ScrollViews
struct VoxaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            // Custom toggle capsule
            // US-525: Wrapped in a larger hit area for easier tapping
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.Voxa.accent : Color.Voxa.border)
                    .frame(width: 44, height: 24)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            }
            .frame(width: 52, height: 32) // US-525: Larger frame for hit testing
            .contentShape(Rectangle()) // US-525: Ensure entire area responds to taps
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
        .contentShape(Rectangle()) // US-525: Make entire row tappable
    }
}

// MARK: - Voxa Text Field Style

/// Custom text field style with warm styling and focus glow
struct VoxaTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(Font.Voxa.body)
            .foregroundColor(Color.Voxa.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )
    }
}

// MARK: - Animation Constants

/// Voxa animation presets
enum VoxaAnimation {
    /// Quick micro-interaction (0.1s)
    static let quick = Animation.easeOut(duration: 0.1)
    
    /// Standard transition (0.2s)
    static let standard = Animation.easeInOut(duration: 0.2)
    
    /// Smooth transition (0.3s)
    static let smooth = Animation.easeInOut(duration: 0.3)
    
    /// Spring animation for bouncy effects
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Slide animation for toast/panel entrances
    static let slide = Animation.spring(response: 0.4, dampingFraction: 0.8)
    
    /// Tab transition animation
    static let tabTransition = Animation.easeInOut(duration: 0.25)
}

// MARK: - Animated Success Checkmark

/// Animated success checkmark with draw-in animation
struct AnimatedCheckmark: View {
    @State private var isAnimating = false
    var size: CGFloat = 60
    var strokeWidth: CGFloat = 4
    var color: Color = Color.Voxa.success
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
                .scaleEffect(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isAnimating)
            
            // Checkmark path
            CheckmarkShape()
                .trim(from: 0, to: isAnimating ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.4, height: size * 0.4)
                .animation(.easeOut(duration: 0.35).delay(0.15), value: isAnimating)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            // Call completion after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete?()
            }
        }
    }
}

/// Custom checkmark shape for draw animation
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Start from bottom-left of check, go to bottom-center, then up to top-right
        path.move(to: CGPoint(x: width * 0.1, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.85))
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.15))
        
        return path
    }
}

// MARK: - Loading Spinner

/// Animated loading spinner with smooth rotation
struct LoadingSpinner: View {
    @State private var isAnimating = false
    var size: CGFloat = 24
    var lineWidth: CGFloat = 3
    var color: Color = Color.Voxa.accent
    
    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1.0)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Pulsing Dot

/// Pulsing dot indicator for recording or activity states
struct PulsingDot: View {
    @State private var isPulsing = false
    var size: CGFloat = 10
    var color: Color = Color.Voxa.accent
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.2 : 0.9)
            .opacity(isPulsing ? 1.0 : 0.7)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Interactive Scale Button Style

/// Button style with scale animation for any interactive element
struct InteractiveScaleStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95
    var animationDuration: Double = 0.1
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeOut(duration: animationDuration), value: configuration.isPressed)
    }
}

// MARK: - Hover Highlight Modifier

/// View modifier that adds hover highlighting effect
struct HoverHighlight: ViewModifier {
    @State private var isHovering = false
    var hoverColor: Color = Color.Voxa.accentLight
    var cornerRadius: CGFloat = CornerRadius.small
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovering ? hoverColor : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
}

extension View {
    /// Apply hover highlighting effect
    func hoverHighlight(color: Color = Color.Voxa.accentLight, cornerRadius: CGFloat = CornerRadius.small) -> some View {
        self.modifier(HoverHighlight(hoverColor: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Tab Content Transition

/// View modifier for smooth tab content transitions
struct TabContentTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                removal: .opacity.combined(with: .scale(scale: 1.02))
            ))
    }
}

extension View {
    /// Apply tab content transition animation
    func tabContentTransition() -> some View {
        self.modifier(TabContentTransition())
    }
}

// MARK: - Success Flash Overlay

/// Temporary success flash overlay for positive feedback
struct SuccessFlashOverlay: View {
    @Binding var isShowing: Bool
    var message: String = "Success!"
    var duration: TimeInterval = 1.5
    
    var body: some View {
        if isShowing {
            VStack(spacing: Spacing.md) {
                AnimatedCheckmark(size: 50)
                
                Text(message)
                    .font(Font.Voxa.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.Voxa.background.opacity(0.8))
            )
            .voxaShadow(.floating)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(VoxaAnimation.smooth) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Bounce Animation Modifier

/// View modifier that adds a subtle bounce effect on appear
struct BounceOnAppear: ViewModifier {
    @State private var hasAppeared = false
    var delay: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared ? 1.0 : 0.9)
            .opacity(hasAppeared ? 1.0 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    /// Apply bounce animation on appear
    func bounceOnAppear(delay: Double = 0) -> some View {
        self.modifier(BounceOnAppear(delay: delay))
    }
}
