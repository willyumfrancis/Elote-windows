using System;
using System.Windows;
using System.Threading.Tasks;
using System.Threading;

namespace EloteWindows.Services
{
    public static class ClipboardService
    {
        /// <summary>
        /// Gets text from the clipboard, if available
        /// </summary>
        /// <returns>Clipboard text or empty string if clipboard is empty or doesn't contain text</returns>
        public static string GetText()
        {
            if (!Thread.CurrentThread.GetApartmentState().Equals(ApartmentState.STA))
            {
                string result = string.Empty;
                var thread = new Thread(() =>
                {
                    try
                    {
                        if (Clipboard.ContainsText())
                        {
                            result = Clipboard.GetText();
                        }
                    }
                    catch (Exception ex)
                    {
                        // Log error
                        Console.WriteLine($"Error getting clipboard text: {ex.Message}");
                    }
                });
                
                thread.SetApartmentState(ApartmentState.STA);
                thread.Start();
                thread.Join();
                
                return result;
            }
            else
            {
                try
                {
                    if (Clipboard.ContainsText())
                    {
                        return Clipboard.GetText();
                    }
                }
                catch (Exception ex)
                {
                    // Log error
                    Console.WriteLine($"Error getting clipboard text: {ex.Message}");
                }
            }
            
            return string.Empty;
        }

        /// <summary>
        /// Sets text to clipboard
        /// </summary>
        /// <param name="text">The text to set on clipboard</param>
        /// <returns>True if successful, false otherwise</returns>
        public static bool SetText(string text)
        {
            if (string.IsNullOrEmpty(text))
                return false;

            if (!Thread.CurrentThread.GetApartmentState().Equals(ApartmentState.STA))
            {
                bool success = false;
                var thread = new Thread(() =>
                {
                    try
                    {
                        Clipboard.SetText(text);
                        success = true;
                    }
                    catch (Exception ex)
                    {
                        // Log error
                        Console.WriteLine($"Error setting clipboard text: {ex.Message}");
                    }
                });
                
                thread.SetApartmentState(ApartmentState.STA);
                thread.Start();
                thread.Join();
                
                return success;
            }
            else
            {
                try
                {
                    Clipboard.SetText(text);
                    return true;
                }
                catch (Exception ex)
                {
                    // Log error
                    Console.WriteLine($"Error setting clipboard text: {ex.Message}");
                    return false;
                }
            }
        }
    }
}
