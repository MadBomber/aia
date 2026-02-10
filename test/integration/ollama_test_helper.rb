# test/integration/ollama_test_helper.rb
#
# Shared setup for integration tests that use Ollama as the LLM provider.
# These tests require a running Ollama instance with the gpt-oss:latest model.

require_relative '../test_helper'
require 'net/http'
require 'json'
require 'ostruct'

module OllamaTestHelper
  OLLAMA_BASE    = 'http://localhost:11434'
  OLLAMA_API_BASE = "#{OLLAMA_BASE}/v1"
  OLLAMA_MODEL   = 'ollama/gpt-oss:latest'

  def self.ollama_available?
    response = Net::HTTP.get_response(URI("#{OLLAMA_BASE}/api/tags"))
    return false unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    models = data['models']&.map { |m| m['name'] } || []
    models.include?('gpt-oss:latest')
  rescue StandardError
    false
  end

  # Configure AIA with a single Ollama model and no MCP
  def setup_ollama_single_model
    skip 'Ollama not available or gpt-oss:latest not installed' unless OllamaTestHelper.ollama_available?

    ENV['OLLAMA_API_BASE'] = OLLAMA_API_BASE

    AIA.config = AIA::Config.setup(no_mcp: true)
    AIA.config.models = AIA::Config::TO_MODEL_SPECS.call([{ name: OLLAMA_MODEL }])
    AIA.config.context_files = []
    AIA.config.output.file = nil
    AIA.config.flags.verbose = false
    AIA.config.flags.speak = false
    AIA.config.flags.tokens = false
    AIA.config.flags.consensus = false

    AIA.client = AIA::RubyLLMAdapter.new
  end

  # Configure AIA with two instances of the same Ollama model
  def setup_ollama_multi_model
    skip 'Ollama not available or gpt-oss:latest not installed' unless OllamaTestHelper.ollama_available?

    ENV['OLLAMA_API_BASE'] = OLLAMA_API_BASE

    AIA.config = AIA::Config.setup(no_mcp: true)
    AIA.config.models = AIA::Config::TO_MODEL_SPECS.call([
      { name: OLLAMA_MODEL },
      { name: OLLAMA_MODEL }
    ])
    AIA.config.context_files = []
    AIA.config.output.file = nil
    AIA.config.flags.verbose = false
    AIA.config.flags.speak = false
    AIA.config.flags.tokens = false
    AIA.config.flags.consensus = false

    AIA.client = AIA::RubyLLMAdapter.new
  end
end
