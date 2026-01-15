import AppKit

// Create the application instance
let app = NSApplication.shared

// Set activation policy to accessory (no dock icon, no menu bar app menu)
// This is critical for a menu bar-only app
app.setActivationPolicy(.accessory)

// Create and set the delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the application
app.run()
