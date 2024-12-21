require 'test_helper'

class SetupHelpersTest < Minitest::Test
  class TestClass
    include AIA::SetupHelpers
    attr_reader :spinner, :logger, :directives_processor, :prompt, :piped_content
    
    def initialize(piped_content = nil)
      @piped_content = piped_content
    end
  end

  def setup
    @test_instance = TestClass.new
  end

  def test_setup_spinner
    @test_instance.setup_spinner
    
    assert_instance_of TTY::Spinner, @test_instance.spinner
    assert_equal "composing response ... ", @test_instance.spinner.title
  end

  def test_setup_logger
    @test_instance.setup_logger
    
    assert_instance_of AIA::Logging, @test_instance.logger
  end

  def test_setup_directives_processor
    @test_instance.setup_directives_processor
    
    assert_instance_of AIA::Directives, @test_instance.directives_processor
  end

  def test_setup_prompt_without_piped_content
    @test_instance.setup_prompt
    
    assert_instance_of PromptManager::Prompt, @test_instance.prompt
  end

  def test_setup_prompt_with_piped_content
    test_instance = TestClass.new("piped data")
    test_instance.setup_prompt
    
    assert_includes test_instance.prompt.text, "piped data"
  end
end
