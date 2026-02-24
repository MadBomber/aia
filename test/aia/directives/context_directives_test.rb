# test/aia/directives/context_directives_test.rb

require_relative '../../test_helper'
require 'ostruct'
require 'stringio'

class ContextDirectivesTest < Minitest::Test
  def setup
    @original_stdout = $stdout
    @captured_output = StringIO.new
    $stdout = @captured_output

    @instance = AIA::ContextDirectives.new

    # Create mock chats with messages
    @mock_message = RubyLLM::Message.new(
      role: :user,
      content: "Hello world"
    )
    @mock_assistant_msg = RubyLLM::Message.new(
      role: :assistant,
      content: "Hi there!"
    )
    @mock_system_msg = RubyLLM::Message.new(
      role: :system,
      content: "You are a helpful assistant"
    )

    @mock_chat = mock('chat')
    @mock_chat.stubs(:messages).returns([@mock_system_msg, @mock_message, @mock_assistant_msg])
    @mock_chat.stubs(:add_message)

    @mock_client = mock('client')
    @mock_client.stubs(:chat).returns(@mock_chat)
    @mock_client.stubs(:respond_to?).with(:name).returns(true)
    @mock_client.stubs(:name).returns('gpt-4o')
    @mock_client.stubs(:messages).returns([@mock_system_msg, @mock_message, @mock_assistant_msg])
    @mock_client.stubs(:clear_messages)
    @mock_client.stubs(:replace_messages)
    AIA.stubs(:client).returns(@mock_client)
  end

  def teardown
    $stdout = @original_stdout
    super
  end

  # --- /checkpoint ---

  def test_checkpoint_creates_auto_named_checkpoint
    result = @instance.checkpoint([])
    assert_equal "", result
    assert_equal 1, @instance.checkpoint_store.size
    assert @instance.checkpoint_store.key?("1")
    output = @captured_output.string
    assert_includes output, "Checkpoint '1' created"
  end

  def test_checkpoint_creates_named_checkpoint
    result = @instance.checkpoint(['my_save'])
    assert_equal "", result
    assert @instance.checkpoint_store.key?("my_save")
    output = @captured_output.string
    assert_includes output, "Checkpoint 'my_save' created"
  end

  def test_checkpoint_increments_counter
    @instance.checkpoint([])
    @instance.checkpoint([])
    assert_equal 2, @instance.checkpoint_counter
    assert @instance.checkpoint_store.key?("1")
    assert @instance.checkpoint_store.key?("2")
  end

  def test_checkpoint_stores_message_data
    @instance.checkpoint(['test'])
    data = @instance.checkpoint_store['test']
    refute_nil data[:messages]
    refute_nil data[:position]
    refute_nil data[:created_at]
    assert_equal 3, data[:position]
  end

  def test_checkpoint_error_when_no_chats
    AIA.stubs(:client).returns(nil)
    result = @instance.checkpoint([])
    assert_includes result, "Error: No active chat sessions found."
  end

  # --- /checkpoint aliases ---

  def test_ckp_alias_exists
    assert_equal @instance.method(:checkpoint).original_name,
                 @instance.method(:ckp).original_name
  end

  def test_cp_alias_exists
    assert_equal @instance.method(:checkpoint).original_name,
                 @instance.method(:cp).original_name
  end

  # --- /restore ---

  def test_restore_with_no_checkpoints
    result = @instance.restore([])
    assert_includes result, "Error: No previous checkpoint"
  end

  def test_restore_nonexistent_name
    @instance.checkpoint(['alpha'])
    result = @instance.restore(['beta'])
    assert_includes result, "Error: Checkpoint 'beta' not found"
    assert_includes result, "Available: alpha"
  end

  def test_restore_named_checkpoint
    @instance.checkpoint(['save1'])
    result = @instance.restore(['save1'])
    assert_includes result, "Context restored to checkpoint 'save1'"
  end

  def test_restore_error_when_no_chats
    @instance.checkpoint(['save1'])
    AIA.stubs(:client).returns(nil)
    result = @instance.restore(['save1'])
    assert_includes result, "Error: No active chat sessions found."
  end

  # --- /clear ---

  def test_clear_resets_context
    @instance.checkpoint(['save1'])

    result = @instance.clear([])
    assert_equal "Chat context cleared.", result
    assert_empty @instance.checkpoint_store
    assert_equal 0, @instance.checkpoint_counter
    assert_nil @instance.last_checkpoint_name
  end

  def test_clear_keeps_system_prompt_by_default
    @mock_client.expects(:clear_messages).with(keep_system: true)
    @instance.clear([])
  end

  def test_clear_removes_system_prompt_with_all_flag
    @mock_client.expects(:clear_messages).with(keep_system: false)
    @instance.clear(['--all'])
  end

  def test_clear_error_when_no_chats
    AIA.stubs(:client).returns(nil)
    result = @instance.clear([])
    assert_includes result, "Error: No active chat sessions found."
  end

  # --- /review ---

  def test_review_displays_messages
    result = @instance.review([])
    assert_equal "", result
    output = @captured_output.string
    assert_includes output, "Chat Context (RubyLLM)"
    assert_includes output, "Total messages: 3"
    assert_includes output, "gpt-4o"
  end

  def test_review_shows_checkpoint_markers
    @instance.checkpoint(['before_question'])
    @captured_output.truncate(0)
    @captured_output.rewind

    @instance.review([])
    output = @captured_output.string
    assert_includes output, "Checkpoints: before_question"
  end

  def test_review_error_when_no_chats
    AIA.stubs(:client).returns(nil)
    result = @instance.review([])
    assert_includes result, "Error: No active chat sessions found."
  end

  # --- /context alias ---

  def test_context_alias_exists
    assert_equal @instance.method(:review).original_name,
                 @instance.method(:context).original_name
  end

  # --- /checkpoints_list ---

  def test_checkpoints_list_empty
    result = @instance.checkpoints_list([])
    assert_equal "", result
    output = @captured_output.string
    assert_includes output, "No checkpoints available."
  end

  def test_checkpoints_list_shows_all
    @instance.checkpoint(['alpha'])
    @instance.checkpoint(['beta'])
    @captured_output.truncate(0)
    @captured_output.rewind

    result = @instance.checkpoints_list([])
    assert_equal "", result
    output = @captured_output.string
    assert_includes output, "Available Checkpoints"
    assert_includes output, "alpha:"
    assert_includes output, "beta:"
  end

  # --- /checkpoints alias ---

  def test_checkpoints_alias_exists
    assert_equal @instance.method(:checkpoints_list).original_name,
                 @instance.method(:checkpoints).original_name
  end

  # --- helper methods ---

  def test_checkpoint_names_returns_keys
    @instance.checkpoint(['a'])
    @instance.checkpoint(['b'])
    assert_equal ['a', 'b'], @instance.checkpoint_names
  end

  def test_reset_clears_all_state
    @instance.checkpoint(['test'])
    @instance.reset!
    assert_empty @instance.checkpoint_store
    assert_equal 0, @instance.checkpoint_counter
    assert_nil @instance.last_checkpoint_name
  end
end
