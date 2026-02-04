require_relative '../test_helper'

class LoggerManagerTest < Minitest::Test
  def setup
    # Test mode is already enabled in test_helper.rb
  end

  def test_log_levels_constant
    assert_equal Lumberjack::Severity::DEBUG, AIA::LoggerManager::LOG_LEVELS['debug']
    assert_equal Lumberjack::Severity::INFO,  AIA::LoggerManager::LOG_LEVELS['info']
    assert_equal Lumberjack::Severity::WARN,  AIA::LoggerManager::LOG_LEVELS['warn']
    assert_equal Lumberjack::Severity::ERROR, AIA::LoggerManager::LOG_LEVELS['error']
    assert_equal Lumberjack::Severity::FATAL, AIA::LoggerManager::LOG_LEVELS['fatal']
  end

  def test_log_levels_frozen
    assert AIA::LoggerManager::LOG_LEVELS.frozen?
  end

  def test_test_mode_enabled
    assert AIA::LoggerManager.test_mode?
  end

  def test_aia_logger_exists
    logger = AIA::LoggerManager.aia_logger
    assert_kind_of Lumberjack::Logger, logger
  end

  def test_llm_logger_exists
    logger = AIA::LoggerManager.llm_logger
    assert_kind_of Lumberjack::Logger, logger
  end

  def test_mcp_logger_exists
    logger = AIA::LoggerManager.mcp_logger
    assert_kind_of Lumberjack::Logger, logger
  end

  def test_test_entries_captures_logs
    AIA::LoggerManager.clear_test_logs!
    AIA::LoggerManager.aia_logger.info("test message from aia")

    entries = AIA::LoggerManager.test_entries(:aia)
    assert entries.any? { |e| e.message.include?("test message from aia") }
  end

  def test_test_entries_by_system
    AIA::LoggerManager.clear_test_logs!
    AIA::LoggerManager.aia_logger.info("aia log")
    AIA::LoggerManager.llm_logger.info("llm log")
    AIA::LoggerManager.mcp_logger.info("mcp log")

    aia_entries = AIA::LoggerManager.test_entries(:aia)
    llm_entries = AIA::LoggerManager.test_entries(:llm)
    mcp_entries = AIA::LoggerManager.test_entries(:mcp)

    assert aia_entries.any? { |e| e.message.include?("aia log") }
    assert llm_entries.any? { |e| e.message.include?("llm log") }
    assert mcp_entries.any? { |e| e.message.include?("mcp log") }
  end

  def test_test_entries_raises_for_unknown_system
    assert_raises(ArgumentError) do
      AIA::LoggerManager.test_entries(:unknown)
    end
  end

  def test_last_test_entry
    AIA::LoggerManager.clear_test_logs!
    AIA::LoggerManager.aia_logger.info("first")
    AIA::LoggerManager.aia_logger.info("second")

    last = AIA::LoggerManager.last_test_entry(:aia)
    assert_equal "second", last.message
  end

  def test_last_test_entry_nil_when_empty
    AIA::LoggerManager.clear_test_logs!
    last = AIA::LoggerManager.last_test_entry(:aia)
    assert_nil last
  end

  def test_clear_test_logs
    AIA::LoggerManager.aia_logger.info("something")
    AIA::LoggerManager.clear_test_logs!

    entries = AIA::LoggerManager.test_entries(:aia)
    assert_empty entries
  end

  def test_resolve_log_file_io_stdout
    result = AIA::LoggerManager.resolve_log_file_io('STDOUT')
    assert_equal $stdout, result
  end

  def test_resolve_log_file_io_stderr
    result = AIA::LoggerManager.resolve_log_file_io('STDERR')
    assert_equal $stderr, result
  end

  def test_resolve_log_file_io_case_insensitive
    assert_equal $stdout, AIA::LoggerManager.resolve_log_file_io('stdout')
    assert_equal $stderr, AIA::LoggerManager.resolve_log_file_io('Stderr')
  end

  def test_resolve_log_file_io_file_path
    result = AIA::LoggerManager.resolve_log_file_io('/tmp/test.log')
    assert_equal '/tmp/test.log', result
  end

  def test_resolve_log_file_io_expands_path
    result = AIA::LoggerManager.resolve_log_file_io('~/test.log')
    assert_equal File.expand_path('~/test.log'), result
  end

  def test_reset_clears_loggers
    # Save test mode state
    was_test_mode = AIA::LoggerManager.test_mode?

    AIA::LoggerManager.reset!
    refute AIA::LoggerManager.test_mode?

    # Restore test mode for other tests
    AIA::LoggerManager.test_mode!(level: :debug)
  end

  def test_test_mode_bang_creates_all_loggers
    AIA::LoggerManager.test_mode!(level: :debug)

    assert_kind_of Lumberjack::Logger, AIA::LoggerManager.aia_logger
    assert_kind_of Lumberjack::Logger, AIA::LoggerManager.llm_logger
    assert_kind_of Lumberjack::Logger, AIA::LoggerManager.mcp_logger
    assert AIA::LoggerManager.test_mode?
  end

  def test_test_mode_with_custom_level
    AIA::LoggerManager.test_mode!(level: :warn)
    assert AIA::LoggerManager.test_mode?
    # Restore default
    AIA::LoggerManager.test_mode!(level: :debug)
  end

end
