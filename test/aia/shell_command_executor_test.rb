require 'minitest/autorun'
require 'ostruct'
require_relative '../../lib/aia/shell_command_executor'

class ShellCommandExecutorTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      shell_confirm: true,
      strict_shell_safety: false
    )
    @executor = AIA::ShellCommandExecutor.new(@config)
  end

  def test_initialization
    assert_equal @config, @executor.instance_variable_get(:@config)
  end

  def test_class_factory_method
    executor = AIA::ShellCommandExecutor.with_config(@config)
    assert_instance_of AIA::ShellCommandExecutor, executor
    assert_equal @config, executor.instance_variable_get(:@config)
  end

  def test_class_method_creates_instance
    # Mock the instance method to verify it's called
    instance = mock
    instance.expects(:execute_command).with('echo hello')

    AIA::ShellCommandExecutor.expects(:new).with(@config).returns(instance)
    AIA::ShellCommandExecutor.execute_command('echo hello', @config)
  end

  def test_blank_command
    assert_equal "No command specified", @executor.execute_command(nil)
    assert_equal "No command specified", @executor.execute_command('')
    assert_equal "No command specified", @executor.execute_command('   ')
  end

  def test_command_too_long
    long_command = 'x' * (AIA::ShellCommandExecutor::MAX_COMMAND_LENGTH + 1)
    result = @executor.execute_command(long_command)
    assert_match(/Error: Command too long/, result)
  end

  def test_dangerous_command_detection
    dangerous_commands = [
      'rm -rf /',
      'rm -f important_file',
      'chmod 777 /etc/passwd',
      'dd if=/dev/zero of=/dev/sda',
      'systemctl stop ssh',
      'shutdown now'
    ]

    dangerous_commands.each do |cmd|
      assert @executor.dangerous_command?(cmd), "Failed to detect dangerous command: #{cmd}"
    end

    safe_commands = [
      'ls -la',
      'echo hello',
      'pwd',
      'cat file.txt'
    ]

    safe_commands.each do |cmd|
      refute @executor.dangerous_command?(cmd), "Incorrectly flagged safe command as dangerous: #{cmd}"
    end
  end

  def test_strict_shell_safety_blocks_dangerous_commands
    strict_config = OpenStruct.new(
      shell_confirm: false,
      strict_shell_safety: true
    )
    strict_executor = AIA::ShellCommandExecutor.new(strict_config)

    result = strict_executor.execute_command('rm -f file')
    assert_match(/Error: Potentially dangerous command blocked/, result)
  end

  def test_shell_confirm_prompts_for_dangerous_commands
    # Mock the confirmation prompt to return false (user declines)
    @executor.expects(:prompt_confirmation).returns("Error: Command execution cancelled by user")

    result = @executor.execute_command('rm -f file')
    assert_equal "Error: Command execution cancelled by user", result
  end

  def test_successful_command_execution
    # Only test simple echo commands that won't modify the system
    result = @executor.execute_command('echo hello world')
    assert_equal "hello world", result
  end

  def test_error_handling
    # Test with a command that should produce an error
    result = @executor.execute_command('non_existent_command with args')
    assert_match(/Error executing shell command:/, result)
  end

  def test_config_flag_handling
    # Test with config param
    assert @executor.send(:config_flag?, :shell_confirm)

    # Test with nil config
    nil_executor = AIA::ShellCommandExecutor.new(nil)
    refute nil_executor.send(:config_flag?, :shell_confirm)

    # Test with config that doesn't have the flag
    empty_config = OpenStruct.new
    empty_executor = AIA::ShellCommandExecutor.new(empty_config)
    refute empty_executor.send(:config_flag?, :shell_confirm)
  end
end
