using System;
using System.Windows;

namespace EloteWindows.Views
{
    public partial class PromptDialog : Window
    {
        public string PromptName { get; private set; }
        public string PromptText { get; private set; }

        public PromptDialog(string title, string promptName = "", string promptText = "")
        {
            InitializeComponent();
            
            // Set the dialog title
            TitleTextBlock.Text = title;
            this.Title = title;
            
            // Set initial values if provided
            PromptNameTextBox.Text = promptName;
            PromptTextTextBox.Text = promptText;
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            // Validate input
            if (string.IsNullOrWhiteSpace(PromptNameTextBox.Text))
            {
                MessageBox.Show("Please enter a name for the prompt.", 
                              "Missing Name", MessageBoxButton.OK, MessageBoxImage.Warning);
                PromptNameTextBox.Focus();
                return;
            }
            
            if (string.IsNullOrWhiteSpace(PromptTextTextBox.Text))
            {
                MessageBox.Show("Please enter text for the prompt.", 
                              "Missing Text", MessageBoxButton.OK, MessageBoxImage.Warning);
                PromptTextTextBox.Focus();
                return;
            }
            
            // Set the properties
            PromptName = PromptNameTextBox.Text.Trim();
            PromptText = PromptTextTextBox.Text.Trim();
            
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
