using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using EloteWindows.Models;

namespace EloteWindows.Services
{
    public class LLMProcessResult
    {
        public bool IsSuccess { get; set; }
        public string ProcessedText { get; set; }
        public string Error { get; set; }
    }

    public class LLMService
    {
        private static readonly HttpClient _httpClient = new HttpClient();

        public LLMService()
        {
            // Configure HttpClient timeout
            _httpClient.Timeout = TimeSpan.FromSeconds(60);
        }

        public void ProcessText(string text, Action<LLMProcessResult> callback)
        {
            // Process in background to avoid UI blocking
            Task.Run(async () =>
            {
                var result = new LLMProcessResult();
                
                try
                {
                    // Get the selected provider
                    var providerType = SettingsService.GetSelectedProvider();
                    var provider = LLMProvider.GetProvider(providerType);
                    
                    // Get API key
                    var apiKey = SettingsService.GetApiKey();
                    if (string.IsNullOrWhiteSpace(apiKey))
                    {
                        result.IsSuccess = false;
                        result.Error = "API key is not set. Please set your API key in Settings.";
                        callback(result);
                        return;
                    }
                    
                    // Get prompt
                    string promptText;
                    var selectedPromptId = SettingsService.GetSelectedPromptId();
                    if (selectedPromptId.HasValue)
                    {
                        var prompts = SettingsService.GetPrompts();
                        var selectedPrompt = prompts.Find(p => p.Id == selectedPromptId.Value);
                        promptText = selectedPrompt?.Text ?? SettingsService.GetLastUsedPrompt();
                    }
                    else
                    {
                        promptText = SettingsService.GetLastUsedPrompt();
                    }
                    
                    // Get model to use
                    var customModel = SettingsService.GetCustomModel();
                    
                    // Build request content
                    var requestBody = provider.GetRequestBody(promptText, text, customModel);
                    var content = new StringContent(requestBody, Encoding.UTF8, "application/json");
                    
                    // Set headers
                    var request = new HttpRequestMessage(HttpMethod.Post, provider.GetApiEndpoint());
                    request.Content = content;
                    
                    foreach (var header in provider.GetHeaders(apiKey))
                    {
                        request.Headers.TryAddWithoutValidation(header.Key, header.Value);
                    }
                    
                    // Send request
                    var response = await _httpClient.SendAsync(request);
                    
                    // Process response
                    if (response.IsSuccessStatusCode)
                    {
                        var responseContent = await response.Content.ReadAsStringAsync();
                        var extractedText = provider.ExtractResponse(responseContent);
                        
                        result.IsSuccess = true;
                        result.ProcessedText = extractedText;
                    }
                    else
                    {
                        var errorContent = await response.Content.ReadAsStringAsync();
                        result.IsSuccess = false;
                        result.Error = $"API Error ({(int)response.StatusCode}): {errorContent}";
                    }
                }
                catch (Exception ex)
                {
                    result.IsSuccess = false;
                    result.Error = $"Error: {ex.Message}";
                }
                
                // Call the callback on the UI thread
                App.Current.Dispatcher.Invoke(() => callback(result));
            });
        }
    }
}
