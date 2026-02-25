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

  # --- /cost ---

  def test_cost_no_tracker
    AIA.stubs(:session_tracker).returns(nil)
    result = @instance.cost
    assert_equal '', result
    assert_match(/No session tracker/, @captured_output.string)
  end

  def test_cost_no_turns
    tracker = AIA::SessionTracker.new
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    result = @instance.cost
    assert_equal '', result
    assert_match(/No turns recorded/, @captured_output.string)
  end

  def test_cost_outputs_csv_with_header
    tracker = AIA::SessionTracker.new
    tracker.instance_variable_get(:@turns) << {
      model: 'gpt-4o-mini',
      input_tokens: 100,
      output_tokens: 50,
      tokens: 150,
      cost: 0.00025,
      elapsed: 2.3,
      timestamp: Time.now
    }
    tracker.instance_variable_get(:@turns) << {
      model: 'claude-sonnet-4',
      input_tokens: 200,
      output_tokens: 80,
      tokens: 280,
      cost: 0.001,
      elapsed: 4.1,
      timestamp: Time.now
    }
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    result = @instance.cost
    assert_equal '', result

    output = @captured_output.string
    lines = output.strip.split("\n")

    assert_equal 'model,input_tokens,output_tokens,total_tokens,cost,elapsed', lines[0]
    assert_match(/^gpt-4o-mini,100,50,150,/, lines[1])
    assert_match(/^claude-sonnet-4,200,80,280,/, lines[2])
    assert_match(/^TOTAL,300,130,430,/, lines[3])
  end

  def test_cost_outputs_elapsed_times
    tracker = AIA::SessionTracker.new
    tracker.instance_variable_get(:@turns) << {
      model: 'gpt-4o-mini',
      input_tokens: 100,
      output_tokens: 50,
      tokens: 150,
      cost: 0.0,
      elapsed: 12.5,
      timestamp: Time.now
    }
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    @instance.cost
    output = @captured_output.string

    assert_match(/12\.5s/, output)
  end

  def test_cost_skips_model_switch_events
    tracker = AIA::SessionTracker.new
    tracker.instance_variable_get(:@turns) << {
      type: :model_switch,
      from: 'gpt-4o-mini',
      to: 'claude-sonnet-4',
      timestamp: Time.now
    }
    tracker.instance_variable_get(:@turns) << {
      model: 'claude-sonnet-4',
      input_tokens: 200,
      output_tokens: 80,
      tokens: 280,
      cost: 0.001,
      elapsed: 3.0,
      timestamp: Time.now
    }
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    @instance.cost
    lines = @captured_output.string.strip.split("\n")

    # Header + 1 data row + TOTAL = 3 lines (model_switch skipped)
    assert_equal 3, lines.size
    assert_match(/^claude-sonnet-4/, lines[1])
  end

  def test_cost_includes_similarity_column_when_present
    tracker = AIA::SessionTracker.new
    tracker.instance_variable_get(:@turns) << {
      model: 'claude-sonnet-4',
      input_tokens: 100,
      output_tokens: 50,
      tokens: 150,
      cost: 0.001,
      elapsed: 2.0,
      similarity: nil,
      timestamp: Time.now
    }
    tracker.instance_variable_get(:@turns) << {
      model: 'gpt-4o-mini',
      input_tokens: 200,
      output_tokens: 80,
      tokens: 280,
      cost: 0.0005,
      elapsed: 3.0,
      similarity: 0.856,
      timestamp: Time.now
    }
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    @instance.cost
    lines = @captured_output.string.strip.split("\n")

    assert_match(/similarity$/, lines[0], "Header should include similarity column")
    assert_match(/ref$/, lines[1], "Reference model should show 'ref'")
    assert_match(/85\.6%$/, lines[2], "Second model should show similarity percentage")
    assert_match(/,$/, lines[3], "TOTAL row should have empty similarity")
  end

  def test_cost_omits_similarity_column_when_not_present
    tracker = AIA::SessionTracker.new
    tracker.instance_variable_get(:@turns) << {
      model: 'gpt-4o-mini',
      input_tokens: 100,
      output_tokens: 50,
      tokens: 150,
      cost: 0.0,
      elapsed: 1.0,
      timestamp: Time.now
    }
    AIA.stubs(:session_tracker).returns(tracker)
    @test_config.stubs(:output).returns(OpenStruct.new(file: nil))

    @instance.cost
    lines = @captured_output.string.strip.split("\n")

    refute_match(/similarity/, lines[0], "Header should not include similarity for single-model")
  end
end
