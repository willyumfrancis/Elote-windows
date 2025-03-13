using System;
using System.Windows.Input;
using NHotkey;
using NHotkey.Wpf;

namespace EloteWindows.Services
{
    public static class HotkeyService
    {
        public static void Initialize()
        {
            // Register initial hotkeys
            try
            {
                RegisterProcessTextHotkey();
                RegisterToggleAutoModeHotkey();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to register hotkeys: {ex.Message}");
            }
        }

        public static void UpdateProcessTextHotkey()
        {
            try
            {
                RegisterProcessTextHotkey();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to update process text hotkey: {ex.Message}");
            }
        }

        public static void UpdateToggleAutoModeHotkey()
        {
            try
            {
                RegisterToggleAutoModeHotkey();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to update toggle auto mode hotkey: {ex.Message}");
            }
        }

        private static void RegisterProcessTextHotkey()
        {
            var hotkeySettings = SettingsService.GetProcessTextHotkey();
            
            HotkeyManager.Current.AddOrReplace("ProcessText", 
                hotkeySettings.Key, 
                hotkeySettings.Modifiers, 
                OnProcessTextHotkey);
        }

        private static void RegisterToggleAutoModeHotkey()
        {
            var hotkeySettings = SettingsService.GetToggleAutoModeHotkey();
            
            HotkeyManager.Current.AddOrReplace("ToggleAutoMode", 
                hotkeySettings.Key, 
                hotkeySettings.Modifiers, 
                OnToggleAutoModeHotkey);
        }

        private static void OnProcessTextHotkey(object sender, HotkeyEventArgs e)
        {
            // Call the process text method from App
            ((App)System.Windows.Application.Current).ProcessClipboardText();
            e.Handled = true;
        }

        private static void OnToggleAutoModeHotkey(object sender, HotkeyEventArgs e)
        {
            // Call the toggle auto mode method from App
            ((App)System.Windows.Application.Current).ToggleAutoMode();
            e.Handled = true;
        }
    }
}
