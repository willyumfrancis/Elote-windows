using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using EloteWindows.Models;
using EloteWindows.Services;

namespace EloteWindows.Views
{
    public partial class SettingsWindow : Window
    {
        private bool _isInitializing = true;
        
        public SettingsWindow()
        {
            InitializeComponent();
            LoadSettings();
            _isInitializing = false;
        }

        private void LoadSettings()
        {
            // Provider
            var provider = LLMProvider.GetProvider(SettingsService.GetSelectedProvider());
            ProviderComboBox.SelectedIndex = provider.Type == ProviderType.OpenAI ? 0 : 1;
            
            // API Key
            ApiKeyPasswordBox.Password = SettingsService.GetApiKey();
            
            // Custom Model
            CustomModelTextBox.Text = SettingsService.GetCustomModel();
            UpdateModelHintText();
            
            // Prompt
            PromptTextBox.Text = SettingsService.GetLastUsedPrompt();
            
            // Saved Prompts
            LoadPrompts();
            
            // Notifications
            ShowNotificationsCheckBox.IsChecked = SettingsService.GetShowNotifications();
            PlaySoundsCheckBox.IsChecked = SettingsService.GetPlayNotificationSounds();
            PlaySoundsCheckBox.IsEnabled = ShowNotificationsCheckBox.IsChecked ?? false;
            
            // Keyboard Shortcuts
            UpdateShortcutTexts();
            
            // Auto Mode
            AutoModeCheckBox.IsChecked = SettingsService.GetAutoModeEnabled();
            
            // Start with Windows
            StartWithWindowsCheckBox.IsChecked = SettingsService.GetStartWithWindows();
        }

        private void LoadPrompts()
        {
            PromptsComboBox.Items.Clear();
            
            var prompts = SettingsService.GetPrompts();
            foreach (var prompt in prompts)
            {
                PromptsComboBox.Items.Add(prompt);
            }
            
            PromptsComboBox.DisplayMemberPath = "Name";
            
            // Select the currently selected prompt if any
            var selectedPromptId = SettingsService.GetSelectedPromptId();
            if (selectedPromptId.HasValue)
            {
                for (int i = 0; i < PromptsComboBox.Items.Count; i++)
                {
                    if (((Prompt)PromptsComboBox.Items[i]).Id == selectedPromptId.Value)
                    {
                        PromptsComboBox.SelectedIndex = i;
                        break;
                    }
                }
            }
            
            // Enable/disable edit and delete buttons based on selection
            EditPromptButton.IsEnabled = PromptsComboBox.SelectedItem != null;
            DeletePromptButton.IsEnabled = PromptsComboBox.SelectedItem != null;
        }

        private void UpdateModelHintText()
        {
            var provider = LLMProvider.GetProvider(SettingsService.GetSelectedProvider());
            CustomModelHintTextBlock.Text = $"Leave empty to use the default model ({provider.GetDefaultModel()})";
        }

        private void UpdateShortcutTexts()
        {
            var processTextHotkey = SettingsService.GetProcessTextHotkey();
            ProcessTextShortcutTextBox.Text = SettingsService.GetShortcutText(
                processTextHotkey.Key, processTextHotkey.Modifiers);
                
            var toggleAutoModeHotkey = SettingsService.GetToggleAutoModeHotkey();
            ToggleAutoModeShortcutTextBox.Text = SettingsService.GetShortcutText(
                toggleAutoModeHotkey.Key, toggleAutoModeHotkey.Modifiers);
        }

        #region Event Handlers

        private void ProviderComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isInitializing) return;
            
            ProviderType providerType = ProviderComboBox.SelectedIndex == 0 
                ? ProviderType.OpenAI : ProviderType.Anthropic;
                
            SettingsService.SetSelectedProvider(providerType);
            UpdateModelHintText();
        }

        private void ApiKeyPasswordBox_PasswordChanged(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            
            SettingsService.SetApiKey(ApiKeyPasswordBox.Password);
        }

        private void CustomModelTextBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_isInitializing) return;
            
            SettingsService.SetCustomModel(CustomModelTextBox.Text);
        }

        private void PromptTextBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_isInitializing) return;
            
            SettingsService.SetLastUsedPrompt(PromptTextBox.Text);
        }

        private void PromptsComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_isInitializing) return;
            
            var selectedPrompt = PromptsComboBox.SelectedItem as Prompt;
            if (selectedPrompt != null)
            {
                SettingsService.SetSelectedPromptId(selectedPrompt.Id);
                // Update the prompt text box with the selected prompt
                PromptTextBox.Text = selectedPrompt.Text;
            }
            else
            {
                SettingsService.SetSelectedPromptId(null);
            }
            
            // Enable/disable edit and delete buttons based on selection
            EditPromptButton.IsEnabled = selectedPrompt != null;
            DeletePromptButton.IsEnabled = selectedPrompt != null;
        }

        private void ShowNotificationsCheckBox_CheckChanged(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            
            bool enabled = ShowNotificationsCheckBox.IsChecked ?? false;
            SettingsService.SetShowNotifications(enabled);
            
            // Disable sound checkbox if notifications are disabled
            PlaySoundsCheckBox.IsEnabled = enabled;
        }

        private void PlaySoundsCheckBox_CheckChanged(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            
            SettingsService.SetPlayNotificationSounds(PlaySoundsCheckBox.IsChecked ?? false);
        }

        private void AutoModeCheckBox_CheckChanged(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            
            bool enabled = AutoModeCheckBox.IsChecked ?? false;
            SettingsService.SetAutoModeEnabled(enabled);
            
            // Update the application auto mode status
            if (enabled)
            {
                ((App)Application.Current).ToggleAutoMode();
            }
            else
            {
                ((App)Application.Current).ToggleAutoMode();
            }
        }

        private void StartWithWindowsCheckBox_CheckChanged(object sender, RoutedEventArgs e)
        {
            if (_isInitializing) return;
            
            SettingsService.SetStartWithWindows(StartWithWindowsCheckBox.IsChecked ?? false);
        }

        private void SetProcessTextShortcut_Click(object sender, RoutedEventArgs e)
        {
            ShowHotkeyDialog("Process Text", SettingsService.GetProcessTextHotkey(), newHotkey =>
            {
                SettingsService.SetProcessTextHotkey(newHotkey);
                
                // Re-register the hotkey
                HotkeyService.UpdateProcessTextHotkey();
                
                // Update the displayed shortcut
                UpdateShortcutTexts();
            });
        }

        private void SetToggleAutoModeShortcut_Click(object sender, RoutedEventArgs e)
        {
            ShowHotkeyDialog("Toggle Auto Mode", SettingsService.GetToggleAutoModeHotkey(), newHotkey =>
            {
                SettingsService.SetToggleAutoModeHotkey(newHotkey);
                
                // Re-register the hotkey
                HotkeyService.UpdateToggleAutoModeHotkey();
                
                // Update the displayed shortcut
                UpdateShortcutTexts();
            });
        }

        private void NewPromptButton_Click(object sender, RoutedEventArgs e)
        {
            // Show dialog to create a new prompt
            var dialog = new PromptDialog("Create New Prompt");
            if (dialog.ShowDialog() == true)
            {
                // Create new prompt
                var prompt = new Prompt(dialog.PromptName, dialog.PromptText);
                
                // Add to settings
                var prompts = SettingsService.GetPrompts();
                prompts.Add(prompt);
                SettingsService.SetPrompts(prompts);
                
                // Reload prompts
                LoadPrompts();
                
                // Select the new prompt
                for (int i = 0; i < PromptsComboBox.Items.Count; i++)
                {
                    if (((Prompt)PromptsComboBox.Items[i]).Id == prompt.Id)
                    {
                        PromptsComboBox.SelectedIndex = i;
                        break;
                    }
                }
            }
        }

        private void EditPromptButton_Click(object sender, RoutedEventArgs e)
        {
            var selectedPrompt = PromptsComboBox.SelectedItem as Prompt;
            if (selectedPrompt == null)
                return;
                
            // Show dialog to edit the prompt
            var dialog = new PromptDialog("Edit Prompt", selectedPrompt.Name, selectedPrompt.Text);
            if (dialog.ShowDialog() == true)
            {
                // Update prompt
                var prompts = SettingsService.GetPrompts();
                int index = prompts.FindIndex(p => p.Id == selectedPrompt.Id);
                if (index >= 0)
                {
                    prompts[index].Name = dialog.PromptName;
                    prompts[index].Text = dialog.PromptText;
                    SettingsService.SetPrompts(prompts);
                    
                    // Reload prompts
                    LoadPrompts();
                    
                    // Re-select the prompt
                    for (int i = 0; i < PromptsComboBox.Items.Count; i++)
                    {
                        if (((Prompt)PromptsComboBox.Items[i]).Id == selectedPrompt.Id)
                        {
                            PromptsComboBox.SelectedIndex = i;
                            break;
                        }
                    }
                }
            }
        }

        private void DeletePromptButton_Click(object sender, RoutedEventArgs e)
        {
            var selectedPrompt = PromptsComboBox.SelectedItem as Prompt;
            if (selectedPrompt == null)
                return;
                
            // Confirm deletion
            if (MessageBox.Show($"Are you sure you want to delete the prompt '{selectedPrompt.Name}'?",
                              "Confirm Deletion", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                // Delete prompt
                var prompts = SettingsService.GetPrompts();
                prompts.RemoveAll(p => p.Id == selectedPrompt.Id);
                SettingsService.SetPrompts(prompts);
                
                // If this was the selected prompt, clear the selection
                if (SettingsService.GetSelectedPromptId() == selectedPrompt.Id)
                {
                    SettingsService.SetSelectedPromptId(null);
                }
                
                // Reload prompts
                LoadPrompts();
            }
        }

        #endregion

        #region Hotkey Dialog

        private void ShowHotkeyDialog(string actionName, HotkeySettings currentHotkey, Action<HotkeySettings> callback)
        {
            var dialog = new HotkeyDialog(actionName, currentHotkey);
            if (dialog.ShowDialog() == true)
            {
                callback(dialog.Hotkey);
            }
        }

        #endregion
    }
}
