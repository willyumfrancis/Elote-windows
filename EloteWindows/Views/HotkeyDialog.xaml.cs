using System;
using System.Windows;
using System.Windows.Input;
using EloteWindows.Services;

namespace EloteWindows.Views
{
    public partial class HotkeyDialog : Window
    {
        private Key _key;
        private ModifierKeys _modifiers;
        private bool _keySet = false;

        public HotkeySettings Hotkey { get; private set; }

        public HotkeyDialog(string actionName, HotkeySettings currentHotkey = null)
        {
            InitializeComponent();
            
            // Set the action name
            ActionTextBlock.Text = $"Set shortcut for {actionName}";
            
            // Initialize with current hotkey if provided
            if (currentHotkey != null)
            {
                _key = currentHotkey.Key;
                _modifiers = currentHotkey.Modifiers;
                _keySet = true;
                UpdateHotkeyDisplay();
            }
            
            // Add key event handlers
            this.PreviewKeyDown += HotkeyDialog_PreviewKeyDown;
        }

        private void HotkeyDialog_PreviewKeyDown(object sender, KeyEventArgs e)
        {
            // Get the pressed key
            Key key = e.Key;
            
            // Skip modifier keys when pressed alone
            if (key == Key.LeftCtrl || key == Key.RightCtrl ||
                key == Key.LeftAlt || key == Key.RightAlt ||
                key == Key.LeftShift || key == Key.RightShift ||
                key == Key.LWin || key == Key.RWin ||
                key == Key.System)
            {
                return;
            }
            
            // Get pressed modifiers
            ModifierKeys modifiers = Keyboard.Modifiers;
            
            // Store the key combination
            _key = key;
            _modifiers = modifiers;
            _keySet = true;
            
            // Update display
            UpdateHotkeyDisplay();
            
            // Mark as handled
            e.Handled = true;
        }

        private void UpdateHotkeyDisplay()
        {
            // Format the key combination for display
            string keyText = SettingsService.GetShortcutText(_key, _modifiers);
            HotkeyDisplayTextBlock.Text = keyText;
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            if (!_keySet)
            {
                MessageBox.Show("Please press a key combination for the shortcut.", 
                              "No Shortcut Set", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            
            // Create new hotkey settings
            Hotkey = new HotkeySettings
            {
                Key = _key,
                Modifiers = _modifiers
            };
            
            // Set dialog result and close
            this.DialogResult = true;
            this.Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            // Cancel and close
            this.DialogResult = false;
            this.Close();
        }
    }
}
