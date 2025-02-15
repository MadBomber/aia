require 'test_helper'

class AIA::CliTest < Minitest::Test
  def setup
    @cli = AIA::Cli.new([])
  end

  def test_initialize
    assert_instance_of AIA::Cli, @cli
  end

  def test_convert_pathname_objects!
    assert_kind_of Array, @cli.convert_pathname_objects!
  end

  def test_error_on_invalid_option_combinations
    assert_silent { @cli.error_on_invalid_option_combinations }
  end

  def test_string_to_pathname
    result = @cli.string_to_pathname('~/test')
    assert_instance_of Pathname, result
  end

  def test_pathname_to_string
    result = @cli.pathname_to_string(Pathname.new('test'))
    assert_equal 'test', result
  end

  def test_load_env_options
    assert_kind_of Array, @cli.load_env_options
  end

  def test_replace_erb_in_config_file
    assert_raises(TypeError) { @cli.replace_erb_in_config_file }
  end

  def test_load_config_file
    assert_raises(TypeError) { @cli.load_config_file }
  end

  def test_setup_options_with_defaults
    assert_kind_of Hash, @cli.setup_options_with_defaults([])
  end

  def test_arguments
    assert_kind_of Array, @cli.arguments
  end

  def test_execute_immediate_commands
    assert_nil @cli.execute_immediate_commands
  end

  def test_dump_config_file
    assert_raises(TypeError) { @cli.dump_config_file }
  end

  def test_prepare_config_as_hash
    result = @cli.prepare_config_as_hash
    assert_instance_of Hash, result
  end

  def test_process_command_line_arguments
    assert_nil @cli.process_command_line_arguments
  end

  def test_check_for_chat
    assert_equal ["--chat"], @cli.check_for(:chat?)
  end

  def test_check_for_role_parameter
    assert_nil @cli.check_for_role_parameter
  end

  def test_invoke_fzf_to_choose_role
    assert_raises(NameError) { @cli.invoke_fzf_to_choose_role }
  end

  def test_show_error_usage
    assert_nil @cli.show_error_usage
  end

  def test_show_usage
    assert_raises(SystemExit) { @cli.show_usage }
  end

  def test_show_completion
    assert_raises(SystemExit) { @cli.show_completion }
  end

  def test_show_version
    assert_raises(SystemExit) { @cli.show_version }
  end

  def test_setup_prompt_manager
    assert_kind_of PromptManager::Storage::FileSystemAdapter, @cli.setup_prompt_manager
  end

  def test_parse_config_file
    assert_raises(NoMethodError) { @cli.parse_config_file }
  end
end
