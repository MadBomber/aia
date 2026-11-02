# frozen_string_literal: true

# test/aia/config/cli_parser_list_providers_test.rb
#
# `aia --list-providers` — list every RubyLLM-registered provider and exit.
#
# NOTE: test_helper suppresses Kernel#exit during the run, so these tests
# assert on output and dispatch rather than SystemExit.

require_relative '../../test_helper'

class CLIParserListProvidersTest < Minitest::Test
  def test_handle_list_providers_is_a_noop_without_the_flag
    AIA::CLIParser.expects(:list_available_providers).never

    assert_nil AIA::CLIParser.send(:handle_list_providers, {})
  end

  def test_handle_list_providers_loads_require_libs_first
    AIA::CLIParser.expects(:require_listed_libs).once
    AIA::CLIParser.expects(:list_available_providers).once

    AIA::CLIParser.send(:handle_list_providers,
                        { list_providers: true, require_libs: ['ruby_llm-providers-xyzzy'] })
  end

  def test_list_available_providers_prints_registered_slugs_and_count
    out, _err = capture_io do
      AIA::CLIParser.send(:list_available_providers)
    end

    assert_match(/Registered RubyLLM providers:/, out)
    assert_includes out, '- openai'
    assert_includes out, '- anthropic'
    assert_match(/\d+ provider\(s\) registered/, out)
  end

  def test_list_available_providers_marks_local_providers
    out, _err = capture_io do
      AIA::CLIParser.send(:list_available_providers)
    end

    assert_includes out, '- ollama (local)'
  end

  def test_list_available_providers_marks_api_key_availability
    AIA::CLIParser.stubs(:provider_api_key?).returns(false)
    AIA::CLIParser.stubs(:provider_api_key?).with('anthropic').returns(true)

    out, _err = capture_io do
      AIA::CLIParser.send(:list_available_providers)
    end

    assert_includes out, '- anthropic (has API key)'
    refute_includes out, '- openai (has API key)'
  end

  def test_provider_entry_combines_local_and_api_key_markers
    klass = mock('provider_class')
    klass.stubs(:local?).returns(true)
    AIA::CLIParser.stubs(:provider_api_key?).with('foo').returns(true)

    assert_equal '- foo (local) (has API key)', AIA::CLIParser.send(:provider_entry, 'foo', klass)
  end

  def test_provider_api_key_detects_conventional_env_var
    original = ENV.fetch('OLLAMA_API_KEY', nil)
    ENV['OLLAMA_API_KEY'] = 'secret'

    assert AIA::CLIParser.send(:provider_api_key?, 'ollama')
  ensure
    original ? ENV['OLLAMA_API_KEY'] = original : ENV.delete('OLLAMA_API_KEY')
  end

  def test_provider_api_key_detects_ruby_llm_config_value
    original_env = ENV.fetch('OLLAMA_API_KEY', nil)
    ENV.delete('OLLAMA_API_KEY')
    original = RubyLLM.config.ollama_api_key
    RubyLLM.config.ollama_api_key = 'secret'

    assert AIA::CLIParser.send(:provider_api_key?, 'ollama')
  ensure
    RubyLLM.config.ollama_api_key = original
    ENV['OLLAMA_API_KEY'] = original_env if original_env
  end

  def test_provider_api_key_is_false_without_config_or_env
    original_env = ENV.fetch('OLLAMA_API_KEY', nil)
    ENV.delete('OLLAMA_API_KEY')
    original = RubyLLM.config.ollama_api_key
    RubyLLM.config.ollama_api_key = nil

    refute AIA::CLIParser.send(:provider_api_key?, 'ollama')
  ensure
    RubyLLM.config.ollama_api_key = original
    ENV['OLLAMA_API_KEY'] = original_env if original_env
  end

  def test_list_available_providers_includes_installed_but_unloaded_provider_gems
    skip 'ruby_llm-providers-lms gem not in this bundle' unless
      AIA::ProviderRegistry.installed_gem_slugs.include?('lms')

    out, _err = capture_io do
      AIA::CLIParser.send(:list_available_providers)
    end

    assert_match(/^- lms/, out)
  end

  def test_installed_gem_slugs_returns_conventional_gem_suffixes
    slugs = AIA::ProviderRegistry.installed_gem_slugs

    assert_kind_of Array, slugs
    refute_includes slugs, 'ruby_llm' # only ruby_llm-providers-* gems, suffix only
  end

  def test_parse_handles_the_flag
    with_argv(['--list-providers']) do
      out, _err = capture_io { AIA::CLIParser.parse }

      assert_includes out, '- openai'
    end
  end

  private

  def with_argv(argv)
    original = ARGV.dup
    ARGV.replace(argv)
    yield
  ensure
    ARGV.replace(original)
  end
end
