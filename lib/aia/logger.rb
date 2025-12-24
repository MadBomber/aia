# frozen_string_literal: true

# lib/aia/logger.rb
#
# Centralized logger management for AIA using Lumberjack.
# Provides loggers for three systems:
#   - aia: AIA application logging
#   - llm: RubyLLM gem logging
#   - mcp: RubyLLM::MCP gem logging
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
      end

      private

      # Create a logger instance from configuration
      #
      # @param system [Symbol] The system to create a logger for (:aia, :llm, :mcp)
      # @return [Lumberjack::Logger] Configured logger instance
      def create_logger(system)
        config = logger_config_for(system)

        file  = config&.file || 'STDOUT'
        level = effective_log_level(config)
        flush = config&.flush != false  # default to true

        device = create_device(file, flush: flush)
        Lumberjack::Logger.new(
          device,
          level:    LOG_LEVELS.fetch(level, Lumberjack::Severity::WARN),
          progname: system.to_s.upcase
        )
      end

      # Get the effective log level, considering any override
      #
      # @param config [ConfigSection, nil] The logger config for a specific system
      # @return [String] The log level to use
      def effective_log_level(config)
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
