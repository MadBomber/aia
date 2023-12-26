# test/aia/tools/mods_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/tools/mods'


class TestMods < Minitest::Test
  def setup
    # Mocking AIA.config.model and AIA.config.markdown?
    mock_config = mock('config')
    mock_config.stubs(:model).returns('gpt-4')
    mock_config.stubs(:markdown?).returns(true)
    AIA.stubs(:config).returns(mock_config)


    @mods = AIA::Mods.new(
      extra_options:  "",
      text:           "summarize this text",
      files:          []
    )
  end


  def test_initialize
    assert_equal :gen_ai,                   @mods.role
    assert_equal 'AI on the command-line',  @mods.description
    assert_equal 'https://github.com/charmbracelet/mods', @mods.url
    assert_equal "",                    @mods.extra_options
    assert_equal "summarize this text", @mods.text
    assert_equal [],                    @mods.files
  end


  def test_command_with_extra_options
    @mods.extra_options = '--max-tokens 100 --temp 0.7'
    start_text  = "mods --no-limit"
    end_text    = '-f -m gpt-4 --max-tokens 100 --temp 0.7 "summarize this text"'
    
    command = @mods.build_command

    assert command.start_with?(start_text)
    assert command.end_with?(end_text) 
  end


  # FIXME: Need to mock this after changing.
  # def test_run
  #   # Assuming that the `mods` command is installed and correctly configured
  #   # This will actually execute the command, so it should be used with caution or mocked
  #   # Using `send_prompt_to_external_command` method, whichis assumed to exist and just wraps `run`
  #   @mods.text  = "test prompt"
  #   result      = @mods.send_prompt_to_external_command
  #   assert !result.empty?, "Command should produce some output"
  #   # Command output assertions would go here, but this would depend on the actual output of the `mods` command
  #   # This could check for expected format, content, and that it includes certain keywords or structures
  # end
end




