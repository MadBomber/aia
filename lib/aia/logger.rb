# frozen_string_literal: true

# lib/aia/logger.rb
#
# Centralized logger management for AIA using Lumberjack.
# Provides loggers for three systems:
#   - aia: Used within the AIA codebase for application-level logging
#   - llm: Passed to RubyLLM gem's configuration (RubyLLM.logger)
#   - mcp: Passed to RubyLLM::MCP process (RubyLLM::MCP.logger)
#
# Configuration is read from AIA.config.logger section:
#   logger:
#     aia:
#       file: STDOUT
#       level: warn
#     llm:
#       file: STDOUT
#       level: warn
#     mcp:
#       file: STDOUT
#       level: warn
#
# Lumberjack provides structured logging, context isolation,
# automatic log file rolling, and multi-process safe file writes.
#
# For testing, use test_mode! to switch to Lumberjack's :test device:
#   AIA::LoggerManager.test_mode!
#   # ... run tests ...
#   AIA::LoggerManager.clear_test_logs!  # between tests
#   entries = AIA::LoggerManager.aia_logger.device.entries  # inspect logs

require 'lumberjack'

module AIA
  module LoggerManager
    # Log level mapping from config strings to Lumberjack severity constants
    LOG_LEVELS = {
      'debug' => Lumberjack::Severity::DEBUG,
      'info'  => Lumberjack::Severity::INFO,
      'warn'  => Lumberjack::Severity::WARN,
      'error' => Lumberjack::Severity::ERROR,
      'fatal' => Lumberjack::Severity::FATAL
    }.freeze

    class << self
      # Track whether we're in test mode
      attr_accessor :test_mode

      # Get or create the AIA application logger
      #
      # @return [Lumberjack::Logger] The AIA logger instance
      def aia_logger
        @aia_logger ||= create_logger(:aia)
      end

      # Get or create the RubyLLM logger
      #
      # @return [Lumberjack::Logger] The LLM logger instance
      def llm_logger
        @llm_logger ||= create_logger(:llm)
      end

      # Get or create the RubyLLM::MCP logger
      #
      # @return [Lumberjack::Logger] The MCP logger instance
      def mcp_logger
        @mcp_logger ||= create_logger(:mcp)
      end

      # Configure RubyLLM's logger
      def configure_llm_logger
        return unless defined?(RubyLLM)

        logger = llm_logger
        RubyLLM.logger = logger if RubyLLM.respond_to?(:logger=)
      end

      # Configure RubyLLM::MCP's logger
      def configure_mcp_logger
        return unless defined?(RubyLLM::MCP)

        logger = mcp_logger
        if RubyLLM::MCP.respond_to?(:logger=)
          RubyLLM::MCP.logger = logger
        elsif RubyLLM::MCP.respond_to?(:logger)
          # Some versions only allow setting level on existing logger
          RubyLLM::MCP.logger.level = logger.level
        end
      end

      # Get the log level symbol for RubyLLM configuration
      #
      # @return [Symbol] The log level as a symbol (e.g., :warn, :debug)
      def llm_log_level_symbol
        config = logger_config_for(:llm)
        level = effective_log_level(config)
        level.to_sym
      end

      # Reset all cached loggers (useful for testing or reconfiguration)
      def reset!
        @aia_logger = nil
        @llm_logger = nil
        @mcp_logger = nil
        @test_mode = false
      end

      # =======================================================================
      # Test Mode Support
      # =======================================================================
      # Use Lumberjack's :test device to capture log entries in memory
      # for assertions in tests.

      # Enable test mode - all loggers will use Lumberjack's :test device
      # which captures entries in memory for inspection and assertions.
      #
      # @param level [Symbol, String] Log level for test loggers (default: :debug)
      def test_mode!(level: :debug)
        reset!
        @test_mode = true
        @test_level = LOG_LEVELS.fetch(level.to_s, Lumberjack::Severity::DEBUG)

        # Pre-create loggers with test devices
        @aia_logger = create_test_logger(:aia)
        @llm_logger = create_test_logger(:llm)
        @mcp_logger = create_test_logger(:mcp)

        # Surface logging errors in tests instead of swallowing them
        Lumberjack.raise_logger_errors = true
      end

      # Check if test mode is enabled
      #
      # @return [Boolean] true if in test mode
      def test_mode?
        @test_mode == true
      end

      # Clear all test log entries (call between tests)
      def clear_test_logs!
        return unless test_mode?

        [@aia_logger, @llm_logger, @mcp_logger].each do |logger|
          logger&.device&.clear if logger&.device.respond_to?(:clear)
        end
      end

      # Get all entries from a specific test logger
      #
      # @param system [Symbol] The logger to get entries from (:aia, :llm, :mcp)
      # @return [Array<Lumberjack::LogEntry>] Array of log entries
      def test_entries(system = :aia)
        logger = case system
                 when :aia then aia_logger
                 when :llm then llm_logger
                 when :mcp then mcp_logger
                 else raise ArgumentError, "Unknown logger: #{system}"
                 end

        return [] unless logger&.device.respond_to?(:entries)

        logger.device.entries
      end

      # Get the last entry from a specific test logger
      #
      # @param system [Symbol] The logger to get entry from (:aia, :llm, :mcp)
      # @return [Lumberjack::LogEntry, nil] The last log entry or nil
      def last_test_entry(system = :aia)
        test_entries(system).last
      end

      private

      # Create a test logger with Lumberjack's :test device
      #
      # @param system [Symbol] The system name for progname
      # @return [Lumberjack::Logger] Logger with test device
      def create_test_logger(system)
        Lumberjack::Logger.new(
          :test,
          level: @test_level || Lumberjack::Severity::DEBUG,
          progname: system.to_s.upcase
        )
      end

      # Create a logger instance from configuration
      #
      # @param system [Symbol] The system to create a logger for (:aia, :llm, :mcp)
      # @return [Lumberjack::Logger] Configured logger instance
      def create_logger(system)
        config = logger_config_for(system)

        file  = effective_log_file(config)
        level = effective_log_level(config, system)
        flush = config&.flush != false  # default to true

        device = create_device(file, flush: flush)
        Lumberjack::Logger.new(
          device,
          level:    LOG_LEVELS.fetch(level, Lumberjack::Severity::WARN),
          progname: system.to_s.upcase
        )
      end

      # Get the effective log file, considering any override
      #
      # @param config [ConfigSection, nil] The logger config for a specific system
      # @return [String] The log file path or STDOUT/STDERR
      def effective_log_file(config)
        # CLI override (--log-to) takes precedence over per-system config
        override = AIA.config&.log_file_override
        return override if override && !override.to_s.empty?

        config&.file || 'STDOUT'
      end

      # Get the effective log level, considering any override
      #
      # @param config [ConfigSection, nil] The logger config for a specific system
      # @return [String] The log level to use
      def effective_log_level(config, _system = nil)
        # CLI override takes precedence over per-system config
        override = AIA.config&.log_level_override
        return override.to_s.downcase if override && !override.to_s.empty?

        config&.level&.to_s&.downcase || 'warn'
      end

      # Create appropriate Lumberjack device based on file config
      #
      # @param file [String] The file config value
      # @param flush [Boolean] If true, flush immediately (no buffering)
      # @return [Lumberjack::Device] The device instance
      def create_device(file, flush: true)
        # buffer_size: 0 means immediate flush (no buffering)
        buffer_size = flush ? 0 : 8192

        case file.to_s.upcase
        when 'STDOUT'
          Lumberjack::Device::Writer.new($stdout, buffer_size: buffer_size)
        when 'STDERR'
          Lumberjack::Device::Writer.new($stderr, buffer_size: buffer_size)
        else
          path = File.expand_path(file)
          # Use date rolling for file-based logs
          # Multiple loggers can safely write to the same file
          Lumberjack::Device::DateRollingLogFile.new(
            path,
            roll: :daily,
            buffer_size: buffer_size
          )
        end
      end

      # Get the logger configuration for a specific system
      #
      # @param system [Symbol] The system (:aia, :llm, :mcp)
      # @return [ConfigSection, nil] The configuration section
      def logger_config_for(system)
        return nil unless AIA.config&.logger

        case system
        when :aia then AIA.config.logger.aia
        when :llm then AIA.config.logger.llm
        when :mcp then AIA.config.logger.mcp
        end
      rescue NoMethodError
        nil
      end
    end
  end
end
