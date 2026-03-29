# frozen_string_literal: true
# test/aia/debug_warn_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class DebugWarnTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(debug: false)
    )
    AIA.stubs(:config).returns(@config)
  end

  def test_debug_warn_always_calls_warn
    # Verify it does not raise
    begin
      AIA.debug_warn("test message")
      passed = true
    rescue
      passed = false
    end
    assert passed, "debug_warn should not raise"
  end

  def test_debug_warn_without_exception_does_not_raise
    begin
      AIA.debug_warn("message only")
      passed = true
    rescue
      passed = false
    end
    assert passed, "debug_warn without exception should not raise"
  end

  def test_debug_warn_with_exception_in_debug_mode_does_not_raise
    @config.flags.debug = true
    exc = RuntimeError.new("boom")
    exc.set_backtrace(["file.rb:1:in 'foo'", "file.rb:2:in 'bar'"])
    begin
      AIA.debug_warn("error occurred", exc: exc)
      passed = true
    rescue
      passed = false
    end
    assert passed, "debug_warn with exception in debug mode should not raise"
  end

  def test_debug_warn_without_debug_flag_does_not_raise_with_exception
    @config.flags.debug = false
    exc = RuntimeError.new("boom")
    exc.set_backtrace(["file.rb:1:in 'foo'"])
    begin
      AIA.debug_warn("error occurred", exc: exc)
      passed = true
    rescue
      passed = false
    end
    assert passed, "debug_warn without debug flag should not raise with exception"
  end
end
