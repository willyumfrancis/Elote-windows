using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using System.Media;

namespace EloteWindows.Services
{
    public enum ToastType
    {
        Success,
        Error,
        Warning,
        Info
    }

    public static class ToastNotificationService
    {
        private static Window _toastWindow;
        private static DispatcherTimer _timer;

        public static void Initialize()
        {
            // Create the window on the UI thread
            Application.Current.Dispatcher.Invoke(() =>
            {
                _toastWindow = new Window
                {
                    Width = 300,
                    Height = 60,
                    WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize,
                    ShowInTaskbar = false,
                    Topmost = true,
                    AllowsTransparency = true,
                    Background = Brushes.Transparent,
                    WindowStartupLocation = WindowStartupLocation.Manual
                };

                // Set window position to bottom right of screen
                var screenWidth = SystemParameters.PrimaryScreenWidth;
                var screenHeight = SystemParameters.PrimaryScreenHeight;
                _toastWindow.Left = screenWidth - _toastWindow.Width - 20;
                _toastWindow.Top = screenHeight - _toastWindow.Height - 40;

                // Initialize timer
                _timer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(2)
                };
                _timer.Tick += (s, e) =>
                {
                    _timer.Stop();
                    HideToast();
                };
            });
        }

        public static void ShowToast(string message, ToastType type = ToastType.Info, double duration = 2.0)
        {
            if (!SettingsService.GetShowNotifications())
                return;

            Application.Current.Dispatcher.Invoke(() =>
            {
                // Stop any existing timer
                _timer.Stop();

                // Play sound if enabled
                if (SettingsService.GetPlayNotificationSounds())
                {
                    PlayNotificationSound(type);
                }

                // Configure the visual effect backdrop
                var visualEffect = new Border
                {
                    Width = _toastWindow.Width,
                    Height = _toastWindow.Height,
                    Background = new SolidColorBrush(Color.FromArgb(230, 30, 30, 30)),
                    CornerRadius = new CornerRadius(8)
                };

                // Configure message
                var messageTextBlock = new TextBlock
                {
                    Text = message,
                    Foreground = Brushes.White,
                    FontWeight = FontWeights.Medium,
                    TextWrapping = TextWrapping.Wrap,
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(50, 0, 10, 0),
                    MaxWidth = _toastWindow.Width - 60
                };

                // Set icon based on toast type
                var iconImage = new Image
                {
                    Width = 24,
                    Height = 24,
                    Margin = new Thickness(15, 0, 0, 0),
                    VerticalAlignment = VerticalAlignment.Center,
                    HorizontalAlignment = HorizontalAlignment.Left
                };

                // Set icon and colors based on type
                switch (type)
                {
                    case ToastType.Success:
                        iconImage.Source = new BitmapImage(new Uri("pack://application:,,,/Resources/success_icon.png", UriKind.Absolute));
                        visualEffect.Background = new SolidColorBrush(Color.FromArgb(230, 22, 92, 22));
                        break;
                    case ToastType.Error:
                        iconImage.Source = new BitmapImage(new Uri("pack://application:,,,/Resources/error_icon.png", UriKind.Absolute));
                        visualEffect.Background = new SolidColorBrush(Color.FromArgb(230, 139, 0, 0));
                        break;
                    case ToastType.Warning:
                        iconImage.Source = new BitmapImage(new Uri("pack://application:,,,/Resources/warning_icon.png", UriKind.Absolute));
                        visualEffect.Background = new SolidColorBrush(Color.FromArgb(230, 130, 90, 0));
                        break;
                    case ToastType.Info:
                    default:
                        iconImage.Source = new BitmapImage(new Uri("pack://application:,,,/Resources/info_icon.png", UriKind.Absolute));
                        visualEffect.Background = new SolidColorBrush(Color.FromArgb(230, 30, 30, 30));
                        break;
                }

                // Create a grid to hold the icon and message
                var grid = new Grid();
                grid.Children.Add(iconImage);
                grid.Children.Add(messageTextBlock);

                // Set the content of the toast window
                visualEffect.Child = grid;
                _toastWindow.Content = visualEffect;

                // Ensure we have the correct position (in case screen resolution changed)
                var screenWidth = SystemParameters.PrimaryScreenWidth;
                var screenHeight = SystemParameters.PrimaryScreenHeight;
                _toastWindow.Left = screenWidth - _toastWindow.Width - 20;
                _toastWindow.Top = screenHeight - _toastWindow.Height - 40;

                // Show the window if not already visible
                if (!_toastWindow.IsVisible)
                {
                    _toastWindow.Show();
                    _toastWindow.Opacity = 0;

                    // Animate in
                    var fadeIn = new DoubleAnimation
                    {
                        From = 0,
                        To = 1,
                        Duration = TimeSpan.FromMilliseconds(300)
                    };
                    _toastWindow.BeginAnimation(UIElement.OpacityProperty, fadeIn);
                }

                // Set the timer
                _timer.Interval = TimeSpan.FromSeconds(duration);
                _timer.Start();
            });
        }

        private static void HideToast()
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                // Animate out
                var fadeOut = new DoubleAnimation
                {
                    From = 1,
                    To = 0,
                    Duration = TimeSpan.FromMilliseconds(300)
                };
                fadeOut.Completed += (s, e) => _toastWindow.Hide();
                _toastWindow.BeginAnimation(UIElement.OpacityProperty, fadeOut);
            });
        }

        private static void PlayNotificationSound(ToastType type)
        {
            try
            {
                switch (type)
                {
                    case ToastType.Success:
                        SystemSounds.Asterisk.Play();
                        break;
                    case ToastType.Error:
                        SystemSounds.Hand.Play();
                        break;
                    case ToastType.Warning:
                        SystemSounds.Exclamation.Play();
                        break;
                    case ToastType.Info:
                    default:
                        SystemSounds.Asterisk.Play();
                        break;
                }
            }
            catch (Exception)
            {
                // Ignore sound playback errors
            }
        }
    }
}
