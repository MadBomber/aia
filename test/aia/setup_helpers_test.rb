require 'test_helper'

class SetupHelpersTest < Minitest::Test
  class TestClass
    include AIA::SetupHelpers
    attr_accessor :piped_content
  end

  def initialize(*args)
    super
    @test_class = TestClass.new
  end

  def setup
    super
    @original_config = AIA.config
    AIA.config = AIA::Config.new
    AIA.config.log_file = ENV['AIA_LOG_FILE']
    AIA.config.prompts_dir = ENV['AIA_PROMPTS_DIR']
    AIA.config.arguments = ["test"]
  end

  def teardown
    super
    AIA.config = @original_config
    File.delete(ENV['AIA_LOG_FILE']) if File.exist?(ENV['AIA_LOG_FILE'])
  end

  def test_setup_spinner
    spinner = @test_class.setup_spinner
    assert_instance_of TTY::Spinner, spinner
    assert_match /composing response/, spinner.message.to_s
  end

  def test_setup_logger
    result = @test_class.setup_logger
    assert_instance_of AIA::Logging, result
  end

  def test_setup_directives_processor
    result = @test_class.setup_directives_processor
    assert_instance_of AIA::Directives, result
  end

  def test_setup_prompt_without_piped_content
    @test_class.piped_content = nil
    simulate_user_input("test_input") do
      result = @test_class.setup_prompt
      assert_instance_of AIA::Prompt, result
    end
  end

  def test_setup_prompt_with_piped_content
    simulate_user_input("test_input") do
      with_stdin do |user_input|
        user_input.puts "test input"
        user_input.close
        @test_class.piped_content = "test input"
        result = @test_class.setup_prompt
        assert_instance_of AIA::Prompt, result
      end
    end
  end
end
