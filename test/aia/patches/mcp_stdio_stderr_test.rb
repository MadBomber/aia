# frozen_string_literal: true

# test/aia/patches/mcp_stdio_stderr_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require 'tmpdir'

class MCPStdioStderrTest < Minitest::Test
  Patch = AIA::MCPStdioStderr

  def test_blank_setting_uses_default_log_file
    Dir.mktmpdir do |home|
      with_home(home) do
        path, mode = Patch.spawn_target(nil)

        assert_equal File.join(home, '.config/aia/logs/mcp_servers.log'), path
        assert_equal 'a', mode
        assert File.directory?(File.dirname(path)), 'creates the log directory'
      end
    end
  end

  def test_stderr_setting_inherits_parent_stderr
    assert_nil Patch.spawn_target('STDERR')
    assert_nil Patch.spawn_target('stderr')
  end

  def test_null_settings_discard
    %w[null none /dev/null NULL].each do |setting|
      assert_equal [File::NULL, 'w'], Patch.spawn_target(setting), setting
    end
  end

  def test_file_setting_expands_and_appends
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'nested', 'servers.log')

      assert_equal [target, 'a'], Patch.spawn_target(target)
      assert File.directory?(File.join(dir, 'nested'))
    end
  end

  def test_unwritable_location_falls_back_to_discard
    FileUtils.stubs(:mkdir_p).raises(Errno::EACCES)

    assert_equal [File::NULL, 'w'], Patch.spawn_target('/nope/servers.log')
  end

  def test_spawn_options_adds_err_and_keeps_existing
    assert_equal({ chdir: '/x', err: ['/l', 'a'] }, Patch.spawn_options({ chdir: '/x' }, ['/l', 'a']))
  end

  def test_spawn_options_without_target_is_unchanged
    assert_equal({ chdir: '/x' }, Patch.spawn_options({ chdir: '/x' }, nil))
  end

  def test_reads_setting_from_config
    AIA.stubs(:config).returns(OpenStruct.new(logger: OpenStruct.new(mcp: OpenStruct.new(server_stderr: 'STDERR'))))

    assert_nil Patch.spawn_target
  end

  def test_install_is_applied_to_ruby_llm_stdio
    assert_includes RubyLLM::MCP::Stdio.ancestors, AIA::MCPStdioStderr::StdioPatch
    assert_equal RubyLLM::MCP::Stdio, Patch.install!, 'idempotent re-install'
    assert_equal 1, RubyLLM::MCP::Stdio.ancestors.count(AIA::MCPStdioStderr::StdioPatch)
  end

  def test_install_skips_class_without_start
    assert_nil Patch.install!(Class.new)
    assert_nil Patch.install!(nil)
  end

  # End to end: a real Stdio-launched child's stderr goes to the file,
  # while its stdout still reaches the transport.
  def test_child_stderr_lands_in_log_file
    Dir.mktmpdir do |dir|
      log = File.join(dir, 'servers.log')
      Patch.stubs(:configured_setting).returns(log)

      stdio = RubyLLM::MCP::Stdio.new(['ruby', '-e', '$stderr.write "server noise\n"; $stdout.write "ok\n"'])
      stdio.send(:start)
      out = stdio.instance_variable_get(:@stdout).read
      stdio.instance_variable_get(:@process).join
      stdio.send(:stop)

      assert_equal "ok\n", out
      assert_includes File.read(log), 'server noise'
    end
  end

  private

  def with_home(home)
    original = Dir.home
    ENV['HOME'] = home
    yield
  ensure
    ENV['HOME'] = original
  end
end
