# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia'

class OpenAIParameterNormalizerTest < Minitest::Test
  NormalizingProvider = Class.new(RubyLLM::Provider) do
    def initialize
    end

    def slug
      'openai'
    end

    def render_payload(_messages, tools:, temperature:, model:, stream:, schema:, thinking:, tool_prefs:)
      { model: model.id, stream: stream }
    end

    def sync_response(_connection, payload, _headers)
      payload
    end
  end

  def test_normalizes_max_tokens_for_openai_gpt_5
    model = OpenStruct.new(id: 'gpt-5.4')
    params = { max_tokens: 2048, top_p: 1.0 }

    result = AIA::OpenAIParameterNormalizer.normalize(params, model, openai_provider)

    refute_includes result, :max_tokens
    assert_equal 2048, result[:max_completion_tokens]
    assert_equal 1.0, result[:top_p]
  end

  def test_normalizes_max_tokens_when_completion_tokens_already_present
    model = OpenStruct.new(id: 'gpt-5.4')
    params = { max_tokens: 2048, max_completion_tokens: 4096 }

    result = AIA::OpenAIParameterNormalizer.normalize(params, model, openai_provider)

    refute_includes result, :max_tokens
    assert_equal 4096, result[:max_completion_tokens]
  end

  def test_leaves_non_openai_params_unchanged
    model = OpenStruct.new(id: 'gpt-5.4')
    params = { max_tokens: 2048 }

    result = AIA::OpenAIParameterNormalizer.normalize(params, model, provider('anthropic'))

    assert_equal params, result
  end

  def test_provider_patch_normalizes_params_before_completion
    model = OpenStruct.new(id: 'gpt-5.4')
    payload = NormalizingProvider.new.complete(
      [],
      tools: {},
      temperature: nil,
      model: model,
      params: { max_tokens: 2048 },
      headers: {}
    )

    refute_includes payload, :max_tokens
    assert_equal 2048, payload[:max_completion_tokens]
  end

  private
    def openai_provider
      provider('openai')
    end

    def provider(slug)
      OpenStruct.new(slug: slug)
    end
end
