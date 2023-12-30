# test/aia/prompt_test.rb

require_relative  '../test_helper'

class PromptTest < Minitest::Test
  def setup
    @original_env = ENV.select { |k, _v| k.start_with?('AIA_') }
    @original_env.each_key { |key| ENV.delete key }
    AIA::Cli.new("--prompts #{__dir__}/prompts_dir")
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
  end


  def test_returns_fake_when_no_prompt_id_and_extra
    assert_equal [], AIA.config.arguments
    AIA.config.extra = "--raw"

    result = AIA::Prompt.new.prompt

    assert result.is_a?(AIA::Prompt::Fake)
  end


  def test_happy_path
    AIA.config.arguments = ['test']
    result = AIA::Prompt.new(build: false).prompt

    assert result.is_a?(PromptManager::Prompt)
    assert_equal 'test',        result.id
    assert_equal ['[ANIMAL]'],  result.keywords
  end


  def test_missing_promt_id
    output = capture_io do
      assert_raises(SystemExit) do
        AIA::Prompt.new
      end
    end.join(' ').downcase

    assert_includes output, 'please provide a prompt id'
  end


  # def test_get_prompt
  #   skip "tested in happy path and missing prompt id tests"
  # end


  # def test_existing_prompt?
  #   skip "tested by the happy path"
  # end


  def test_process_prompt
    skip "TBD - Test for Prompt#process_prompt method"
  end


  def test_replace_keywords
    skip "TBD - Test for Prompt#replace_keywords method"
  end


  def test_keyword_value
    skip "TBD - Test for Prompt#keyword_value method"
  end


  def test_search_for_a_matching_prompt
    skip "TBD - Test for Prompt#search_for_a_matching_prompt method"
  end


  def test_handle_multiple_prompts
    skip "TBD - Test for Prompt#handle_multiple_prompts method"
  end


  # def test_create_prompt
  #   skip "PromptManager is response for this"
  # end


  def test_edit_prompt
    skip "TBD - Test for Prompt#edit_prompt method"
  end


  def test_show_prompt_without_comments
    AIA.config.arguments = ['test']
    apc = AIA::Prompt.new(build: false)
    expected  = ["    What does [ANIMAL] say?\n", ""]

    result = capture_io do
      apc.show_prompt_without_comments
    end

    assert_equal expected, result
  end


  def test_remove_comments
    AIA.config.arguments = ['test']
    apc = AIA::Prompt.new(build: false)

    result    = apc.remove_comments
    expected  = "What does [ANIMAL] say?\n"

    assert_equal expected, result
  end
end


