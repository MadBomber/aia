require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class PromptHandlerTest < Minitest::Test
  def setup
    # Mock AIA module methods to prevent actual operations
    AIA.stubs(:config).returns(OpenStruct.new(
                                 models: [OpenStruct.new(name: 'test-model')],
                                 llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
                                 flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
                                 tools: OpenStruct.new(paths: []),
                                 context_files: [],
                                 prompts: OpenStruct.new(
                                   dir: '/tmp/test_prompts',
                                   extname: '.md',
                                   roles_dir: '/tmp/test_prompts/roles',
                                   roles_prefix: 'roles',
                                   role: nil,
                                   parameter_regex: '\\{\\{\\w+\\}\\}'
                                 ),
                                 prompt_id: 'test_prompt'
                               ))

    @handler = AIA::PromptHandler.new
  end

  # PM's shell/erb settings are global; restore its defaults for other tests.
  def teardown
    PM.configure do |c|
      c.shell = true
      c.erb   = true
    end
  end

  def test_config_flags_become_prompt_manager_defaults
    refute PM.config.shell
    refute PM.config.erb
  end

  # --- mode: front matter ---

  def test_mode_for_names_the_chat_directives_without_the_slash
    assert_equal :debate,         AIA::PromptHandler.mode_for('debate')
    assert_equal :verify,         AIA::PromptHandler.mode_for(' Verify ')
    assert_equal :concurrent_mcp, AIA::PromptHandler.mode_for('concurrent')
    assert_equal :orchestrate,    AIA::PromptHandler.mode_for(:orchestrate)
  end

  def test_mode_for_rejects_a_name_that_is_not_a_mode
    error = assert_raises(AIA::ConfigurationError) { AIA::PromptHandler.mode_for('argue') }
    assert_match(/Unknown mode: "argue"/, error.message)
    assert_match(/concurrent, debate, decompose/, error.message)
  end

  def test_mode_front_matter_requests_that_mode_for_the_turn
    AIA.turn_state = AIA::TurnState.new
    metadata = mock('metadata')
    metadata.stubs(:to_h).returns({ 'mode' => 'debate' })

    @handler.apply_metadata_config(OpenStruct.new(metadata: metadata))

    assert_equal :debate, AIA.turn_state.active_mode
  end

  def test_front_matter_without_mode_leaves_the_turn_state_alone
    AIA.turn_state = AIA::TurnState.new
    metadata = mock('metadata')
    metadata.stubs(:to_h).returns({ 'temperature' => 0.2 })

    @handler.apply_metadata_config(OpenStruct.new(metadata: metadata))

    assert_nil AIA.turn_state.active_mode
  end

  def test_flag_enabled_unless_explicitly_false
    assert AIA::PromptHandler.flag_enabled?(OpenStruct.new(shell: true), :shell)
    assert AIA::PromptHandler.flag_enabled?(OpenStruct.new(shell: nil), :shell)
    refute AIA::PromptHandler.flag_enabled?(OpenStruct.new(erb: false), :erb)
    assert AIA::PromptHandler.flag_enabled?(nil, :erb)
  end

  def test_initialization
    # Test basic initialization
    assert_instance_of AIA::PromptHandler, @handler
  end

  def test_basic_functionality
    # Test that handler has expected methods
    assert_respond_to @handler, :fetch_prompt
    assert_respond_to @handler, :fetch_role
  end

  def test_handler_with_valid_config
    # Test that handler works with valid configuration
    handler = AIA::PromptHandler.new
    assert_instance_of AIA::PromptHandler, handler
  end

  def test_handler_methods_exist
    # Test that core methods exist and are callable
    handler = AIA::PromptHandler.new

    # These methods should exist
    assert handler.respond_to?(:fetch_prompt)
    assert handler.respond_to?(:fetch_role)
  end
end
