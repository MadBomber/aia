# test/aia/directives/configuration_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'

class ConfigurationDirectivesTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    @test_config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil, instance: 1, internal_id: 'gpt-4o-mini')],
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        roles_prefix: 'roles'
      ),
      flags: OpenStruct.new(
        debug: false,
        verbose: false,
        consensus: nil
      ),
      llm: OpenStruct.new(
        temperature: 0.7,
        top_p: 0.9
      )
    )
    AIA.stubs(:config).returns(@test_config)

    @instance = AIA::ConfigurationDirectives.new

    @stderr_messages = []
    @instance.stubs(:warn).with { |msg| @stderr_messages << msg; true }
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # --- /config with no args ---

  def test_config_no_args_lists_all_config
    result = @instance.config([])
    assert_equal "", result
    # amazing_print outputs to stdout
    output = @captured_output.string
    refute_empty output
  end

  # --- /config with one arg ---

  def test_config_single_arg_shows_value
    result = @instance.config(['llm'])
    assert_equal "", result
    output = @captured_output.string
    refute_empty output
  end

  def test_config_single_arg_unknown_key_shows_nil
    result = @instance.config(['nonexistent_key'])
    assert_equal "", result
    output = @captured_output.string
    refute_empty output
  end

  # --- /config with key and value ---

  def test_config_sets_value
    # OpenStruct responds to any setter, so this should set the value
    result = @instance.config(['llm', 'new_value'])
    assert_equal "", result
  end

  def test_config_sets_boolean_value_true
    # AIA has a debug? method, so 'debug' is treated as boolean
    result = @instance.config(['debug', 'true'])
    assert_equal "", result
  end

  def test_config_sets_boolean_value_false
    # AIA has a verbose? method, so 'verbose' is treated as boolean
    result = @instance.config(['verbose', 'no'])
    assert_equal "", result
  end

  def test_config_unknown_option_warns
    # Use a Struct-based config that does NOT respond to arbitrary setters
    strict_config = Struct.new(:models, :prompts, :flags, :llm, keyword_init: true).new(
      models: [], prompts: nil, flags: nil, llm: nil
    )
    AIA.stubs(:config).returns(strict_config)

    @instance.config(['bogus', 'value'])
    assert @stderr_messages.any? { |m| m.include?("Unknown config option 'bogus'") }
  end

  # --- /cfg alias ---

  def test_cfg_alias_exists
    assert_equal @instance.method(:config).original_name,
                 @instance.method(:cfg).original_name
  end

  # --- /temperature ---

  def test_temperature_delegates_to_config
    # temperature prepends 'temperature' to args and calls config
    @instance.expects(:config).with(['temperature', '0.5'], nil)
    @instance.temperature(['0.5'])
  end

  def test_temp_alias_exists
    assert_equal @instance.method(:temperature).original_name,
                 @instance.method(:temp).original_name
  end

  # --- /top_p ---

  def test_top_p_delegates_to_config
    @instance.expects(:config).with(['top_p', '0.8'], nil)
    @instance.top_p(['0.8'])
  end

  def test_topp_alias_exists
    assert_equal @instance.method(:top_p).original_name,
                 @instance.method(:topp).original_name
  end
end
