using System;
using System.Windows;
using EloteWindows.Services;
using EloteWindows.Views;
using NHotkey;
using NHotkey.Wpf;
using System.Windows.Input;
using Hardcodet.Wpf.TaskbarNotification;

namespace EloteWindows
{
    public partial class App : Application
    {
        private TaskbarIcon _notifyIcon;
        private SettingsWindow _settingsWindow;
        private ClipboardMonitorService _clipboardMonitor;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            // Initialize services
            InitializeServices();
            
            // Create system tray icon
            CreateNotifyIcon();
            
            // Register global hotkeys
            RegisterHotkeys();
        }

        private void Application_Startup(object sender, StartupEventArgs e)
        {
            // Hide the main window as we're a tray app
            Current.ShutdownMode = ShutdownMode.OnExplicitShutdown;
        }

        private void Application_Exit(object sender, ExitEventArgs e)
        {
            // Clean up
            _notifyIcon?.Dispose();
            _clipboardMonitor?.Dispose();
        }

        private void InitializeServices()
        {
            // Initialize settings service
            SettingsService.Initialize();
            
            // Initialize clipboard monitor
            _clipboardMonitor = new ClipboardMonitorService();
            
            // Initialize toast notification service
            ToastNotificationService.Initialize();
            
            // Initialize hotkey service
            HotkeyService.Initialize();
        }

        private void CreateNotifyIcon()
        {
            _notifyIcon = new TaskbarIcon
            {
                Icon = new System.Drawing.Icon(Application.GetResourceStream(new Uri("pack://application:,,,/Resources/elote_icon.ico")).Stream),
                ToolTipText = "Elote - AI Text Enhancement"
            };

            // Create context menu
            _notifyIcon.ContextMenu = new System.Windows.Controls.ContextMenu();

            // Process Text menu item
            var processTextMenuItem = new System.Windows.Controls.MenuItem
            {
                Header = "Process Clipboard" + GetShortcutText(Key.E, ModifierKeys.Control | ModifierKeys.Alt)
            };
            processTextMenuItem.Click += (s, e) => ProcessClipboardText();
            _notifyIcon.ContextMenu.Items.Add(processTextMenuItem);

            // Toggle Auto mode menu item
            var toggleAutoMenuItem = new System.Windows.Controls.MenuItem
            {
                Header = "Toggle Auto Mode" + GetShortcutText(Key.A, ModifierKeys.Control | ModifierKeys.Alt)
            };
            toggleAutoMenuItem.Click += (s, e) => ToggleAutoMode();
            _notifyIcon.ContextMenu.Items.Add(toggleAutoMenuItem);

            // Separator
            _notifyIcon.ContextMenu.Items.Add(new System.Windows.Controls.Separator());

            // Settings menu item
            var settingsMenuItem = new System.Windows.Controls.MenuItem { Header = "Settings..." };
            settingsMenuItem.Click += (s, e) => ShowSettings();
            _notifyIcon.ContextMenu.Items.Add(settingsMenuItem);

            // Separator
            _notifyIcon.ContextMenu.Items.Add(new System.Windows.Controls.Separator());

            // Exit menu item
            var exitMenuItem = new System.Windows.Controls.MenuItem { Header = "Exit" };
            exitMenuItem.Click += (s, e) => Application.Current.Shutdown();
            _notifyIcon.ContextMenu.Items.Add(exitMenuItem);

            // Double-click handler
            _notifyIcon.TrayLeftMouseDoubleClick += (s, e) => ShowSettings();
        }

        private void RegisterHotkeys()
        {
            try
            {
                // Register process text hotkey
                HotkeyManager.Current.AddOrReplace("ProcessText", 
                    SettingsService.GetProcessTextHotkey().Key, 
                    SettingsService.GetProcessTextHotkey().Modifiers, 
                    (s, e) => ProcessClipboardText());

                // Register toggle auto mode hotkey
                HotkeyManager.Current.AddOrReplace("ToggleAutoMode", 
                    SettingsService.GetToggleAutoModeHotkey().Key, 
                    SettingsService.GetToggleAutoModeHotkey().Modifiers, 
                    (s, e) => ToggleAutoMode());
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to register hotkeys: {ex.Message}", "Elote Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private string GetShortcutText(Key key, ModifierKeys modifiers)
        {
            var shortcut = SettingsService.GetShortcutText(key, modifiers);
            return string.IsNullOrEmpty(shortcut) ? "" : $" ({shortcut})";
        }

        public void ShowSettings()
        {
            if (_settingsWindow == null || !_settingsWindow.IsVisible)
            {
                _settingsWindow = new SettingsWindow();
                _settingsWindow.Show();
            }
            else
            {
                _settingsWindow.Activate();
            }
        }

        public void ProcessClipboardText()
        {
            if (!NetworkService.IsNetworkAvailable())
            {
                ToastNotificationService.ShowToast("Network Unavailable. Please check your internet connection.", ToastType.Error);
                return;
            }

            var clipboardText = ClipboardService.GetText();
            if (string.IsNullOrWhiteSpace(clipboardText))
            {
                ToastNotificationService.ShowToast("No text found in clipboard.", ToastType.Warning);
                return;
            }

            // Show processing toast
            ToastNotificationService.ShowToast("Processing text...", ToastType.Info);

            // Process text with the selected LLM provider
            var llmService = new LLMService();
            llmService.ProcessText(clipboardText, (result) =>
            {
                if (result.IsSuccess)
                {
                    ClipboardService.SetText(result.ProcessedText);
                    ToastNotificationService.ShowToast("Text processed and copied to clipboard!", ToastType.Success);
                }
                else
                {
                    ToastNotificationService.ShowToast($"Error: {result.Error}", ToastType.Error);
                }
            });
        }

        public void ToggleAutoMode()
        {
            var autoModeEnabled = SettingsService.GetAutoModeEnabled();
            SettingsService.SetAutoModeEnabled(!autoModeEnabled);

            if (!autoModeEnabled)
            {
                _clipboardMonitor.StartMonitoring();
                ToastNotificationService.ShowToast("Auto Mode enabled", ToastType.Info);
            }
            else
            {
                _clipboardMonitor.StopMonitoring();
                ToastNotificationService.ShowToast("Auto Mode disabled", ToastType.Info);
            }

            // Update menu item status
            UpdateAutoModeMenuItem();
        }

        private void UpdateAutoModeMenuItem()
        {
            var autoModeEnabled = SettingsService.GetAutoModeEnabled();
            var toggleAutoMenuItem = _notifyIcon.ContextMenu.Items[1] as System.Windows.Controls.MenuItem;
            if (toggleAutoMenuItem != null)
            {
                toggleAutoMenuItem.Header = "Toggle Auto Mode" + GetShortcutText(Key.A, ModifierKeys.Control | ModifierKeys.Alt) + (autoModeEnabled ? " ✓" : "");
            }
        }
    }
}
