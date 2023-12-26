# lib/aia/logging.rb

require 'logger'

class AIA::Logging
  attr_accessor :logger

  def initialize(log_file_path)
    @logger = if log_file_path
                Logger.new(
                  log_file_path,  # path/to/file
                  'weekly',       # rotation interval
                  'a'             # append to existing file
                )
              else
                Logger.new(STDOUT) # Fall back to standard output if path is nil or invalid
              end

    configure_logger
  end

  def prompt_result(prompt, result)
    logger.info( <<~EOS
      PROMPT ID #{prompt.id}
      PATH:     #{prompt.path}
      KEYWORDS: #{prompt.keywords.join(', ')}
        
        #{prompt.to_s}

      RESULT:
      #{result}


    EOS
    )
  rescue StandardError => e
    logger.error("Failed to log the result. Error: #{e.message}")
  end


  def debug(msg)    = logger.debug(msg)
  def info(msg)     = logger.info(msg)
  def warn(msg)     = logger.warn(msg)
  def error(msg)    = logger.error(msg)
  def fatal(msg)    = logger.fatal(msg)

  private

  def configure_logger
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      formatted_datetime = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "[#{formatted_datetime}] #{severity}: #{msg}\n"
    end
    @logger.level = Logger::DEBUG
  end
end



