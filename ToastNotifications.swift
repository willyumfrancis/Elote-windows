import Cocoa
import SwiftUI

// A simple, reliable toast notification system
final class SimpleToastNotifier {
    // Singleton
    static let shared = SimpleToastNotifier()
    
    // Private initialization
    private init() {}
    
    // Show a simple toast message
    func show(message: String, duration: TimeInterval = 2.0) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.show(message: message, duration: duration)
            }
            return
        }
        
        // Get appropriate window to display on
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first else {
            NSLog("❌ Cannot show toast: No window available")
            return
        }
        
        // Create a simple visual effect backdrop
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 8
        
        // Create a simple text label
        let label = NSTextField(frame: NSRect(x: 50, y: 0, width: 230, height: 60))
        label.stringValue = message
        label.isEditable = false
        label.isBordered = false
        label.isBezeled = false
        label.drawsBackground = false
        label.textColor = .textColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        
        // Add an icon
        let icon = NSImageView(frame: NSRect(x: 15, y: 18, width: 24, height: 24))
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = .systemGreen
        
        // Add subviews
        visualEffect.addSubview(label)
        visualEffect.addSubview(icon)
        
        // Position the toast at the bottom right of the window
        let windowFrame = window.contentView?.frame ?? window.frame
        let x = windowFrame.width - 320
        let y = 40
        visualEffect.frame = NSRect(x: Int(x), y: y, width: 300, height: 60)
        
        // Add to window
        window.contentView?.addSubview(visualEffect)
        
        // Start with zero alpha
        visualEffect.alphaValue = 0
        
        // Animate in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            visualEffect.animator().alphaValue = 1.0
        }, completionHandler: {
            // Schedule removal
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                // Animate out
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    visualEffect.animator().alphaValue = 0
                }, completionHandler: {
                    // Remove from window
                    visualEffect.removeFromSuperview()
                })
            }
        })
    }
}

// Simple helper method to show a toast from your AppDelegate
func showSimpleToast(_ message: String, duration: TimeInterval = 2.0) {
    SimpleToastNotifier.shared.show(message: message, duration: duration)
}
