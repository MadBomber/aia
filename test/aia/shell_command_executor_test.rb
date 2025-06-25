require 'minitest/autorun'
require 'ostruct'
require_relative '../test_helper'
require_relative '../../lib/aia'

class ShellCommandExecutorTest < Minitest::Test
  def setup
    @executor = AIA::ShellCommandExecutor.new
    
    # Define stub methods for AIA module if they don't exist
    unless AIA.respond_to?(:strict_shell_safety?)
      AIA.define_singleton_method(:strict_shell_safety?) { @strict_shell_safety || false }
    end
    
    unless AIA.respond_to?(:shell_confirm?)
      AIA.define_singleton_method(:shell_confirm?) { @shell_confirm || false }
    end
    
    # Set default values
    @strict_shell_safety = false
    @shell_confirm = false
  end

  def test_initialization
    assert_instance_of AIA::ShellCommandExecutor, @executor
  end

  def test_class_method_creates_instance
    result = AIA::ShellCommandExecutor.execute_command('echo test')
    assert_instance_of String, result
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
    # Temporarily override the method behavior
    original_method = AIA.method(:strict_shell_safety?)
    AIA.define_singleton_method(:strict_shell_safety?) { true }
    
    result = @executor.execute_command('rm -f file')
    assert_match(/Error: Potentially dangerous command blocked/, result)
    
    # Restore original method
    AIA.define_singleton_method(:strict_shell_safety?, &original_method)
  end

  def test_shell_confirm_prompts_for_dangerous_commands
    # Temporarily override the method behavior
    original_confirm = AIA.method(:shell_confirm?)
    original_strict = AIA.method(:strict_shell_safety?)
    
    AIA.define_singleton_method(:shell_confirm?) { true }
    AIA.define_singleton_method(:strict_shell_safety?) { false }
    
    # Mock the confirmation prompt to return cancellation
    @executor.stub(:prompt_confirmation, "Command execution canceled by user") do
      result = @executor.execute_command('rm -f file')
      assert_equal "Command execution canceled by user", result
    end
    
    # Restore original methods
    AIA.define_singleton_method(:shell_confirm?, &original_confirm)
    AIA.define_singleton_method(:strict_shell_safety?, &original_strict)
  end

  def test_successful_command_execution
    result = @executor.execute_command('echo hello world')
    assert_equal "hello world", result
  end

  def test_error_handling
    result = @executor.execute_command('non_existent_command_that_should_fail_12345')
    assert_match(/Error executing shell command:/, result)
  end
end