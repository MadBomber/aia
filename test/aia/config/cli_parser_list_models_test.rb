# frozen_string_literal: true

# test/aia/config/cli_parser_list_models_test.rb
#
# `aia --provider SLUG --list-models` — live per-provider model listing
# through RubyLLM's provider API, generic over any registered provider.
#
# NOTE: test_helper suppresses Kernel#exit during the run, so these tests
# assert on output and dispatch rather than SystemExit.

require_relative '../../test_helper'
require 'ostruct'

class CLIParserListModelsTest < Minitest::Test
  def test_handle_list_models_is_a_noop_without_the_flag
    AIA::CLIParser.expects(:list_provider_models).never

    assert_nil AIA::CLIParser.send(:handle_list_models, { provider: 'lms' })
  end

  def test_handle_list_models_requires_a_provider
    AIA::CLIParser.expects(:list_provider_models).never

    _out, err = capture_io do
      AIA::CLIParser.send(:handle_list_models, { list_models: true })
    end

    assert_match(/--list-models requires --provider SLUG/, err)
  end

  def test_handle_list_models_dispatches_to_the_given_provider
    AIA::CLIParser.expects(:list_provider_models).with('lms').once

    AIA::CLIParser.send(:handle_list_models, { list_models: true, provider: 'lms' })
  end

  def test_handle_list_models_loads_require_libs_first
    AIA::CLIParser.expects(:require_listed_libs).once
    AIA::CLIParser.expects(:list_provider_models).with('xyzzy').once

    AIA::CLIParser.send(:handle_list_models,
                        { list_models: true, provider: 'xyzzy', require_libs: ['ruby_llm-providers-xyzzy'] })
  end

  def test_list_provider_models_prints_each_model
    stub_provider_listing('lms', %w[gpt-oss-20b qwen3.8-27b])

    out, _err = capture_io do
      AIA::CLIParser.send(:list_provider_models, 'lms')
    end

    assert_match(/lms models:/, out)
    assert_includes out, '- lms/gpt-oss-20b'
    assert_includes out, '- lms/qwen3.8-27b'
    assert_match(/2 lms model\(s\) available/, out)
  end

  def test_list_provider_models_rejects_unknown_provider
    AIA::ProviderRegistry.stubs(:available?).with('nope').returns(false)
    AIA::ProviderRegistry.expects(:instantiate).never

    _out, err = capture_io do
      AIA::CLIParser.send(:list_provider_models, 'nope')
    end

    assert_match(/unknown provider 'nope'/, err)
    assert_match(/Registered providers:/, err)
  end

  def test_list_provider_models_reports_provider_errors
    AIA::ProviderRegistry.stubs(:available?).with('lms').returns(true)
    AIA::ProviderRegistry.stubs(:instantiate).with('lms').raises(StandardError.new('connection refused'))

    _out, err = capture_io do
      AIA::CLIParser.send(:list_provider_models, 'lms')
    end

    assert_match(/cannot list models for provider 'lms'/, err)
    assert_match(/connection refused/, err)
  end

  def test_require_listed_libs_warns_on_load_error_without_raising
    _out, err = capture_io do
      AIA::CLIParser.send(:require_listed_libs, { require_libs: ['no_such_lib_xyzzy'] })
    end

    assert_match(/Failed to require 'no_such_lib_xyzzy'/, err)
  end

  def test_parse_handles_flags_in_either_order
    stub_provider_listing('lms', %w[some-model])

    [%w[--provider lms --list-models], %w[--list-models --provider lms]].each do |argv|
      with_argv(argv) do
        out, _err = capture_io { AIA::CLIParser.parse }

        assert_includes out, '- lms/some-model', "failed for ARGV: #{argv.inspect}"
      end
    end
  end

  private

  def stub_provider_listing(slug, model_ids)
    provider = mock("provider_#{slug}")
    provider.stubs(:list_models).returns(model_ids.map { |id| OpenStruct.new(id: id) })
    AIA::ProviderRegistry.stubs(:available?).with(slug).returns(true)
    AIA::ProviderRegistry.stubs(:instantiate).with(slug).returns(provider)
  end

  def with_argv(argv)
    original = ARGV.dup
    ARGV.replace(argv)
    yield
  ensure
    ARGV.replace(original)
  end
end
