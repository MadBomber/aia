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
  
  def test_command_with_special_characters
    # Test commands with quotes and special characters
    result = @executor.execute_command('echo "hello world"')
    assert_equal "hello world", result
    
    result = @executor.execute_command("echo 'single quotes'")
    assert_equal "single quotes", result
  end
  
  def test_command_with_pipes_and_redirects
    # Test that pipes work correctly
    result = @executor.execute_command('echo "line1\nline2" | head -1')
    assert_equal "line1", result
    
    # Test command substitution
    result = @executor.execute_command('echo "Current directory: $(pwd)"')
    assert_match(/Current directory:/, result)
  end
  
  def test_multiline_output_handling
    # Use printf instead of echo -e for better cross-platform compatibility
    result = @executor.execute_command('printf "line1\nline2\nline3"')
    lines = result.split("\n")
    assert_equal 3, lines.size
    assert_equal "line1", lines[0]
    assert_equal "line2", lines[1]
    assert_equal "line3", lines[2]
  end
  
  def test_command_timeout_simulation
    # Test a command that should execute quickly
    start_time = Time.now
    result = @executor.execute_command('sleep 0.1 && echo "completed"')
    duration = Time.now - start_time
    
    assert_equal "completed", result
    assert duration < 1.0  # Should complete well under 1 second
  end
  
  def test_dangerous_command_patterns_comprehensive
    # Test various dangerous patterns
    dangerous_patterns = [
      'rm -rf *',
      'rm -rf /',  # This is what the actual implementation checks for
      'chmod 777 /etc/passwd',
      'mkfs.ext4 /dev/sda1',
      'dd if=/dev/zero of=/dev/sda',
      'systemctl disable firewall',
      'systemctl stop ssh',
      'halt',
      'reboot',
      'halt',
      'poweroff',
      'kill -9 -1',
      'kill -9 -1',
      'pkill chrome',
      'tcpdump -i eth0'
    ]
    
    dangerous_patterns.each do |pattern|
      assert @executor.dangerous_command?(pattern), "Should detect dangerous pattern: #{pattern}"
    end
  end
  
  def test_safe_command_patterns_comprehensive
    safe_patterns = [
      'ls -la .',
      'cat README.md',
      'grep "pattern" file.txt',
      'find . -name "*.rb"',
      'head -10 logfile.txt',
      'tail -f application.log',
      'wc -l *.txt',
      'sort data.csv',
      'uniq sorted_data.txt',
      'cut -d, -f1 data.csv',
      'awk "{print $1}" file.txt',
      'sed "s/old/new/g" file.txt',
      'ps aux | grep ruby',
      'df -h',
      'du -sh *',
      'whoami',
      'id',
      'date',
      'uname -a'
    ]
    
    safe_patterns.each do |pattern|
      refute @executor.dangerous_command?(pattern), "Should not flag safe pattern as dangerous: #{pattern}"
    end
  end
  
  def test_command_length_boundary_conditions
    # Test at exact boundary
    boundary_command = 'x' * AIA::ShellCommandExecutor::MAX_COMMAND_LENGTH
    result = @executor.execute_command(boundary_command)
    # Should not error on length, but command will fail to execute
    assert_match(/Error executing shell command:/, result)
    
    # Test just over boundary
    over_boundary = 'x' * (AIA::ShellCommandExecutor::MAX_COMMAND_LENGTH + 1)
    result = @executor.execute_command(over_boundary)
    assert_match(/Error: Command too long/, result)
  end
  
  def test_whitespace_handling
    # Test command with leading/trailing whitespace
    result = @executor.execute_command('  echo hello  ')
    assert_equal "hello", result
    
    # Test command with tabs
    result = @executor.execute_command("\techo\ttab\ttest\t")
    assert_equal "tab test", result
  end
  
  def test_environment_variable_expansion
    # Test that environment variables work
    result = @executor.execute_command('echo $HOME')
    assert_match(/\//, result)  # Should contain path separators
    
    # Test with custom environment variable
    result = @executor.execute_command('TEST_VAR=hello && echo $TEST_VAR')
    assert_equal "hello", result
  end
  
  def test_prompt_confirmation_edge_cases
    # Test that prompt_confirmation method exists and handles input
    # Since the method actually calls gets which we can't easily mock,
    # we'll test the dangerous command blocking instead
    original_confirm = AIA.method(:shell_confirm?) if AIA.respond_to?(:shell_confirm?)
    original_strict = AIA.method(:strict_shell_safety?) if AIA.respond_to?(:strict_shell_safety?)
    
    AIA.define_singleton_method(:shell_confirm?) { true }
    AIA.define_singleton_method(:strict_shell_safety?) { false }
    
    # Mock the confirmation to return cancel
    @executor.stub(:prompt_confirmation, "Command execution canceled by user") do
      result = @executor.execute_command('rm -f file')
      assert_equal "Command execution canceled by user", result
    end
    
    # Restore original methods
    AIA.define_singleton_method(:shell_confirm?, &original_confirm) if original_confirm
    AIA.define_singleton_method(:strict_shell_safety?, &original_strict) if original_strict
  end
  
  def test_class_and_instance_method_equivalence
    test_command = 'echo "class vs instance"'
    
    class_result = AIA::ShellCommandExecutor.execute_command(test_command)
    instance_result = @executor.execute_command(test_command)
    
    # Both should produce the same result
    assert_equal class_result, instance_result
    assert_equal "class vs instance", class_result
  end
end