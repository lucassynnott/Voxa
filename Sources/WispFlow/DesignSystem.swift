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

// MARK: - Wispflow Color Palette

extension Color {
    /// Wispflow design system colors
    struct Wispflow {
        /// Warm ivory/cream background (#FEFCF8) - not harsh white
        static let background = Color(hex: "FEFCF8")
        
        /// Soft white surface (#FFFFFF)
        static let surface = Color.white
        
        /// Warm coral/terracotta accent (#E07A5F) - distinctive, not generic blue
        static let accent = Color(hex: "E07A5F")
        
        /// Muted sage green for success states (#81B29A)
        static let success = Color(hex: "81B29A")
        
        /// Warm charcoal text (#2D3436) - not pure black
        static let textPrimary = Color(hex: "2D3436")
        
        /// Warm gray secondary text (#636E72)
        static let textSecondary = Color(hex: "636E72")
        
        /// Very subtle warm gray border (#E8E4DF)
        static let border = Color(hex: "E8E4DF")
        
        /// Error state color - warm red
        static let error = Color(hex: "D64545")
        
        /// Warning state color - warm orange
        static let warning = Color(hex: "E09F3E")
        
        /// Accent color at lighter opacity for backgrounds
        static let accentLight = accent.opacity(0.15)
        
        /// Success color at lighter opacity for backgrounds
        static let successLight = success.opacity(0.15)
        
        /// Error color at lighter opacity for backgrounds
        static let errorLight = error.opacity(0.15)
    }
}

// MARK: - NSColor Wispflow Equivalents (for AppKit components)

extension NSColor {
    /// Wispflow design system colors for AppKit
    struct Wispflow {
        /// Warm ivory/cream background (#FEFCF8)
        static let background = NSColor(hex: "FEFCF8")
        
        /// Soft white surface
        static let surface = NSColor.white
        
        /// Warm coral/terracotta accent (#E07A5F)
        static let accent = NSColor(hex: "E07A5F")
        
        /// Muted sage green for success states (#81B29A)
        static let success = NSColor(hex: "81B29A")
        
        /// Warm charcoal text (#2D3436)
        static let textPrimary = NSColor(hex: "2D3436")
        
        /// Warm gray secondary text (#636E72)
        static let textSecondary = NSColor(hex: "636E72")
        
        /// Very subtle warm gray border (#E8E4DF)
        static let border = NSColor(hex: "E8E4DF")
        
        /// Error state color - warm red
        static let error = NSColor(hex: "D64545")
        
        /// Warning state color - warm orange
        static let warning = NSColor(hex: "E09F3E")
    }
}

// MARK: - Wispflow Typography

extension Font {
    /// Wispflow design system fonts
    struct Wispflow {
        /// Large title (28pt, bold, rounded) - for main headers
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        
        /// Title (20pt, semibold, rounded) - for section headers
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        /// Headline (16pt, semibold, rounded) - for subsection headers
        static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
        
        /// Body (14pt, regular) - for main content
        static let body = Font.system(size: 14, weight: .regular)
        
        /// Caption (12pt, medium) - for secondary text
        static let caption = Font.system(size: 12, weight: .medium)
        
        /// Small (11pt, regular) - for tertiary/fine print
        static let small = Font.system(size: 11, weight: .regular)
        
        /// Monospace (13pt, regular, monospaced) - for code/technical
        static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
}

// MARK: - NSFont Wispflow Equivalents (for AppKit components)

extension NSFont {
    /// Wispflow design system fonts for AppKit
    struct Wispflow {
        /// Large title (28pt, bold, rounded)
        static let largeTitle = NSFont.systemFont(ofSize: 28, weight: .bold)
        
        /// Title (20pt, semibold)
        static let title = NSFont.systemFont(ofSize: 20, weight: .semibold)
        
        /// Headline (16pt, semibold)
        static let headline = NSFont.systemFont(ofSize: 16, weight: .semibold)
        
        /// Body (14pt, regular)
        static let body = NSFont.systemFont(ofSize: 14, weight: .regular)
        
        /// Caption (12pt, medium)
        static let caption = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        /// Small (11pt, regular)
        static let small = NSFont.systemFont(ofSize: 11, weight: .regular)
        
        /// Monospace (13pt, regular)
        static let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }
}

// MARK: - Spacing Constants

/// Wispflow spacing constants for consistent layout
enum Spacing {
    /// Extra small spacing (4pt)
    static let xs: CGFloat = 4
    
    /// Small spacing (8pt)
    static let sm: CGFloat = 8
    
    /// Medium spacing (12pt)
    static let md: CGFloat = 12
    
    /// Large spacing (16pt)
    static let lg: CGFloat = 16
    
    /// Extra large spacing (24pt)
    static let xl: CGFloat = 24
    
    /// Extra extra large spacing (32pt)
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius Constants

/// Wispflow corner radius constants
enum CornerRadius {
    /// Small corner radius (8pt) - for buttons, badges
    static let small: CGFloat = 8
    
    /// Medium corner radius (12pt) - for cards, sections
    static let medium: CGFloat = 12
    
    /// Large corner radius (16pt) - for modals, large cards
    static let large: CGFloat = 16
    
    /// Extra large corner radius (22pt) - for floating pills
    static let extraLarge: CGFloat = 22
}

// MARK: - Shadow Styles

/// Wispflow shadow styles
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
    /// Apply a Wispflow shadow style to a view
    func wispflowShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - Wispflow Button Style

/// Custom button style for Wispflow with press animation
struct WispflowButtonStyle: ButtonStyle {
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
        WispflowButtonContent(
            configuration: configuration,
            variant: variant,
            isFullWidth: isFullWidth
        )
    }
    
    // Convenience static methods for easy access
    static var primary: WispflowButtonStyle {
        WispflowButtonStyle(variant: .primary)
    }
    
    static var secondary: WispflowButtonStyle {
        WispflowButtonStyle(variant: .secondary)
    }
    
    static var ghost: WispflowButtonStyle {
        WispflowButtonStyle(variant: .ghost)
    }
}

/// Internal view for button content with proper @State management
private struct WispflowButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let variant: WispflowButtonStyle.Variant
    let isFullWidth: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        configuration.label
            .font(Font.Wispflow.body)
            .fontWeight(.medium)
            .foregroundColor(textColor(isPressed: configuration.isPressed))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(CornerRadius.small)
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
                return Color.Wispflow.accent.opacity(0.8)
            } else if isHovering {
                return Color.Wispflow.accent.opacity(0.9)
            }
            return Color.Wispflow.accent
            
        case .secondary:
            if isPressed {
                return Color.Wispflow.border.opacity(0.8)
            } else if isHovering {
                return Color.Wispflow.border
            }
            return Color.Wispflow.border.opacity(0.5)
            
        case .ghost:
            if isPressed {
                return Color.Wispflow.accent.opacity(0.15)
            } else if isHovering {
                return Color.Wispflow.accent.opacity(0.08)
            }
            return Color.clear
        }
    }
    
    private func textColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return Color.Wispflow.accent
        }
    }
}

// MARK: - Wispflow Card Style (View Modifier)

/// Custom card style modifier for Wispflow with soft shadow and rounded corners
struct WispflowCardStyle: ViewModifier {
    let padding: CGFloat
    let shadow: ShadowStyle
    
    init(padding: CGFloat = Spacing.lg, shadow: ShadowStyle = .card) {
        self.padding = padding
        self.shadow = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            .wispflowShadow(shadow)
    }
}

extension View {
    /// Apply Wispflow card styling to a view
    func wispflowCard(padding: CGFloat = Spacing.lg, shadow: ShadowStyle = .card) -> some View {
        self.modifier(WispflowCardStyle(padding: padding, shadow: shadow))
    }
}

// MARK: - Wispflow Toggle Style

/// Custom toggle style with coral accent color
struct WispflowToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            // Custom toggle capsule
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.Wispflow.accent : Color.Wispflow.border)
                    .frame(width: 44, height: 24)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

// MARK: - Wispflow Text Field Style

/// Custom text field style with warm styling and focus glow
struct WispflowTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(Font.Wispflow.body)
            .foregroundColor(Color.Wispflow.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.Wispflow.border, lineWidth: 1)
            )
    }
}

// MARK: - Animation Constants

/// Wispflow animation presets
enum WispflowAnimation {
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
    var color: Color = Color.Wispflow.success
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
    var color: Color = Color.Wispflow.accent
    
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
    var color: Color = Color.Wispflow.accent
    
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
    var hoverColor: Color = Color.Wispflow.accentLight
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
    func hoverHighlight(color: Color = Color.Wispflow.accentLight, cornerRadius: CGFloat = CornerRadius.small) -> some View {
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
                    .font(Font.Wispflow.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.Wispflow.background.opacity(0.8))
            )
            .wispflowShadow(.floating)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(WispflowAnimation.smooth) {
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
