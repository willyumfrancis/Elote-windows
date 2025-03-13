import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var apiKey: String = ""
    @State private var selectedProvider: LLMProvider = .openAI
    @State private var customModel: String = ""
    @State private var prompt: String = ""
    
    // Load saved values when view appears
    private func loadSavedValues() {
        apiKey = appDelegate.apiKey
        if let provider = LLMProvider(rawValue: appDelegate.selectedProviderRaw) {
            selectedProvider = provider
        }
        customModel = appDelegate.customModel
        prompt = appDelegate.lastUsedPrompt
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app icon
            HStack {
                // Use the colored version of the elote icon
                if let eloteImage = NSImage.fromSVG(appDelegate.eloteColoredIconSVG, size: NSSize(width: 64, height: 64)) {
                    Image(nsImage: eloteImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                } else {
                    // Fallback to system icon
                    Image(systemName: "text.bubble.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading) {
                    Text("Elote")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered Text Enhancement")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Provider selection
                    VStack(alignment: .leading) {
                        Text("LLM Provider").fontWeight(.medium)
                        
                        Picker("", selection: $selectedProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedProvider) { newValue in
                            appDelegate.selectedProviderRaw = newValue.rawValue
                        }
                    }
                    .padding(.horizontal)
                    
                    // API Key
                    VStack(alignment: .leading) {
                        Text("API Key").fontWeight(.medium)
                        
                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: apiKey) { newValue in
                                appDelegate.apiKey = newValue
                            }
                        
                        Text("Your API key for \(selectedProvider.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // MOVED: Notification settings section
                    VStack(alignment: .leading) {
                        Text("Notifications").fontWeight(.medium)
                        
                        Toggle("Show Notifications", isOn: Binding<Bool>(
                            get: { appDelegate.showNotifications },
                            set: { appDelegate.showNotifications = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        
                        Toggle("Play Notification Sounds", isOn: Binding<Bool>(
                            get: { appDelegate.playNotificationSounds },
                            set: { appDelegate.playNotificationSounds = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(!appDelegate.showNotifications)
                        
                        Text("Control how Elote notifies you of events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Custom model
                    VStack(alignment: .leading) {
                        Text("Custom Model").fontWeight(.medium)
                        
                        
                        
                        TextField("e.g. \(selectedProvider.defaultModel)", text: $customModel)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: customModel) { newValue in
                                appDelegate.customModel = newValue
                            }
                        
                        Text("Leave empty to use the default model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Processing prompt
                    VStack(alignment: .leading) {
                        Text("Processing Prompt").fontWeight(.medium)
                        
                        TextEditor(text: $prompt)
                            .font(.body)
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.3), width: 1)
                            .onChange(of: prompt) { newValue in
                                appDelegate.lastUsedPrompt = newValue
                            }
                        
                        Text("Instructions for how to process the text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Notification settings (new section)
                    VStack(alignment: .leading) {
                        Text("Notifications").fontWeight(.medium)
                        
                        Toggle("Show Notifications", isOn: Binding<Bool>(
                            get: { appDelegate.showNotifications },
                            set: { appDelegate.showNotifications = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        
                        Toggle("Play Notification Sounds", isOn: Binding<Bool>(
                            get: { appDelegate.playNotificationSounds },
                            set: { appDelegate.playNotificationSounds = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(!appDelegate.showNotifications)
                        
                        Text("Control how Elote notifies you of events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Keyboard shortcuts
                    VStack(alignment: .leading) {
                        Text("Keyboard Shortcuts").fontWeight(.medium)
                        
                        HStack {
                            Text("Process Text:")
                                .frame(width: 120, alignment: .leading)
                            
                            KeyboardShortcuts.Recorder(for: .processText)
                        }
                        .padding(.bottom, 4)
                        
                        HStack {
                            Text("Toggle Auto Mode:")
                                .frame(width: 120, alignment: .leading)
                            
                            KeyboardShortcuts.Recorder(for: .toggleMonitoring)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Auto mode
                    VStack(alignment: .leading) {
                        Toggle("Auto Mode", isOn: Binding<Bool>(
                            get: { appDelegate.isAutoModeEnabled },
                            set: { newValue in
                                appDelegate.isAutoModeEnabled = newValue
                                if newValue {
                                    appDelegate.startClipboardMonitoring()
                                } else {
                                    appDelegate.stopClipboardMonitoring()
                                }
                                appDelegate.updateStatusItemAppearance()
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                        
                        Text("When enabled, Elote will watch your clipboard for text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
        }
        .frame(width: 450, height: 600)
        .onAppear {
            loadSavedValues()
        }
    }
}
