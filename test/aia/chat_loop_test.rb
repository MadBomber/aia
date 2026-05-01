# test/aia/chat_loop_test.rb
#
# Tests for AIA::ChatLoop, focusing on the conversation context preservation
# fix described in Issue #152.

require_relative '../test_helper'
require 'ostruct'
require_relative '../../lib/aia'

class ChatLoopRoleContextTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      prompts: OpenStruct.new(
        role:          nil,
        skills:        [],
        skills_prefix: 'skills'
      ),
      models:        [OpenStruct.new(name: 'gpt-5.4')],
      skills:        OpenStruct.new(dir: '/tmp/skills'),
      context_files: []
    )

    @mock_client = mock('client')

    AIA.stubs(:config).returns(@config)
    AIA.stubs(:client).returns(@mock_client)

    @mock_chat_processor = mock('chat_processor')
    @mock_ui_presenter   = mock('ui_presenter')
    @mock_directive_proc = mock('directive_processor')

    @chat_loop = AIA::ChatLoop.new(
      @mock_chat_processor,
      @mock_ui_presenter,
      @mock_directive_proc
    )
  end

  def teardown
    super
  end

  # ---------------------------------------------------------------------------
  # process_role_context — baseline behaviour
  # ---------------------------------------------------------------------------

  def test_process_role_context_returns_early_when_no_role_configured
    @config.prompts.role = nil
    AIA::PromptHandler.expects(:new).never
    @chat_loop.send(:process_role_context)
  end

  def test_process_role_context_returns_early_when_role_is_empty_string
    @config.prompts.role = ''
    AIA::PromptHandler.expects(:new).never
    @chat_loop.send(:process_role_context)
  end

  def test_process_role_context_adds_system_message_to_chats
    @config.prompts.role = 'helpful_assistant'

    mock_role    = OpenStruct.new(to_s: 'You are a helpful assistant.')
    mock_handler = mock('prompt_handler')
    mock_handler.stubs(:fetch_role).with('helpful_assistant').returns(mock_role)
    AIA::PromptHandler.stubs(:new).returns(mock_handler)

    mock_chat = mock('chat')
    mock_chat.stubs(:messages).returns([])
    mock_chat.expects(:add_message).with { |msg| msg.is_a?(RubyLLM::Message) && msg.role == :system }
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    @chat_loop.send(:process_role_context)
  end

  def test_process_role_context_skips_chat_that_already_has_system_message
    @config.prompts.role = 'helpful_assistant'

    mock_role    = OpenStruct.new(to_s: 'You are a helpful assistant.')
    mock_handler = mock('prompt_handler')
    mock_handler.stubs(:fetch_role).with('helpful_assistant').returns(mock_role)
    AIA::PromptHandler.stubs(:new).returns(mock_handler)

    existing_system = RubyLLM::Message.new(role: :system, content: 'Already set.')
    mock_chat = mock('chat')
    mock_chat.stubs(:messages).returns([existing_system])
    mock_chat.expects(:add_message).never
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    @chat_loop.send(:process_role_context)
  end

  # ---------------------------------------------------------------------------
  # process_role_context — model preservation fix (Issue #152)
  # ---------------------------------------------------------------------------

  def test_process_role_context_restores_models_after_fetch_role_side_effect
    # A role file with `model: claude-3-5-sonnet` in its YAML front matter
    # causes fetch_role → apply_metadata_config to overwrite AIA.config.models.
    # process_role_context must restore the user's original model choice so
    # maybe_change_model cannot later destroy the active chat session.
    @config.prompts.role = 'assistant_role'
    @config.models = [OpenStruct.new(name: 'gpt-5.4')]

    # Fake handler that mimics apply_metadata_config writing a different model
    fake_handler = Object.new
    mock_role    = OpenStruct.new(to_s: 'You are an assistant.')
    fake_handler.define_singleton_method(:fetch_role) do |_role_id|
      AIA.config.models = [OpenStruct.new(name: 'claude-3-5-sonnet')]  # side-effect
      mock_role
    end
    AIA::PromptHandler.stubs(:new).returns(fake_handler)

    mock_chat = mock('chat')
    mock_chat.stubs(:messages).returns([])
    mock_chat.stubs(:add_message)
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    @chat_loop.send(:process_role_context)

    assert_equal 'gpt-5.4', @config.models.first.name,
      'process_role_context must restore AIA.config.models after fetch_role changes it'
  end

  def test_process_role_context_model_restoration_prevents_context_loss
    # Full scenario: pipeline ran with gpt-5.4, chat loop starts, role file
    # sets models to Claude. Without the fix, maybe_change_model would see a
    # mismatch and destroy the pipeline history. Verify models are back to
    # gpt-5.4 after process_role_context so downstream code sees the right model.
    @config.prompts.role = 'my_role'
    @config.models = [OpenStruct.new(name: 'gpt-5.4')]

    fake_handler = Object.new
    mock_role    = OpenStruct.new(to_s: 'Act as a coding expert.')
    fake_handler.define_singleton_method(:fetch_role) do |_role_id|
      AIA.config.models = [OpenStruct.new(name: 'claude-opus-4')]
      mock_role
    end
    AIA::PromptHandler.stubs(:new).returns(fake_handler)

    user_msg = mock('pipeline_user_msg')
    asst_msg = mock('pipeline_asst_msg')
    user_msg.stubs(:role).returns(:user)
    asst_msg.stubs(:role).returns(:assistant)

    mock_chat = mock('chat')
    mock_chat.stubs(:messages).returns([user_msg, asst_msg])
    mock_chat.stubs(:add_message)
    @mock_client.stubs(:chats).returns({ 'gpt-5.4' => mock_chat })

    @chat_loop.send(:process_role_context)

    # AIA.config.models must match the adapter's model so maybe_change_model
    # will not fire and destroy the pipeline history.
    assert_equal 'gpt-5.4', @config.models.first.name
  end
end
