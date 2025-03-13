using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace EloteWindows.Models
{
    public enum ProviderType
    {
        OpenAI,
        Anthropic
    }

    public class LLMProvider
    {
        public ProviderType Type { get; private set; }
        public string DisplayName { get; private set; }
        
        private LLMProvider(ProviderType type, string displayName)
        {
            Type = type;
            DisplayName = displayName;
        }

        // Static provider instances
        public static readonly LLMProvider OpenAI = new LLMProvider(ProviderType.OpenAI, "OpenAI");
        public static readonly LLMProvider Anthropic = new LLMProvider(ProviderType.Anthropic, "Anthropic");

        // Get all available providers
        public static IReadOnlyList<LLMProvider> AllProviders => new List<LLMProvider> { OpenAI, Anthropic };

        // Get provider by type
        public static LLMProvider GetProvider(ProviderType type)
        {
            return type switch
            {
                ProviderType.OpenAI => OpenAI,
                ProviderType.Anthropic => Anthropic,
                _ => throw new ArgumentOutOfRangeException(nameof(type), $"Unknown provider type: {type}")
            };
        }

        // Get provider by name
        public static LLMProvider GetProviderByName(string name)
        {
            foreach (var provider in AllProviders)
            {
                if (provider.DisplayName.Equals(name, StringComparison.OrdinalIgnoreCase))
                {
                    return provider;
                }
            }
            
            // Default to OpenAI if no match
            return OpenAI;
        }

        // Get API endpoint for this provider
        public string GetApiEndpoint()
        {
            return Type switch
            {
                ProviderType.OpenAI => "https://api.openai.com/v1/chat/completions",
                ProviderType.Anthropic => "https://api.anthropic.com/v1/messages",
                _ => throw new ArgumentOutOfRangeException()
            };
        }

        // Get default model for this provider
        public string GetDefaultModel()
        {
            return Type switch
            {
                ProviderType.OpenAI => "gpt-4o",
                ProviderType.Anthropic => "claude-3-haiku-20240307",
                _ => throw new ArgumentOutOfRangeException()
            };
        }

        // Get headers for API request
        public Dictionary<string, string> GetHeaders(string apiKey)
        {
            return Type switch
            {
                ProviderType.OpenAI => new Dictionary<string, string>
                {
                    { "Content-Type", "application/json" },
                    { "Authorization", $"Bearer {apiKey}" }
                },
                ProviderType.Anthropic => new Dictionary<string, string>
                {
                    { "Content-Type", "application/json" },
                    { "anthropic-version", "2023-06-01" },
                    { "x-api-key", apiKey }
                },
                _ => throw new ArgumentOutOfRangeException()
            };
        }

        // Build request body for API call
        public string GetRequestBody(string prompt, string userText, string model = null)
        {
            string modelToUse = model;
            
            // Use default model if none specified
            if (string.IsNullOrWhiteSpace(modelToUse))
            {
                modelToUse = GetDefaultModel();
            }
            
            // Handle common model name variations
            if (Type == ProviderType.OpenAI)
            {
                var lowerModelName = modelToUse.ToLowerInvariant();
                if (lowerModelName == "gpt4" || lowerModelName == "gpt-4o")
                {
                    modelToUse = "gpt-4o";
                }
                else if (lowerModelName.Contains("gpt3.5"))
                {
                    modelToUse = "gpt-3.5-turbo";
                }
            }
            else if (Type == ProviderType.Anthropic)
            {
                var lowerModelName = modelToUse.ToLowerInvariant();
                if (lowerModelName.Contains("claude-2"))
                {
                    modelToUse = "claude-2";
                }
                else if (lowerModelName.Contains("1.3"))
                {
                    modelToUse = "claude-1.3";
                }
                else if (lowerModelName.Contains("3") && !lowerModelName.Contains("-"))
                {
                    modelToUse = "claude-3-haiku-20240307";
                }
            }
            
            // Create request body based on provider
            JObject requestBody = new JObject();
            
            if (Type == ProviderType.OpenAI)
            {
                var messages = new JArray
                {
                    new JObject
                    {
                        ["role"] = "user",
                        ["content"] = $"{prompt} {userText}"
                    }
                };
                
                requestBody["model"] = modelToUse;
                requestBody["messages"] = messages;
                requestBody["max_tokens"] = 4000;
                requestBody["temperature"] = 0.7;
            }
            else if (Type == ProviderType.Anthropic)
            {
                var messages = new JArray
                {
                    new JObject
                    {
                        ["role"] = "user",
                        ["content"] = $"{prompt} {userText}"
                    }
                };
                
                requestBody["model"] = modelToUse;
                requestBody["messages"] = messages;
                requestBody["max_tokens"] = 4000;
                requestBody["temperature"] = 0.7;
            }
            
            return requestBody.ToString(Formatting.None);
        }

        // Extract response from API call data
        public string ExtractResponse(string jsonResponse)
        {
            try
            {
                JObject json = JObject.Parse(jsonResponse);
                
                if (Type == ProviderType.OpenAI)
                {
                    // Check Chat Completion format
                    if (json["choices"] is JArray choices && choices.Count > 0)
                    {
                        JObject firstChoice = (JObject)choices[0];
                        
                        if (firstChoice["message"] is JObject message && message["content"] != null)
                        {
                            return message["content"].ToString();
                        }
                        
                        // Fallback to older text completion
                        if (firstChoice["text"] != null)
                        {
                            return firstChoice["text"].ToString();
                        }
                    }
                }
                else if (Type == ProviderType.Anthropic)
                {
                    // For messages API response format
                    if (json["content"] is JArray content && content.Count > 0)
                    {
                        JObject firstContent = (JObject)content[0];
                        if (firstContent["text"] != null)
                        {
                            return firstContent["text"].ToString();
                        }
                    }
                    
                    // Fallback for older completion API
                    if (json["completion"] != null)
                    {
                        return json["completion"].ToString();
                    }
                }
                
                // Check for errors
                if (json["error"] is JObject error)
                {
                    string errorMessage = "API Error";
                    
                    if (error["message"] != null)
                    {
                        errorMessage = error["message"].ToString();
                    }
                    else if (error["msg"] != null)
                    {
                        errorMessage = error["msg"].ToString();
                    }
                    else if (error["type"] != null)
                    {
                        errorMessage = $"Error type: {error["type"]}";
                    }
                    
                    throw new Exception(errorMessage);
                }
                
                throw new Exception("Failed to parse API response");
            }
            catch (Exception ex)
            {
                throw new Exception($"Error extracting response: {ex.Message}", ex);
            }
        }
    }
}
