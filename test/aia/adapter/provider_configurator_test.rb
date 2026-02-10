# frozen_string_literal: true

require_relative '../../test_helper'

class ProviderConfiguratorTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, AIA::Adapter::ProviderConfigurator
  end

  def test_responds_to_configure
    assert_respond_to AIA::Adapter::ProviderConfigurator, :configure
  end

  def test_configure_calls_rubyllm_configure
    RubyLLM.expects(:configure).yields(mock_rubyllm_config).once
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.stubs(:configure_llm_logger)
    AIA::LoggerManager.stubs(:configure_mcp_logger)

    AIA::Adapter::ProviderConfigurator.configure
  end

  def test_configure_sets_api_keys_from_env
    original_key = ENV['ANTHROPIC_API_KEY']
    ENV['ANTHROPIC_API_KEY'] = 'test-key-123'

    config_mock = mock_rubyllm_config
    config_mock.expects(:anthropic_api_key=).with('test-key-123')

    RubyLLM.stubs(:configure).yields(config_mock)
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.stubs(:configure_llm_logger)
    AIA::LoggerManager.stubs(:configure_mcp_logger)

    AIA::Adapter::ProviderConfigurator.configure
  ensure
    if original_key
      ENV['ANTHROPIC_API_KEY'] = original_key
    else
      ENV.delete('ANTHROPIC_API_KEY')
    end
  end

  def test_configure_calls_configure_llm_logger
    RubyLLM.stubs(:configure).yields(mock_rubyllm_config)
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.expects(:configure_llm_logger).once
    AIA::LoggerManager.stubs(:configure_mcp_logger)

    AIA::Adapter::ProviderConfigurator.configure
  end

  def test_configure_calls_configure_mcp_logger
    RubyLLM.stubs(:configure).yields(mock_rubyllm_config)
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.stubs(:configure_llm_logger)
    AIA::LoggerManager.expects(:configure_mcp_logger).once

    AIA::Adapter::ProviderConfigurator.configure
  end

  def test_configure_sets_connection_settings
    config_mock = mock_rubyllm_config
    config_mock.expects(:request_timeout=).with(120)
    config_mock.expects(:max_retries=).with(3)

    RubyLLM.stubs(:configure).yields(config_mock)
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.stubs(:configure_llm_logger)
    AIA::LoggerManager.stubs(:configure_mcp_logger)

    AIA::Adapter::ProviderConfigurator.configure
  end

  def test_configure_handles_nil_env_keys
    # Ensure keys that don't exist return nil
    ENV.delete('DEEPSEEK_API_KEY')

    config_mock = mock_rubyllm_config
    config_mock.expects(:deepseek_api_key=).with(nil)

    RubyLLM.stubs(:configure).yields(config_mock)
    AIA::LoggerManager.stubs(:llm_log_level_symbol).returns(:info)
    AIA::LoggerManager.stubs(:configure_llm_logger)
    AIA::LoggerManager.stubs(:configure_mcp_logger)

    AIA::Adapter::ProviderConfigurator.configure
  end

  def teardown
    super
  end

  private

  def mock_rubyllm_config
    config = mock('rubyllm_config')
    # Stub all the config setters
    config.stubs(:anthropic_api_key=)
    config.stubs(:deepseek_api_key=)
    config.stubs(:gemini_api_key=)
    config.stubs(:gpustack_api_key=)
    config.stubs(:mistral_api_key=)
    config.stubs(:openrouter_api_key=)
    config.stubs(:perplexity_api_key=)
    config.stubs(:openai_api_key=)
    config.stubs(:openai_organization_id=)
    config.stubs(:openai_project_id=)
    config.stubs(:bedrock_api_key=)
    config.stubs(:bedrock_secret_key=)
    config.stubs(:bedrock_region=)
    config.stubs(:bedrock_session_token=)
    config.stubs(:ollama_api_base=)
    config.stubs(:openai_api_base=)
    config.stubs(:request_timeout=)
    config.stubs(:max_retries=)
    config.stubs(:retry_interval=)
    config.stubs(:retry_backoff_factor=)
    config.stubs(:retry_interval_randomness=)
    config.stubs(:log_level=)
    config
  end
end
