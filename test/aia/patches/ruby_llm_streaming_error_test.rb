# frozen_string_literal: true

# test/aia/patches/ruby_llm_streaming_error_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'

class RubyLLMStreamingErrorPatchTest < Minitest::Test
  def setup
    # A bare object carrying the patched Streaming instance methods, the way a
    # provider does via `include Streaming`.
    @provider = Class.new { include RubyLLM::Streaming }.new
  end

  def test_extracts_data_line_from_a_complete_error_chunk
    captured = capture_error_data("event: error\ndata: {\"error\":\"boom\"}\n\n")
    assert_equal '{"error":"boom"}', captured
  end

  def test_extracts_data_line_with_no_space_after_colon
    captured = capture_error_data("event: error\ndata:{\"x\":1}")
    assert_equal '{"x":1}', captured
  end

  # The regression: event and data split across chunks => no data line here.
  # The shipped code did chunk.split("\n")[1].delete_prefix(...) and raised
  # NoMethodError on nil. The patch must not raise and must pass the chunk on.
  def test_does_not_raise_when_data_line_is_in_a_separate_chunk
    captured = capture_error_data("event: error\n")
    assert_equal 'event: error', captured
  end

  private

  # Stub parse_error_from_json (which would otherwise raise a RubyLLM error) and
  # capture the error_data string the patched method extracts and forwards.
  def capture_error_data(chunk)
    captured = :unset
    @provider.stubs(:parse_error_from_json).with do |data, _env, _msg|
      captured = data
      true
    end.returns(nil)

    @provider.send(:handle_error_chunk, chunk, {})
    captured
  end
end
