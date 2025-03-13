import SwiftUI
import Cocoa
import KeyboardShortcuts
import Network
import UserNotifications


// Define shortcut names
extension KeyboardShortcuts.Name {
    static let processText = Self("processText")
    static let toggleMonitoring = Self("toggleMonitoring")
}

@main
struct EloteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}



// Define API provider enum
// Update the LLMProvider enum

// Create a struct for storing prompts
struct Prompt: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var text: String
    
    init(id: UUID = UUID(), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
    
    static func == (lhs: Prompt, rhs: Prompt) -> Bool {
        return lhs.id == rhs.id
    }
}

// Complete implementation of the LLMProvider enum
enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    
    var id: String { self.rawValue }
    
    var apiEndpoint: String {
        switch self {
        case .openAI:
            // Chat Completion endpoint for OpenAI
            return "https://api.openai.com/v1/chat/completions"
        case .anthropic:
            // Updated endpoint for Anthropic (Messages API)
            return "https://api.anthropic.com/v1/messages"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o"
        case .anthropic:
            return "claude-3-haiku-20240307" // Updated to Claude 3 model
        }
    }
    
    func headers(apiKey: String) -> [String: String] {
        switch self {
        case .openAI:
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey)"
            ]
        case .anthropic:
            return [
                "Content-Type": "application/json",
                // Updated version
                "anthropic-version": "2023-06-01",
                // Anthropic uses x-api-key instead of Bearer
                "x-api-key": apiKey
            ]
        }
    }
    
    /// Builds the request body for each provider.
    func requestBody(prompt: String, userText: String, model: String?) -> [String: Any] {
        var modelToUse = model ?? defaultModel
        
        // Basic fallback for typical naming issues
        switch self {
        case .openAI:
            if modelToUse.lowercased() == "gpt4" || modelToUse.lowercased() == "gpt-4o" {
                modelToUse = "gpt-4o"
            } else if modelToUse.lowercased().contains("gpt3.5") {
                modelToUse = "gpt-3.5-turbo"
            }
        case .anthropic:
            // Example fallback: handle common "claude" naming patterns
            if modelToUse.lowercased().contains("claude-2") {
                modelToUse = "claude-2"
            } else if modelToUse.lowercased().contains("1.3") {
                modelToUse = "claude-1.3"
            } else if modelToUse.lowercased().contains("3") && !modelToUse.contains("-") {
                modelToUse = "claude-3-haiku-20240307"
            }
        }
        
        switch self {
        case .openAI:
            // Uses Chat Completions format
            return [
                "model": modelToUse,
                "messages": [
                    ["role": "user", "content": "\(prompt) \(userText)"]
                ],
                "max_tokens": 4000,
                "temperature": 0.7
            ]
            
        case .anthropic:
            // Uses the Anthropic Messages API format (updated)
            return [
                "model": modelToUse,
                "messages": [
                    ["role": "user", "content": "\(prompt) \(userText)"]
                ],
                "max_tokens": 4000,
                "temperature": 0.7
            ]
        }
    }
    
    // Extract response function
    func extractResponse(from data: Data) -> Result<String, Error> {
        do {
            if let rawString = String(data: data, encoding: .utf8) {
                print("Parsing response from \(self.rawValue)...")
                print("Raw response snippet: \(rawString.prefix(200))...")
            }
            
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            switch self {
            case .openAI:
                if let choices = json?["choices"] as? [[String: Any]],
                   let firstChoice = choices.first {
                    
                    // Check Chat Completion format
                    if let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        return .success(content)
                    }
                    
                    // Fallback to older text completion
                    if let text = firstChoice["text"] as? String {
                        return .success(text)
                    }
                }
                
            case .anthropic:
                // For messages API response format
                if let content = json?["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    return .success(text)
                }
                
                // Fallback for older completion API
                if let completion = json?["completion"] as? String {
                    return .success(completion)
                }
            }
            
            // If there's an explicit "error" block, return it
            if let errorInfo = json?["error"] as? [String: Any] {
                var errorMessage = "API Error"
                
                if let message = errorInfo["message"] as? String {
                    errorMessage = message
                } else if let msg = errorInfo["msg"] as? String {
                    errorMessage = msg
                } else if let errType = errorInfo["type"] as? String {
                    errorMessage = "Error type: \(errType)"
                }
                
                return .failure(NSError(domain: "LLMProvider", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "API Error: \(errorMessage)"
                ]))
            }
            
            // Otherwise return the raw JSON so you can see what's going on
            if let rawString = String(data: data, encoding: .utf8) {
                if rawString.contains("error") {
                    return .failure(NSError(domain: "LLMProvider", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "API Error: \(rawString)"
                    ]))
                } else {
                    return .success("Raw API response: \(rawString)")
                }
            }
            
            return .failure(NSError(domain: "LLMProvider", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse API response"
            ]))
            
        } catch {
            return .failure(error)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("selectedProvider") var selectedProviderRaw: String = LLMProvider.openAI.rawValue
    @AppStorage("customModel") var customModel: String = ""
    @AppStorage("playNotificationSounds") var playNotificationSounds: Bool = true
    @AppStorage("showNotifications") var showNotifications: Bool = true
    
    // Multiple prompts support
    @AppStorage("promptsData") private var promptsData: Data = Data()
    @AppStorage("selectedPromptId") private var selectedPromptId: String = ""
    private var prompts: [Prompt] = []
    
    var lastOperationSucceeded: Bool = false
    var clipboardMonitor: Timer?
    var lastChangeCount: Int = 0
    var isAutoProcessing: Bool = false
    // Add this property to AppDelegate
    var networkMonitor: NWPathMonitor?
    var isNetworkAvailable: Bool = true
    // Add this property for visual processing feedback
    var processingTimer: Timer?
    @AppStorage("isAutoModeEnabled") var isAutoModeEnabled: Bool = false
    @AppStorage("lastUsedPrompt") var lastUsedPrompt: String = "Improve the following text while maintaining its original meaning."
    // Computed property to get the currently selected provider
    var selectedProvider: LLMProvider {
        if let provider = LLMProvider(rawValue: selectedProviderRaw) {
            return provider
        }
        return .openAI // Default to OpenAI if invalid
    }
    
    // Within your AppDelegate class, add this property to store the SVG data:
    let eloteIconSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <g fill="currentColor">
        <!-- Corn cob body with a rounded, more natural shape -->
        <path d="M32 8c-6 0-11 8-11 24s5 24 11 24 11-8 11-24S38 8 32 8z"/>
        
        <!-- Kernel details -->
        <circle cx="26" cy="18" r="2.5"/>
        <circle cx="32" cy="15" r="2.5"/>
        <circle cx="38" cy="18" r="2.5"/>
        
        <circle cx="26" cy="26" r="2.5"/>
        <circle cx="32" cy="23" r="2.5"/>
        <circle cx="38" cy="26" r="2.5"/>
        
        <circle cx="26" cy="34" r="2.5"/>
        <circle cx="32" cy="31" r="2.5"/>
        <circle cx="38" cy="34" r="2.5"/>
        
        <circle cx="26" cy="42" r="2.5"/>
        <circle cx="32" cy="39" r="2.5"/>
        <circle cx="38" cy="42" r="2.5"/>
        
        <!-- Husk leaves with better curvature -->
        <path d="M22 18c-6-2-12 2-16 6 6 2 12 2 16-6z"/>
        <path d="M42 18c6-2 12 2 16 6-6 2-12 2-16-6z"/>
      </g>
    </svg>
    """

    // Optional: Add a colored version for use in the settings view, keeping the original colors
    let eloteColoredIconSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <g>
        <!-- Corn cob body with a rounded, more natural shape -->
        <path d="M32 8c-6 0-11 8-11 24s5 24 11 24 11-8 11-24S38 8 32 8z" fill="gold" stroke="darkorange" stroke-width="2"/>
        
        <!-- Kernel details -->
        <circle cx="26" cy="18" r="2.5" fill="yellow"/>
        <circle cx="32" cy="15" r="2.5" fill="yellow"/>
        <circle cx="38" cy="18" r="2.5" fill="yellow"/>
        
        <circle cx="26" cy="26" r="2.5" fill="yellow"/>
        <circle cx="32" cy="23" r="2.5" fill="yellow"/>
        <circle cx="38" cy="26" r="2.5" fill="yellow"/>
        
        <circle cx="26" cy="34" r="2.5" fill="yellow"/>
        <circle cx="32" cy="31" r="2.5" fill="yellow"/>
        <circle cx="38" cy="34" r="2.5" fill="yellow"/>
        
        <circle cx="26" cy="42" r="2.5" fill="yellow"/>
        <circle cx="32" cy="39" r="2.5" fill="yellow"/>
        <circle cx="38" cy="42" r="2.5" fill="yellow"/>
        
        <!-- Husk leaves with better curvature -->
        <path d="M22 18c-6-2-12 2-16 6 6 2 12 2 16-6z" fill="green" stroke="darkgreen" stroke-width="2"/>
        <path d="M42 18c6-2 12 2 16 6-6 2-12 2-16-6z" fill="green" stroke="darkgreen" stroke-width="2"/>
      </g>
    </svg>
    """
    
    // Clipboard text storage
    var capturedText: String = ""
    
//    // Add this function to AppDelegate
//    func setupNetworkMonitoring() {
//        networkMonitor = NWPathMonitor()
//        
//        networkMonitor?.pathUpdateHandler = { [weak self] path in
//            DispatchQueue.main.async {
//                self?.isNetworkAvailable = path.status == .satisfied
//                
//                if path.status != .satisfied {
//                    print("Network unavailable")
//                    self?.showNotification(title: "Network Unavailable",
//                                         message: "Please check your internet connection")
//                } else {
//                    print("Network is available via: \(path.availableInterfaces.map { $0.name }.joined(separator: ", "))")
//                    // If network was previously down, we could notify it's back
//                }
//            }
//        }
//        
//        let queue = DispatchQueue(label: "NetworkMonitor")
//        networkMonitor?.start(queue: queue)
//    }
    
    let eloteYellowIconSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <g>
        <!-- Corn cob body with a rounded, more natural shape -->
        <path d="M32 8c-6 0-11 8-11 24s5 24 11 24 11-8 11-24S38 8 32 8z" fill="#FFD700" stroke="#FFA500" stroke-width="2"/>
        
        <!-- Kernel details -->
        <circle cx="26" cy="18" r="2.5" fill="#FFFF00"/>
        <circle cx="32" cy="15" r="2.5" fill="#FFFF00"/>
        <circle cx="38" cy="18" r="2.5" fill="#FFFF00"/>
        
        <circle cx="26" cy="26" r="2.5" fill="#FFFF00"/>
        <circle cx="32" cy="23" r="2.5" fill="#FFFF00"/>
        <circle cx="38" cy="26" r="2.5" fill="#FFFF00"/>
        
        <circle cx="26" cy="34" r="2.5" fill="#FFFF00"/>
        <circle cx="32" cy="31" r="2.5" fill="#FFFF00"/>
        <circle cx="38" cy="34" r="2.5" fill="#FFFF00"/>
        
        <circle cx="26" cy="42" r="2.5" fill="#FFFF00"/>
        <circle cx="32" cy="39" r="2.5" fill="#FFFF00"/>
        <circle cx="38" cy="42" r="2.5" fill="#FFFF00"/>
        
        <!-- Husk leaves with better curvature -->
        <path d="M22 18c-6-2-12 2-16 6 6 2 12 2 16-6z" fill="#8FBC8F" stroke="#006400" stroke-width="2"/>
        <path d="M42 18c6-2 12 2 16 6-6 2-12 2-16-6z" fill="#8FBC8F" stroke="#006400" stroke-width="2"/>
      </g>
    </svg>
    """

    // Green icon for ready-to-paste state
    let eloteGreenIconSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <g>
        <!-- Corn cob body with a rounded, more natural shape -->
        <path d="M32 8c-6 0-11 8-11 24s5 24 11 24 11-8 11-24S38 8 32 8z" fill="#32CD32" stroke="#006400" stroke-width="2"/>
        
        <!-- Kernel details -->
        <circle cx="26" cy="18" r="2.5" fill="#7CFC00"/>
        <circle cx="32" cy="15" r="2.5" fill="#7CFC00"/>
        <circle cx="38" cy="18" r="2.5" fill="#7CFC00"/>
        
        <circle cx="26" cy="26" r="2.5" fill="#7CFC00"/>
        <circle cx="32" cy="23" r="2.5" fill="#7CFC00"/>
        <circle cx="38" cy="26" r="2.5" fill="#7CFC00"/>
        
        <circle cx="26" cy="34" r="2.5" fill="#7CFC00"/>
        <circle cx="32" cy="31" r="2.5" fill="#7CFC00"/>
        <circle cx="38" cy="34" r="2.5" fill="#7CFC00"/>
        
        <circle cx="26" cy="42" r="2.5" fill="#7CFC00"/>
        <circle cx="32" cy="39" r="2.5" fill="#7CFC00"/>
        <circle cx="38" cy="42" r="2.5" fill="#7CFC00"/>
        
        <!-- Husk leaves with better curvature -->
        <path d="M22 18c-6-2-12 2-16 6 6 2 12 2 16-6z" fill="#008000" stroke="#006400" stroke-width="2"/>
        <path d="M42 18c6-2 12 2 16 6-6 2-12 2-16-6z" fill="#008000" stroke="#006400" stroke-width="2"/>
      </g>
    </svg>
    """

    
    // Update your applicationDidFinishLaunching method:
    func applicationDidFinishLaunching(_ notification: Notification) {
//        setupNetworkMonitoring()
        setupNotifications()  // Add this line
        NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") ?? NSImage(named: "elote_icon")

        // Load prompts from storage
        loadPrompts()
        
        // If no prompts exist, create a default one
        if prompts.isEmpty {
            let defaultPrompt = Prompt(name: "Default", text: lastUsedPrompt)
            prompts.append(defaultPrompt)
            selectedPromptId = defaultPrompt.id.uuidString
            savePrompts()
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Create the elote icon from SVG - using a smaller size for menu bar
            if let eloteImage = NSImage.fromSVG(eloteIconSVG, size: NSSize(width: 18, height: 18)) {
                button.image = eloteImage
                print("✅ Successfully loaded elote icon")
            } else {
                // Fallback to system symbol if SVG fails
                button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Elote")
                print("❌ Failed to load elote icon")
            }
            updateStatusItemAppearance()
        }
        
        setupMenus()
        registerShortcuts()
        
        // Initialize clipboard change count
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Start monitoring if auto mode is enabled
        if isAutoModeEnabled {
            startClipboardMonitoring()
        }
    }
    
    func getFormattedPrompt() -> String {
        return """
        \(prompts.first(where: { $0.id.uuidString == selectedPromptId })?.text ?? lastUsedPrompt)

        CRITICAL INSTRUCTION: You MUST ONLY return the enhanced version of the text. 
        DO NOT include ANY explanations, introductions, commentary, responses to the user, greetings, farewells, or quotation marks.
        DO NOT acknowledge or respond to the user in ANY way.
        If you cannot process the text, simply return the original text unchanged.
        """
    }

    @MainActor
    func updateStatusItemAppearance() {
        if let button = statusItem.button {
            if isAutoProcessing {
                // Use explicit yellow corn icon for processing
                if let yellowIcon = NSImage.fromSVG(eloteYellowIconSVG, size: NSSize(width: 18, height: 18)) {
                    yellowIcon.isTemplate = false // IMPORTANT: Don't let system override our colors
                    button.image = yellowIcon
                }
                
                // Start a timer to create a pulsing effect
                if processingTimer == nil {
                    processingTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                        DispatchQueue.main.async {
                            if let button = self?.statusItem.button {
                                // Toggle opacity for pulsing effect
                                button.alphaValue = button.alphaValue == 1.0 ? 0.5 : 1.0
                            }
                        }
                    }
                }
            } else if lastOperationSucceeded {
                // Use explicit green icon for success
                if let greenIcon = NSImage.fromSVG(eloteGreenIconSVG, size: NSSize(width: 18, height: 18)) {
                    greenIcon.isTemplate = false // IMPORTANT: Don't let system override our colors
                    button.image = greenIcon
                }
                button.alphaValue = 1.0
                stopProcessingAnimation()
                
                // Reset success indicator after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.lastOperationSucceeded = false
                    self?.updateStatusItemAppearance()
                }
            } else {
                // Default appearance
                if let defaultIcon = NSImage.fromSVG(eloteIconSVG, size: NSSize(width: 18, height: 18)) {
                    defaultIcon.isTemplate = true // Allow system to theme it in normal state
                    button.image = defaultIcon
                }
                button.contentTintColor = isAutoModeEnabled ? NSColor.systemBlue : nil
                button.alphaValue = 1.0
                stopProcessingAnimation()
            }
        }
    }

    
    // Add this method to your AppDelegate class
    // Enhanced showToast method with elote icon
    func showToast(message: String, duration: TimeInterval = 2.0) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.showToast(message: message, duration: duration)
            }
            return
        }
        
        // Log the toast message regardless of UI display
        print("TOAST: \(message)")
        
        // Get the main application window to show the toast on
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else {
            return
        }
        
        // Create the container view with visual effect background
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        
        // Create a label for the message
        let label = NSTextField(frame: NSRect(x: 54, y: 0, width: 230, height: 60))
        label.stringValue = message
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.textColor = NSColor.textColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        
        // Create an icon view
        let iconView = NSImageView(frame: NSRect(x: 16, y: 18, width: 24, height: 24))
        
        // Use the elote icon from SVG
        if let eloteImage = NSImage.fromSVG(eloteIconSVG, size: NSSize(width: 24, height: 24)) {
            iconView.image = eloteImage
            if #available(macOS 11.0, *) {
                // Use system accent color on newer macOS
                iconView.contentTintColor = NSColor.controlAccentColor
            } else {
                // Use a fixed color on older macOS
                iconView.contentTintColor = NSColor.systemBlue
            }
        } else {
            // Fallback to system symbol if SVG fails
            iconView.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Elote")
            iconView.contentTintColor = NSColor.systemGreen
        }
        
        // Add subviews to container
        container.addSubview(label)
        container.addSubview(iconView)
        
        // Position at the bottom of the window
        let windowFrame = window.contentView?.frame ?? window.frame
        container.frame = NSRect(
            x: (windowFrame.width - 300) / 2,
            y: 40,
            width: 300,
            height: 60
        )
        
        // Add to window
        window.contentView?.addSubview(container)
        
        // Animate in
        container.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            container.animator().alphaValue = 1.0
        }, completionHandler: {
            // Schedule removal
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    container.animator().alphaValue = 0
                }, completionHandler: {
                    container.removeFromSuperview()
                })
            }
        })
    }
    
    @MainActor
    func setupNotifications() {
        // Request authorization for notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
                
                // Register for notifications
                DispatchQueue.main.async {
                    NSApplication.shared.registerForRemoteNotifications()
                }
                
                // Register a simple notification category
                let category = UNNotificationCategory(
                    identifier: "misiaszek.elote",
                    actions: [],
                    intentIdentifiers: [],
                    options: .customDismissAction
                )
                
                UNUserNotificationCenter.current().setNotificationCategories([category])
                
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }
    }

    

    // Method to stop processing animation
    func stopProcessingAnimation() {
        processingTimer?.invalidate()
        processingTimer = nil
    }

    
    @MainActor func setupMenus() {
        let menu = NSMenu()
        
        // Process Text option
        menu.addItem(NSMenuItem(title: "Process Clipboard (\(KeyboardShortcuts.getShortcut(for: .processText)?.description ?? "Not Set"))",
                               action: #selector(processClipboardText),
                               keyEquivalent: ""))
        
        // // Auto Monitoring toggle
        // let autoModeItem = NSMenuItem(title: isAutoModeEnabled ? "Disable Auto Mode" : "Enable Auto Mode",
        //                        action: #selector(toggleAutoMode),
        //                        keyEquivalent: "")
        // menu.addItem(autoModeItem)
        
        // Settings submenu
        let settingsMenu = NSMenu()
        
        // Provider selection submenu
        let providerMenu = NSMenu()
        for provider in LLMProvider.allCases {
            let item = NSMenuItem(title: provider.rawValue, action: #selector(selectProvider(_:)), keyEquivalent: "")
            item.representedObject = provider.rawValue
            item.state = provider.rawValue == selectedProviderRaw ? .on : .off
            providerMenu.addItem(item)
        }
        
        let providerItem = NSMenuItem(title: "LLM Provider", action: nil, keyEquivalent: "")
        providerItem.submenu = providerMenu
        settingsMenu.addItem(providerItem)
        
        // Model selection
        settingsMenu.addItem(NSMenuItem(title: "Set Custom Model", action: #selector(setCustomModel), keyEquivalent: ""))
        
        // API Key
        settingsMenu.addItem(NSMenuItem(title: "Set API Key", action: #selector(setAPIKey), keyEquivalent: ""))
        
        // Prompt management submenu
        let promptsMenu = NSMenu()
        
        // Add "Manage Prompts" option
        promptsMenu.addItem(NSMenuItem(title: "Create New Prompt", action: #selector(createPrompt), keyEquivalent: ""))
        promptsMenu.addItem(NSMenuItem(title: "Edit Selected Prompt", action: #selector(editSelectedPrompt), keyEquivalent: ""))
        promptsMenu.addItem(NSMenuItem(title: "Delete Selected Prompt", action: #selector(deleteSelectedPrompt), keyEquivalent: ""))
        
        // Add separator before prompts list
        promptsMenu.addItem(NSMenuItem.separator())
        
        // Add all available prompts
        for prompt in prompts {
            let item = NSMenuItem(title: prompt.name, action: #selector(selectPrompt(_:)), keyEquivalent: "")
            item.representedObject = prompt.id.uuidString
            item.state = prompt.id.uuidString == selectedPromptId ? .on : .off
            promptsMenu.addItem(item)
        }
        
        let promptsItem = NSMenuItem(title: "Processing Prompts", action: nil, keyEquivalent: "")
        promptsItem.submenu = promptsMenu
        settingsMenu.addItem(promptsItem)
        
        // Add settings to main menu
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)
        
        // Add notification settings directly to the main menu
        let notificationItem = NSMenuItem(title: "Notification Settings", action: nil, keyEquivalent: "")
        let notificationMenu = NSMenu()
        
        // Show Notifications toggle
        let showNotificationsItem = NSMenuItem(title: "Show Notifications", action: #selector(toggleShowNotifications), keyEquivalent: "")
        showNotificationsItem.state = showNotifications ? .on : .off
        notificationMenu.addItem(showNotificationsItem)
        
        // Play Sounds toggle
        let playSoundItem = NSMenuItem(title: "Play Notification Sounds", action: #selector(toggleNotificationSounds), keyEquivalent: "")
        playSoundItem.state = playNotificationSounds ? .on : .off
        notificationMenu.addItem(playSoundItem)
        
        notificationItem.submenu = notificationMenu
        menu.addItem(notificationItem)
        
        // Shortcuts
        menu.addItem(NSMenuItem(title: "Set Keyboard Shortcuts", action: #selector(setShortcuts), keyEquivalent: ""))
        
        // About & Quit
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Elote", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }

    // Add these methods to toggle notification settings
    @MainActor @objc func toggleShowNotifications() {
        showNotifications.toggle()
        setupMenus() // Refresh menu to update checkmarks
    }

    @MainActor @objc func toggleNotificationSounds() {
        playNotificationSounds.toggle()
        setupMenus() // Refresh menu to update checkmarks
    }
    
    @objc func selectProvider(_ sender: NSMenuItem) {
        if let providerName = sender.representedObject as? String {
            selectedProviderRaw = providerName
            Task { @MainActor in
                setupMenus() // Update menus to show selected provider
                showNotification(title: "LLM Provider Changed", message: "Now using \(providerName)")
            }
        }
    }
    
    @MainActor
    @objc func setCustomModel() {
        let alert = NSAlert()
        alert.messageText = "Set Custom Model"
        alert.informativeText = "Enter the model identifier for \(selectedProvider.rawValue) (leave empty for default)"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = customModel
        textField.placeholderString = selectedProvider.defaultModel
        
        alert.accessoryView = textField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            customModel = textField.stringValue
        }
    }
    
    func registerShortcuts() {
        // Process clipboard shortcut
        KeyboardShortcuts.onKeyDown(for: .processText) { [weak self] in
            // Ensure we run on the main thread
            DispatchQueue.main.async {
                self?.processClipboardText()
            }
        }
        
        // Toggle monitoring shortcut
        KeyboardShortcuts.onKeyDown(for: .toggleMonitoring) { [weak self] in
            // Ensure we run on the main thread
            DispatchQueue.main.async {
                self?.toggleAutoMode()
            }
        }
    }
    
    @MainActor
    @objc func toggleAutoMode() {
        isAutoModeEnabled.toggle()
        
        if isAutoModeEnabled {
            startClipboardMonitoring()
            showNotification(title: "Elote Auto Mode Enabled", message: "Elote will now monitor your clipboard for text to process.")
        } else {
            stopClipboardMonitoring()
            showNotification(title: "Elote Auto Mode Disabled", message: "Clipboard monitoring has been turned off.")
        }
        
        updateStatusItemAppearance()
        setupMenus()
    }
    
    func startClipboardMonitoring() {
        stopClipboardMonitoring() // Ensure any existing timer is invalidated
        
        clipboardMonitor = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        
        print("Clipboard monitoring started")
    }
    
    
    func stopClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        clipboardMonitor = nil
        print("Clipboard monitoring stopped")
    }
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Only process if clipboard has changed
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                // Store the text but don't process automatically
                capturedText = text
                print("Clipboard changed: \(text.prefix(30))...")
                
                // Show a notification that text is ready to process
                if isAutoModeEnabled && !isAutoProcessing {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.showNotification(
                            title: "Text Captured",
                            message: "Press \(KeyboardShortcuts.getShortcut(for: .processText)?.description ?? "the process shortcut") to enhance this text."
                        )
                    }
                }
            }
        }
    }
    
    
    @MainActor
    @objc func processClipboardText() {
        // First check network status
        if !isNetworkAvailable {
            showAlert(title: "Network Unavailable",
                     message: "Please check your internet connection and try again.")
            return
        }
        
        // Check if API key is set
        if apiKey.isEmpty {
            showAlert(title: "API Key Missing", message: "Please set your API key in the app menu.")
            return
        }
        
        // Get text from clipboard if we don't already have captured text
        let pasteboard = NSPasteboard.general
        let textToProcess: String
        
        if !capturedText.isEmpty {
            textToProcess = capturedText
        } else if let clipboardText = pasteboard.string(forType: .string), !clipboardText.isEmpty {
            textToProcess = clipboardText
            capturedText = clipboardText // Store for potential reuse
        } else {
            showAlert(title: "No Text Available", message: "Copy text to your clipboard first, then try again.")
            return
        }
        
        print("Processing with \(selectedProvider.rawValue): \(textToProcess.prefix(30))...")
        isAutoProcessing = true
        updateStatusItemAppearance() // Update appearance to show processing
        
        // SAFETY: Store a reference to the original menu item title if available
        var originalTitle = "Process Clipboard"
        if let menuItem = statusItem.menu?.item(at: 0) {
            originalTitle = menuItem.title
            menuItem.title = "Processing..."
        }
        
        // Show processing notification and toast
        showNotification(title: "Processing Text", message: "Elote is enhancing your text with \(selectedProvider.rawValue)...")
        showToast(message: "Processing text with \(selectedProvider.rawValue)...", duration: 2.0)
        
        // Process with LLM
        processWithLLM(text: textToProcess) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAutoProcessing = false
                
                // SAFETY: Only try to update menu if it exists
                if let menuItem = self.statusItem.menu?.item(at: 0) {
                    menuItem.title = originalTitle
                }
                
                switch result {
                case .success(let processedText):
                    print("API returned \(processedText.count) characters")
                    
                    // Set success flag
                    self.lastOperationSucceeded = true
                    
                                        
                    // Put processed text on clipboard directly
                      pasteboard.clearContents()
                      pasteboard.setString(processedText, forType: .string)
                    
                    // Update lastChangeCount to prevent reprocessing
                    self.lastChangeCount = pasteboard.changeCount
                    
                    // Clear the captured text since we've processed it
                    self.capturedText = ""
                    
                    // Show notification and toast
                    self.showNotification(
                        title: "Text Enhanced",
                        message: "Enhanced text is now on your clipboard. Use Cmd+V to paste it."
                    )
                    self.showToast(message: "✅ Text enhanced! Ready to paste.", duration: 2.0)
                    
                    // Play a sound to indicate completion if sounds are enabled
                    if self.playNotificationSounds {
                        NSSound.beep()
                    }
                    
                case .failure(let error):
                    // Make sure success flag is false
                    self.lastOperationSucceeded = false
                    
                    print("API ERROR: \(error.localizedDescription)")
                    self.showAlert(title: "API Error", message: error.localizedDescription)
                    self.showToast(message: "❌ Error processing text", duration: 2.0)
                }
                
                // Update UI to reflect new state
                self.updateStatusItemAppearance()
            }
        
        }
    }

   
    
    // Update this function in your AppDelegate to get more detailed error information:

    func processWithLLM(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let provider = selectedProvider
        
        // Get the currently selected prompt text
        let promptText = getFormattedPrompt()
        
        // --- NEW: Ensure we actually have an API key stored in `apiKey`.
        if apiKey.isEmpty {
            print("ERROR: No API Key is set. Please set your API key via the menu.")
            completion(.failure(NSError(
                domain: "EloteApp",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing API Key. Please set your key in the menu."]
            )))
            return
        }
        
        // For safety, only show the first 8 characters in logs.
        let partialKey = apiKey.prefix(8)
//        print("DEBUG: Using stored API key (first 8 chars): \(partialKey)... [REDACTED]")

        // Get provider-specific details
        let endpoint = provider.apiEndpoint
        let headers = provider.headers(apiKey: apiKey)
        let modelToUse = customModel.isEmpty ? nil : customModel
        // To this:
            let requestBody = provider.requestBody(prompt: promptText, userText: text, model: modelToUse)
        // Print request info for debugging
//        print("API Request:")
//        print("- Provider: \(provider.rawValue)")
//        print("- Endpoint: \(endpoint)")
//        print("- Model: \(modelToUse ?? provider.defaultModel)")
        // NEW: Print actual header values (excluding the full key):
        headers.forEach { print("- Header: \($0.key) = \($0.value)") }
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "EloteApp", code: 100, userInfo: [
                NSLocalizedDescriptionKey: "Invalid API endpoint URL"
            ])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add request body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Print request body for debugging (sanitize the API key if it appears)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let sanitized = jsonString.replacingOccurrences(of: apiKey, with: "[API_KEY]")
                print("- Request Body: \(sanitized)")
            }
        } catch {
            print("Error creating request body: \(error)")
            completion(.failure(error))
            return
        }
        
        // Set a 60s timeout
        request.timeoutInterval = 60
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Network error handling
            if let error = error {
                let nsError = error as NSError
                let errorMessage: String
                
                // Provide more helpful messages for common network error codes
                switch nsError.code {
                case NSURLErrorCannotFindHost:
                    errorMessage = "Cannot connect to \(provider.rawValue) API server. Please check your internet connection and try again."
                case NSURLErrorTimedOut:
                    errorMessage = "Request timed out. The server is taking too long to respond."
                case NSURLErrorNetworkConnectionLost:
                    errorMessage = "Network connection was lost. Please try again."
                case NSURLErrorNotConnectedToInternet:
                    errorMessage = "No internet connection available. Please check your network settings."
                default:
                    errorMessage = error.localizedDescription
                }
                
                print("API Error: \(errorMessage) (Code: \(nsError.code))")
                completion(.failure(NSError(
                    domain: nsError.domain,
                    code: nsError.code,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )))
                return
            }
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("API Response Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    var errorMessage = "API server error (Status \(httpResponse.statusCode))"
                    
                    // Provide more context for common HTTP errors
                    switch httpResponse.statusCode {
                    case 401:
                        errorMessage = "Authentication failed: Please check your API key."
                    case 403:
                        errorMessage = "Access denied: You may not have permission to use this model or API."
                    case 404:
                        errorMessage = "API endpoint not found. The service may have changed."
                    case 429:
                        errorMessage = "Rate limit exceeded. Please try again later."
                    case 500, 502, 503, 504:
                        errorMessage = "API server error. The service may be experiencing issues."
                    default:
                        break
                    }
                    
                    // Try to extract error details from response if available
                    if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                        print("Error response: \(jsonString)")
                        
                        // Try to parse the error JSON
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errorObj = json["error"] as? [String: Any],
                               let errorMsg = errorObj["message"] as? String {
                                errorMessage = "API Error: \(errorMsg)"
                            }
                        } catch {
                            print("Error parsing error response: \(error)")
                        }
                        
                        if jsonString.contains("error") {
                            errorMessage += "\n\nDetailed error: \(jsonString)"
                        }
                    }
                    
                    completion(.failure(NSError(domain: "EloteApp", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: errorMessage
                    ])))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "EloteApp", code: 102, userInfo: [
                    NSLocalizedDescriptionKey: "No data received from API"
                ])))
                return
            }
            
            // Print raw JSON for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw API response: \(rawJSON.prefix(200))...")
            }
            
            // Use the provider's response extractor
            let result = provider.extractResponse(from: data)
            completion(result)
        }
        
        // Helper to debug full API responses (optionally call this in extractResponse).
        func logDebugResponse(_ data: Data) {
            guard let rawString = String(data: data, encoding: .utf8) else {
                print("Could not decode API response data to string")
                return
            }
            
            print("------------------------")
            print("FULL API RESPONSE DUMP:")
            print("------------------------")
            print(rawString)
            print("------------------------")
            
            // Try to pretty-print JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("PRETTY PRINTED JSON:")
                    print(prettyString)
                }
            } catch {
                print("Could not pretty print response: \(error)")
            }
            print("------------------------")
        }
        
        task.resume()
    }
    
    @MainActor
    @objc func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Enter API Key"
        alert.informativeText = "Please enter your \(selectedProvider.rawValue) API key"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = apiKey
        
        alert.accessoryView = textField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            apiKey = textField.stringValue
        }
    }
    
    @MainActor
    @objc func setPrompt() {
        // For backward compatibility
        editSelectedPrompt()
    }
    
    // MARK: - Prompt Management
    
    private func loadPrompts() {
        do {
            // If we have data, decode it
            if !promptsData.isEmpty {
                let decoder = JSONDecoder()
                prompts = try decoder.decode([Prompt].self, from: promptsData)
                
                // Ensure we have a selected prompt if prompts exist
                if !prompts.isEmpty && (selectedPromptId.isEmpty || !prompts.contains(where: { $0.id.uuidString == selectedPromptId })) {
                    selectedPromptId = prompts[0].id.uuidString
                }
            }
        } catch {
            print("Error loading prompts: \(error)")
            // Initialize with empty array on error
            prompts = []
        }
    }
    
    private func savePrompts() {
        do {
            let encoder = JSONEncoder()
            promptsData = try encoder.encode(prompts)
        } catch {
            print("Error saving prompts: \(error)")
        }
    }
    
    @objc func selectPrompt(_ sender: NSMenuItem) {
        if let promptId = sender.representedObject as? String {
            selectedPromptId = promptId
            
            // Update lastUsedPrompt for backward compatibility
            if let selectedPrompt = prompts.first(where: { $0.id.uuidString == promptId }) {
                lastUsedPrompt = selectedPrompt.text
            }
            
            Task { @MainActor in
                setupMenus() // Update menu to show selected prompt
                showNotification(title: "Prompt Changed", 
                                message: "Now using prompt: \(prompts.first(where: { $0.id.uuidString == promptId })?.name ?? "Unknown")")
            }
        }
    }
    
    @MainActor
    @objc func createPrompt() {
        let alert = NSAlert()
        alert.messageText = "Create New Prompt"
        alert.informativeText = "Enter a name and text for your new processing prompt"
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        
        let nameLabel = NSTextField(frame: NSRect(x: 0, y: 70, width: 100, height: 20))
        nameLabel.stringValue = "Name:"
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        
        let nameField = NSTextField(frame: NSRect(x: 110, y: 70, width: 290, height: 24))
        nameField.stringValue = ""
        nameField.placeholderString = "Enter prompt name"
        
        let promptLabel = NSTextField(frame: NSRect(x: 0, y: 30, width: 100, height: 20))
        promptLabel.stringValue = "Prompt:"
        promptLabel.isEditable = false
        promptLabel.isBordered = false
        promptLabel.backgroundColor = .clear
        
        let promptField = NSTextView(frame: NSRect(x: 110, y: 0, width: 290, height: 60))
        promptField.string = ""
        promptField.isEditable = true
        promptField.isRichText = false
        promptField.font = NSFont.systemFont(ofSize: 12)
        let scrollView = NSScrollView(frame: NSRect(x: 110, y: 0, width: 290, height: 60))
        scrollView.documentView = promptField
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        container.addSubview(nameLabel)
        container.addSubview(nameField)
        container.addSubview(promptLabel)
        container.addSubview(scrollView)
        
        alert.accessoryView = container
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn, !nameField.stringValue.isEmpty {
            let newPrompt = Prompt(name: nameField.stringValue, text: promptField.string)
            prompts.append(newPrompt)
            selectedPromptId = newPrompt.id.uuidString
            lastUsedPrompt = newPrompt.text // Update legacy storage
            savePrompts()
            setupMenus() // Update menus with new prompt
        }
    }
    
    @MainActor
    @objc func editSelectedPrompt() {
        guard let prompt = prompts.first(where: { $0.id.uuidString == selectedPromptId }) else {
            showAlert(title: "No Prompt Selected", message: "Please select a prompt to edit")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Edit Prompt"
        alert.informativeText = "Edit the name and text for your processing prompt"
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        
        let nameLabel = NSTextField(frame: NSRect(x: 0, y: 70, width: 100, height: 20))
        nameLabel.stringValue = "Name:"
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        
        let nameField = NSTextField(frame: NSRect(x: 110, y: 70, width: 290, height: 24))
        nameField.stringValue = prompt.name
        
        let promptLabel = NSTextField(frame: NSRect(x: 0, y: 30, width: 100, height: 20))
        promptLabel.stringValue = "Prompt:"
        promptLabel.isEditable = false
        promptLabel.isBordered = false
        promptLabel.backgroundColor = .clear
        
        let promptField = NSTextView(frame: NSRect(x: 110, y: 0, width: 290, height: 60))
        promptField.string = prompt.text
        promptField.isEditable = true
        promptField.isRichText = false
        promptField.font = NSFont.systemFont(ofSize: 12)
        let scrollView = NSScrollView(frame: NSRect(x: 110, y: 0, width: 290, height: 60))
        scrollView.documentView = promptField
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        container.addSubview(nameLabel)
        container.addSubview(nameField)
        container.addSubview(promptLabel)
        container.addSubview(scrollView)
        
        alert.accessoryView = container
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn, !nameField.stringValue.isEmpty {
            // Find and update the existing prompt
            if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[index].name = nameField.stringValue
                prompts[index].text = promptField.string
                
                if selectedPromptId == prompt.id.uuidString {
                    lastUsedPrompt = promptField.string // Update legacy storage
                }
                
                savePrompts()
                setupMenus() // Update menus with edited prompt
            }
        }
    }
    
    @MainActor
    @objc func deleteSelectedPrompt() {
        guard let prompt = prompts.first(where: { $0.id.uuidString == selectedPromptId }) else {
            showAlert(title: "No Prompt Selected", message: "Please select a prompt to delete")
            return
        }
        
        // Prevent deleting the last prompt
        if prompts.count <= 1 {
            showAlert(title: "Cannot Delete", message: "You must have at least one prompt available")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Delete Prompt"
        alert.informativeText = "Are you sure you want to delete the prompt '\(prompt.name)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts.remove(at: index)
                
                // Select another prompt if we're deleting the selected one
                if selectedPromptId == prompt.id.uuidString {
                    selectedPromptId = prompts[0].id.uuidString
                    lastUsedPrompt = prompts[0].text // Update legacy storage
                }
                
                savePrompts()
                setupMenus() // Update menus after deleting the prompt
            }
        }
    }
    
    @MainActor
    @objc func setShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Set Keyboard Shortcuts"
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        
        let processLabel = NSTextField(frame: NSRect(x: 0, y: 60, width: 150, height: 20))
        processLabel.stringValue = "Process Text:"
        processLabel.isEditable = false
        processLabel.isBordered = false
        processLabel.backgroundColor = .clear
        
        let processRecorder = KeyboardShortcuts.RecorderCocoa(for: .processText)
        processRecorder.frame = NSRect(x: 150, y: 60, width: 150, height: 30)
        
        let toggleLabel = NSTextField(frame: NSRect(x: 0, y: 20, width: 150, height: 20))
        toggleLabel.stringValue = "Toggle Auto Mode:"
        toggleLabel.isEditable = false
        toggleLabel.isBordered = false
        toggleLabel.backgroundColor = .clear
        
        let toggleRecorder = KeyboardShortcuts.RecorderCocoa(for: .toggleMonitoring)
        toggleRecorder.frame = NSRect(x: 150, y: 20, width: 150, height: 30)
        
        containerView.addSubview(processLabel)
        containerView.addSubview(processRecorder)
        containerView.addSubview(toggleLabel)
        containerView.addSubview(toggleRecorder)
        
        alert.accessoryView = containerView
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            setupMenus() // Update menu to show new shortcuts
        }
    }
    
    @MainActor
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Elote"
        alert.informativeText = """
        Elote is a clipboard enhancement tool that uses AI to improve your text.
        
        Usage:
        1. Copy text to clipboard (Cmd+C)
        2. Press your Elote keyboard shortcut
        3. Wait for processing
        4. Paste enhanced text (Cmd+V)
        
        Supported APIs: OpenAI and Anthropic
        
        Version: 1.0
        """
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    
    @MainActor
    func showNotification(title: String, message: String) {
        // Skip if notifications are disabled
        if !showNotifications {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.categoryIdentifier = "misiaszek.elote"
        
        // Only play sound if enabled
        if playNotificationSounds {
            content.sound = UNNotificationSound.default
        } else {
            content.sound = nil
        }
        
        let identifier = "misiaszek.elote.\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
    
    
    @MainActor
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension AppDelegate: ObservableObject {
    // This makes AppDelegate fully compatible with @EnvironmentObject
    // No additional implementation needed if your properties already use @AppStorage
}

// Update the fromSVG extension to NOT auto-set template mode
extension NSImage {
    static func fromSVG(_ svgString: String, size: NSSize) -> NSImage? {
        guard let data = svgString.data(using: .utf8) else { return nil }
        
        let tempImage = NSImage(data: data)
        guard let tempImage = tempImage else { return nil }
        
        let finalImage = NSImage(size: size)
        finalImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        tempImage.draw(in: NSRect(origin: .zero, size: size))
        
        finalImage.unlockFocus()
        // Don't set isTemplate here - we'll set it explicitly when we use the image
        
        return finalImage
    }
}
