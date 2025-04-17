require_relative '../test_helper'
require 'ostruct'
require 'tempfile'
require_relative '../../lib/aia'

class ConfigTest < Minitest::Test
  def setup
    @default_config = AIA::Config::DEFAULT_CONFIG
  end

  def test_no_prompt_id_provided
    args = []

    # We need to capture output from STDERR constant, not just $stderr
    stderr_output = capture_constant_stderr do
      # This will call exit, but our test_helper has overridden exit
      # so it won't actually terminate the test
      AIA::Config.parse(args)
    end

    # Check that an error message about missing prompt ID was printed
    assert_match(/prompt id is required/i, stderr_output, "Expected error message about missing prompt ID")
  end

  def test_parse_command_line_arguments
    args = ['--model', 'custom-model', '--chat']
    config = AIA::Config.parse(args)
    assert_equal 'custom-model', config[:model], "Expected model to be 'custom-model'"
    assert_equal true, config[:chat], "Expected chat to be true"
    assert config.prompt_id.nil? || config.prompt_id.empty?, "Expected prompt_id to be nil or empty"
  end

  def test_parse_environment_variables
    ENV['AIA_MODEL'] = 'env-model'
    config = AIA::Config.parse([])
    assert_equal 'env-model', config.model
  ensure
    ENV.delete('AIA_MODEL')
  end

  # Helper method to capture output from the STDERR constant
  def capture_constant_stderr
    old_stderr = STDERR.dup
    io = Tempfile.new("stderr")
    STDERR.reopen(io.path, "w")

    yield

    STDERR.reopen(old_stderr)
    io.rewind
    output = io.read
    io.close
    io.unlink

    output
  end
end
