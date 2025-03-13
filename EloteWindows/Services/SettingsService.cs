using System;
using System.Collections.Generic;
using System.IO;
using System.Windows.Input;
using Microsoft.Win32;
using Newtonsoft.Json;
using EloteWindows.Models;

namespace EloteWindows.Services
{
    public static class SettingsService
    {
        private static readonly string SettingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Elote", "settings.json");
            
        private static Settings _settings;
        private static readonly object _lock = new object();

        public static void Initialize()
        {
            // Create directory if it doesn't exist
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath));
            
            // Load settings from file or create default settings
            LoadSettings();
            
            // Register for auto-start
            UpdateStartupRegistration();
        }

        private static void LoadSettings()
        {
            lock (_lock)
            {
                if (File.Exists(SettingsPath))
                {
                    try
                    {
                        string json = File.ReadAllText(SettingsPath);
                        _settings = JsonConvert.DeserializeObject<Settings>(json);
                    }
                    catch (Exception)
                    {
                        _settings = CreateDefaultSettings();
                    }
                }
                else
                {
                    _settings = CreateDefaultSettings();
                    SaveSettings();
                }
            }
        }

        private static Settings CreateDefaultSettings()
        {
            return new Settings
            {
                ApiKey = "",
                SelectedProvider = ProviderType.OpenAI,
                CustomModel = "",
                LastUsedPrompt = "Improve this text to make it clear, concise, and professional.",
                ShowNotifications = true,
                PlayNotificationSounds = true,
                AutoModeEnabled = false,
                ProcessTextHotkey = new HotkeySettings
                {
                    Key = Key.E,
                    Modifiers = ModifierKeys.Control | ModifierKeys.Alt
                },
                ToggleAutoModeHotkey = new HotkeySettings
                {
                    Key = Key.A,
                    Modifiers = ModifierKeys.Control | ModifierKeys.Alt
                },
                Prompts = new List<Prompt>
                {
                    new Prompt("Default", "Improve this text to make it clear, concise, and professional."),
                    new Prompt("Fix Grammar", "Fix any grammar and spelling errors in this text. Maintain the original tone and style."),
                    new Prompt("Make Professional", "Make this text more professional and formal.")
                },
                SelectedPromptId = null,
                StartWithWindows = true
            };
        }

        public static void SaveSettings()
        {
            lock (_lock)
            {
                string json = JsonConvert.SerializeObject(_settings, Formatting.Indented);
                File.WriteAllText(SettingsPath, json);
            }
            
            // Update startup registration
            UpdateStartupRegistration();
        }

        private static void UpdateStartupRegistration()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                {
                    if (_settings.StartWithWindows)
                    {
                        string appPath = System.Reflection.Assembly.GetExecutingAssembly().Location;
                        key?.SetValue("Elote", $"\"{appPath}\"");
                    }
                    else
                    {
                        key?.DeleteValue("Elote", false);
                    }
                }
            }
            catch (Exception)
            {
                // Ignore errors with registry - user might not have permissions
            }
        }

        #region Settings Properties
        
        public static string GetApiKey()
        {
            lock (_lock)
            {
                return _settings.ApiKey;
            }
        }

        public static void SetApiKey(string value)
        {
            lock (_lock)
            {
                _settings.ApiKey = value;
                SaveSettings();
            }
        }

        public static ProviderType GetSelectedProvider()
        {
            lock (_lock)
            {
                return _settings.SelectedProvider;
            }
        }

        public static void SetSelectedProvider(ProviderType value)
        {
            lock (_lock)
            {
                _settings.SelectedProvider = value;
                SaveSettings();
            }
        }

        public static string GetCustomModel()
        {
            lock (_lock)
            {
                return _settings.CustomModel;
            }
        }

        public static void SetCustomModel(string value)
        {
            lock (_lock)
            {
                _settings.CustomModel = value;
                SaveSettings();
            }
        }

        public static string GetLastUsedPrompt()
        {
            lock (_lock)
            {
                return _settings.LastUsedPrompt;
            }
        }

        public static void SetLastUsedPrompt(string value)
        {
            lock (_lock)
            {
                _settings.LastUsedPrompt = value;
                SaveSettings();
            }
        }

        public static bool GetShowNotifications()
        {
            lock (_lock)
            {
                return _settings.ShowNotifications;
            }
        }

        public static void SetShowNotifications(bool value)
        {
            lock (_lock)
            {
                _settings.ShowNotifications = value;
                SaveSettings();
            }
        }

        public static bool GetPlayNotificationSounds()
        {
            lock (_lock)
            {
                return _settings.PlayNotificationSounds;
            }
        }

        public static void SetPlayNotificationSounds(bool value)
        {
            lock (_lock)
            {
                _settings.PlayNotificationSounds = value;
                SaveSettings();
            }
        }

        public static bool GetAutoModeEnabled()
        {
            lock (_lock)
            {
                return _settings.AutoModeEnabled;
            }
        }

        public static void SetAutoModeEnabled(bool value)
        {
            lock (_lock)
            {
                _settings.AutoModeEnabled = value;
                SaveSettings();
            }
        }

        public static HotkeySettings GetProcessTextHotkey()
        {
            lock (_lock)
            {
                return _settings.ProcessTextHotkey;
            }
        }

        public static void SetProcessTextHotkey(HotkeySettings value)
        {
            lock (_lock)
            {
                _settings.ProcessTextHotkey = value;
                SaveSettings();
            }
        }

        public static HotkeySettings GetToggleAutoModeHotkey()
        {
            lock (_lock)
            {
                return _settings.ToggleAutoModeHotkey;
            }
        }

        public static void SetToggleAutoModeHotkey(HotkeySettings value)
        {
            lock (_lock)
            {
                _settings.ToggleAutoModeHotkey = value;
                SaveSettings();
            }
        }

        public static List<Prompt> GetPrompts()
        {
            lock (_lock)
            {
                return _settings.Prompts;
            }
        }

        public static void SetPrompts(List<Prompt> value)
        {
            lock (_lock)
            {
                _settings.Prompts = value;
                SaveSettings();
            }
        }

        public static Guid? GetSelectedPromptId()
        {
            lock (_lock)
            {
                return _settings.SelectedPromptId;
            }
        }

        public static void SetSelectedPromptId(Guid? value)
        {
            lock (_lock)
            {
                _settings.SelectedPromptId = value;
                SaveSettings();
            }
        }

        public static bool GetStartWithWindows()
        {
            lock (_lock)
            {
                return _settings.StartWithWindows;
            }
        }

        public static void SetStartWithWindows(bool value)
        {
            lock (_lock)
            {
                _settings.StartWithWindows = value;
                SaveSettings();
            }
        }
        
        public static string GetShortcutText(Key key, ModifierKeys modifiers)
        {
            string result = "";
            
            if ((modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                result += "Ctrl+";
            if ((modifiers & ModifierKeys.Alt) == ModifierKeys.Alt)
                result += "Alt+";
            if ((modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                result += "Shift+";
            if ((modifiers & ModifierKeys.Windows) == ModifierKeys.Windows)
                result += "Win+";
                
            result += key.ToString();
            
            return result;
        }
        
        #endregion
    }

    public class Settings
    {
        public string ApiKey { get; set; }
        public ProviderType SelectedProvider { get; set; }
        public string CustomModel { get; set; }
        public string LastUsedPrompt { get; set; }
        public bool ShowNotifications { get; set; }
        public bool PlayNotificationSounds { get; set; }
        public bool AutoModeEnabled { get; set; }
        public HotkeySettings ProcessTextHotkey { get; set; }
        public HotkeySettings ToggleAutoModeHotkey { get; set; }
        public List<Prompt> Prompts { get; set; }
        public Guid? SelectedPromptId { get; set; }
        public bool StartWithWindows { get; set; }
    }

    public class HotkeySettings
    {
        public Key Key { get; set; }
        public ModifierKeys Modifiers { get; set; }
    }
}
