using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Threading;

namespace EloteWindows.Services
{
    public class ClipboardMonitorService : IDisposable
    {
        // Win32 API constants
        private const int WM_CLIPBOARDUPDATE = 0x031D;
        private IntPtr HWND_MESSAGE = new IntPtr(-3);

        // Win32 API imports
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool AddClipboardFormatListener(IntPtr hwnd);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        private const int GWL_STYLE = -16;
        private const int WS_CHILD = 0x40000000;

        private Window _hiddenWindow;
        private HwndSource _hwndSource;
        private string _lastProcessedText = string.Empty;
        private bool _isMonitoring = false;
        private Timer _debounceTimer;
        private readonly object _lockObject = new object();

        public ClipboardMonitorService()
        {
            // Create hidden window on UI thread
            Application.Current.Dispatcher.Invoke(() =>
            {
                _hiddenWindow = new Window
                {
                    Width = 0,
                    Height = 0,
                    WindowStyle = WindowStyle.None,
                    ShowInTaskbar = false,
                    ShowActivated = false,
                    Visibility = Visibility.Hidden
                };

                // Set window to be a message-only window
                _hiddenWindow.SourceInitialized += (s, e) =>
                {
                    var handle = new WindowInteropHelper(_hiddenWindow).Handle;
                    _hwndSource = HwndSource.FromHwnd(handle);
                    _hwndSource.AddHook(WndProc);

                    // Make it a message-only window
                    SetParent(handle, HWND_MESSAGE);
                    int style = GetWindowLong(handle, GWL_STYLE);
                    SetWindowLong(handle, GWL_STYLE, style | WS_CHILD);
                };

                _hiddenWindow.Show();
            });

            // Initialize the debounce timer
            _debounceTimer = new Timer(ProcessClipboardContent, null, Timeout.Infinite, Timeout.Infinite);
        }

        public void StartMonitoring()
        {
            lock (_lockObject)
            {
                if (_isMonitoring)
                    return;

                Application.Current.Dispatcher.Invoke(() =>
                {
                    if (_hwndSource != null)
                    {
                        AddClipboardFormatListener(_hwndSource.Handle);
                        _isMonitoring = true;
                    }
                });
            }
        }

        public void StopMonitoring()
        {
            lock (_lockObject)
            {
                if (!_isMonitoring)
                    return;

                Application.Current.Dispatcher.Invoke(() =>
                {
                    if (_hwndSource != null)
                    {
                        RemoveClipboardFormatListener(_hwndSource.Handle);
                        _isMonitoring = false;
                    }
                });
            }
        }

        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_CLIPBOARDUPDATE && _isMonitoring)
            {
                // Reset and restart the timer to handle clipboard content after a short delay
                // This helps debounce multiple rapid clipboard updates
                _debounceTimer.Change(500, Timeout.Infinite);
                handled = true;
            }

            return IntPtr.Zero;
        }

        private void ProcessClipboardContent(object state)
        {
            if (!_isMonitoring)
                return;

            string clipboardText = string.Empty;

            // Get clipboard text on UI thread
            Application.Current.Dispatcher.Invoke(() =>
            {
                try
                {
                    if (Clipboard.ContainsText())
                    {
                        clipboardText = Clipboard.GetText();
                    }
                }
                catch (Exception)
                {
                    // Ignore clipboard access errors
                }
            });

            // Check if text is valid and not already processed
            if (!string.IsNullOrWhiteSpace(clipboardText) && clipboardText != _lastProcessedText)
            {
                _lastProcessedText = clipboardText;

                // Process the text
                ToastNotificationService.ShowToast("Auto-processing text...", ToastType.Info);

                // Use LLMService to process the text
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
        }

        public void Dispose()
        {
            StopMonitoring();
            _debounceTimer?.Dispose();

            Application.Current.Dispatcher.Invoke(() =>
            {
                _hwndSource?.RemoveHook(WndProc);
                _hwndSource?.Dispose();
                _hiddenWindow?.Close();
            });
        }
    }
}
