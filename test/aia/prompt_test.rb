# test/aia/prompt_test.rb

require 'test_helper'

module PromptManager
  class FileSystemAdapter
    def initialize(dir); end
    def find(id); end
    def list; []; end
  end

  class Storage
    def initialize(dir)
      @adapter = FileSystemAdapter.new(dir)
    end
    def find(id); @adapter.find(id); end
    def list; @adapter.list; end
  end

  class Prompt
    attr_reader :id, :path, :keywords
    def initialize(id:, path:, keywords:)
      @id = id
      @path = path 
      @keywords = keywords
    end
    def to_s; "test prompt"; end
  end
end

class PromptTest < Minitest::Test
  def setup
    @original_env = ENV.select { |k, _v| k.start_with?('AIA_') }
    @original_env.each_key { |key| ENV.delete key }
    
    # Set up the prompts directory before initializing CLI
    prompts_dir = File.expand_path('../prompts_dir', __FILE__)
    ENV['AIA_PROMPTS_DIR'] = prompts_dir
    
    # Mock fzf to prevent interactive prompts
    fzf = Minitest::Mock.new
    fzf.expect(:run, 'test')
    AIA::Fzf.stub(:new, fzf) do
      simulate_user_input("test_animal") do
        AIA::Cli.new("test")  # Pass just the test argument
        @prompt = AIA::Prompt.new(build: false)
      end
    end
  end
  
  def teardown
    @original_env.each { |k, v| ENV[k] = v }
  end
  
  def test_aia_prompt_fake
    fake = AIA::Prompt::Fake.new
    assert_equal '_fake_',  fake.id
    assert_equal '_fake_',  fake.path
    assert_equal '',        fake.to_s
    assert_equal [],        fake.keywords
    assert_equal [],        fake.directives
    assert_equal '',        fake.text
  end

  def test_returns_fake_when_no_prompt_id_and_extra
    AIA.config.arguments = []
    AIA.config.extra = "--raw"

    result = AIA::Prompt.new.prompt
    assert result.is_a?(AIA::Prompt::Fake)
  end

  def test_happy_path
    AIA.config.arguments = ['test']
    
    simulate_user_input("test_animal") do
      result = AIA::Prompt.new(build: false).prompt
      assert result.is_a?(PromptManager::Prompt)
      assert_equal 'test', result.id
      assert_equal ['[ANIMAL]'], result.keywords
    end
  end

  def test_missing_promt_id
    AIA.config.arguments = []
    result = AIA::Prompt.new.prompt
    assert result.is_a?(AIA::Prompt::Fake)
  end

  def test_show_prompt_without_comments
    AIA.config.arguments = ['test']
    apc = nil
    simulate_user_input("test_animal") do
      apc = AIA::Prompt.new(build: false)
    end
    expected = ["    What does [ANIMAL] say?\n", ""]

    result = capture_io do
      apc.show_prompt_without_comments
    end

    assert_equal expected, result
  end

  def test_remove_comments
    AIA.config.arguments = ['test']
    apc = nil
    simulate_user_input("test_animal") do
      apc = AIA::Prompt.new(build: false)
    end

    result = apc.remove_comments
    expected = "What does [ANIMAL] say?\n"

    assert_equal expected, result
  end
end
