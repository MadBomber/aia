# test/aia/logging_test.rb

require 'ostruct'

require_relative  '../test_helper'

require 'logging'

class LoggingTest < Minitest::Test
  def setup
    @log_file_path = 'test.log'
    File.delete(@log_file_path) if File.exist?(@log_file_path)

    # Use an instance variable to store our Logging instance
    @logging = AIA::Logging.new(@log_file_path)
  end


  def teardown
    # Clean up log file after tests
    File.delete(@log_file_path) if File.exist?(@log_file_path)
  end


  #########################################
  def test_initialization_with_log_file
    assert_instance_of Logger, @logging.logger, "Logger instance should be created with a log file"
    assert_match @log_file_path, @logging.logger.instance_variable_get(:@logdev).filename, "Logger should log to the specified file"
  end


  def test_initialization_without_log_file
    logging_stdout = AIA::Logging.new(nil)
    assert_instance_of Logger, logging_stdout.logger, "Logger instance should be created even without a log file"
    assert_equal STDOUT, logging_stdout.logger.instance_variable_get(:@logdev).dev, "Logger should log to STDOUT when file path is not provided"
  end


  def test_logging_methods
    methods = [:debug, :info, :warn, :error, :fatal]
    methods.each do |method|
      @logging.logger.stub(method, true) do
        assert @logging.send(method, "Test"), "Logger should respond to :#{method}"
      end
    end
  end


  def test_configure_logger_formatter
    message           = "Test message"
    severity          = "INFO"
    timestamp         = Time.new(2023, 1, 1, 12, 0, 0)
    @logging.send(:configure_logger)
    formatted_log     = @logging.logger.formatter.call(severity, timestamp, nil, message)
    
    assert_match (/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] INFO: Test message\n/), formatted_log, "Log formatter should properly format the message"
    
    # assert false
    # assert formatted_log.include?(severity)
    # assert formatted_log.include?(message)

  end


  def test_logging_prompt_result
    prompt = OpenStruct.new(id: 1, path: 'test_path', keywords: ['keyword1', 'keyword2'], to_s: 'prompt_string')
    result = "Test Result"

    @logging.prompt_result(prompt, result)

    # Check if the log file contains the proper formatted message
    log_content = File.read(@log_file_path)
    assert_match (/PROMPT ID 1/), log_content
    assert_match (/PATH:     test_path/), log_content
    assert_match (/KEYWORDS: keyword1, keyword2/), log_content
    assert_match (/prompt_string/), log_content
    assert_match (/RESULT:\nTest Result/), log_content
  end
end


