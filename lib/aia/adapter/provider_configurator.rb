# lib/aia/adapter/provider_configurator.rb
# frozen_string_literal: true

module AIA
  module Adapter
    class ProviderConfigurator
      def self.configure
        # TODO: Add some of these configuration items to AIA.config
        # Note: RubyLLM supports specific providers. Use provider prefix (e.g., "xai/grok-beta")
        # for providers not directly configured here.
        RubyLLM.configure do |config|
          config.anthropic_api_key  = ENV.fetch('ANTHROPIC_API_KEY', nil)
          config.deepseek_api_key   = ENV.fetch('DEEPSEEK_API_KEY', nil)
          config.gemini_api_key     = ENV.fetch('GEMINI_API_KEY', nil)
          config.gpustack_api_key   = ENV.fetch('GPUSTACK_API_KEY', nil)
          config.mistral_api_key    = ENV.fetch('MISTRAL_API_KEY', nil)
          config.openrouter_api_key = ENV.fetch('OPEN_ROUTER_API_KEY', nil)
          config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', nil)

          # These providers require a little something extra
          config.openai_api_key         = ENV.fetch('OPENAI_API_KEY', nil)
          config.openai_organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)
          config.openai_project_id      = ENV.fetch('OPENAI_PROJECT_ID', nil)

          config.bedrock_api_key       = ENV.fetch('BEDROCK_ACCESS_KEY_ID', nil)
          config.bedrock_secret_key    = ENV.fetch('BEDROCK_SECRET_ACCESS_KEY', nil)
          config.bedrock_region        = ENV.fetch('BEDROCK_REGION', nil)
          config.bedrock_session_token = ENV.fetch('BEDROCK_SESSION_TOKEN', nil)

          # Ollama is based upon the OpenAI API so it needs to over-ride a few things
          config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', nil)

          # --- Custom OpenAI Endpoint ---
          # Use this for Azure OpenAI, proxies, or self-hosted models via OpenAI-compatible APIs.
          # For osaurus: Use model name prefix "osaurus/" and set OSAURUS_API_BASE env var
          # For LM Studio: Use model name prefix "lms/" and set LMS_API_BASE env var
          config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil) # e.g., "https://your-azure.openai.azure.com"

          # --- Connection Settings ---
          config.request_timeout            = 120 # Request timeout in seconds (default: 120)
          config.max_retries                = 3   # Max retries on transient network errors (default: 3)
          config.retry_interval             = 0.1 # Initial delay in seconds (default: 0.1)
          config.retry_backoff_factor       = 2   # Multiplier for subsequent retries (default: 2)
          config.retry_interval_randomness  = 0.5 # Jitter factor (default: 0.5)

          # Configure RubyLLM logger from centralized LoggerManager
          config.log_level = LoggerManager.llm_log_level_symbol
        end

        # Configure RubyLLM's logger output destination
        LoggerManager.configure_llm_logger

        # Configure RubyLLM::MCP's logger early, before any MCP operations
        # This ensures all MCP debug/info logs go to the configured log file
        LoggerManager.configure_mcp_logger
      end
    end
  end
end
