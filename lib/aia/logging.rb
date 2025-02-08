# lib/aia/logging.rb

require 'logger'
require 'fileutils'

class AIA::Logging
  attr_accessor :logger

  def initialize(log_file_path)
    if log_file_path
      # Ensure the directory for the log file exists
      FileUtils.mkdir_p(File.dirname(log_file_path))
      @logger = Logger.new(
        log_file_path,  # path/to/file
        'weekly',       # rotation interval
        'a'             # append mode
      )
    else
      @logger = Logger.new(STDOUT)
    end

    configure_logger
  end

  def prompt_result(result)
    logger.info result
  end

  def debug(msg)    = logger.debug(msg)
  def info(msg)     = logger.info(msg)
  def warn(msg)     = logger.warn(msg)
  def error(msg)    = logger.error(msg)
  def fatal(msg)    = logger.fatal(msg)

  private

  def configure_logger
    @logger.formatter = proc do |severity, datetime, progname, msg|
      date_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "[#{date_format}] #{severity}: #{msg}\n"
    end
  end
end

#
# Provides structured logging capabilities for the AIA system
#
# This class implements a comprehensive logging system that:
# - Supports multiple log levels (DEBUG, INFO, WARN, ERROR, FATAL)
# - Handles log rotation (weekly)
# - Formats log entries with timestamps
# - Provides special handling for prompt/result logging
#
# The logger can write to files or STDOUT and includes safeguards
# against common logging failures.
#
