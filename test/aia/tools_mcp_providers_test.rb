# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'json'
require 'yaml'
require_relative '../../lib/aia'

class McpJsonKeysTest < Minitest::Test
  def parse(name, data)
    Dir.mktmpdir do |dir|
      path = File.join(dir, name)
      File.write(path, JSON.generate(data))
      AIA::McpParser.parse_files([path])
    end
  end

  def test_http_server_without_type_is_streamable_http
    server = parse('docs.json', 'url' => 'https://example.com/mcp', 'headers' => { 'X-Key' => 'k' }).first
    assert_equal 'docs', server[:name]
    assert_equal({ type: 'streamable-http', url: 'https://example.com/mcp', headers: { 'X-Key' => 'k' } }, server[:transport])
  end

  def test_server_settings_are_kept_in_both_forms
    settings = { 'prefix' => 'gh_', 'only' => ['search'], 'except' => ['delete'], 'requires_approval' => true }
    simple = parse('gh.json', { 'command' => %w[github-mcp-server stdio] }.merge(settings)).first
    nested = parse('servers.json', 'mcpServers' => { 'gh' => { 'command' => 'github-mcp-server' }.merge(settings) }).first

    [simple, nested].each do |server|
      assert_equal 'gh_', server[:prefix]
      assert_equal ['search'], server[:only]
      assert_equal ['delete'], server[:except]
      assert_equal true, server[:requires_approval]
      assert_equal 'stdio', server[:transport][:type]
    end
    assert_equal({ type: 'stdio', command: 'github-mcp-server', args: ['stdio'] }, simple[:transport])
  end

  def test_nested_form_accepts_a_command_array
    server = parse('s.json', 'mcpServers' => { 'fs' => { 'command' => %w[npx -y fs], 'args' => ['/tmp'] } }).first
    assert_equal 'npx', server[:transport][:command]
    assert_equal %w[-y fs /tmp], server[:transport][:args]
  end
end

class McpSelectionTest < Minitest::Test
  def test_use_then_skip
    servers = [{ name: 'a' }, { 'name' => 'b' }, { name: 'c' }]
    assert_equal [{ name: 'a' }], AIA::MCPDiscovery.select(servers, use: %w[a b], skip: %w[b])
    assert_equal [{ name: 'a' }, { name: 'c' }], AIA::MCPDiscovery.select(servers, skip: %w[b])
    assert_equal servers, AIA::MCPDiscovery.select(servers)
  end
end

class OllamaEndpointTest < Minitest::Test
  def setup
    @saved = RubyLLM.config.ollama_api_base
    @env = ENV.delete('OLLAMA_API_BASE')
    RubyLLM.config.ollama_api_base = nil
  end

  def teardown
    RubyLLM.config.ollama_api_base = @saved
    @env ? ENV['OLLAMA_API_BASE'] = @env : ENV.delete('OLLAMA_API_BASE')
  end

  def test_defaults_to_localhost
    AIA::ProviderRegistry.apply_env_endpoints
    assert_equal 'http://localhost:11434/v1', RubyLLM.config.ollama_api_base
  end

  def test_environment_variable_wins
    ENV['OLLAMA_API_BASE'] = 'http://gpu-box:11434/v1'
    AIA::ProviderRegistry.apply_env_endpoints
    assert_equal 'http://gpu-box:11434/v1', RubyLLM.config.ollama_api_base
  end

  def test_an_existing_setting_is_kept
    RubyLLM.config.ollama_api_base = 'http://set-in-code:11434/v1'
    AIA::ProviderRegistry.apply_env_endpoints
    assert_equal 'http://set-in-code:11434/v1', RubyLLM.config.ollama_api_base
  end
end

class ImageModelDefaultTest < Minitest::Test
  def test_default_image_model_is_in_the_catalogue
    defaults = YAML.load_file(File.expand_path("../../lib/aia/config/defaults.yml", __dir__), aliases: true)
    model = (defaults["defaults"] || defaults).dig("image", "model")
    assert_equal 'gpt-image-1', model
    refute_nil RubyLLM.models.find(model)
  end
end
