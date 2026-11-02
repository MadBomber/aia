require_relative '../test_helper'
require 'ostruct'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/aia'

# Prompt lookup and rendering: IDs with hyphens, folders and paths, piped
# text, front-matter pipelines, and parameters declared by included files.
class PromptLoadingTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('aia_prompts')
    @config = OpenStruct.new(
      models: [], pipeline: [], context_files: [], executable_prompt_content: nil,
      llm: OpenStruct.new(temperature: 0.7),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: true, shell: false),
      tools: OpenStruct.new(paths: []),
      prompts: OpenStruct.new(dir: @dir, extname: '.md', roles_prefix: 'roles', role: nil)
    )
    AIA.stubs(:config).returns(@config)
    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
    PM.configure do |c|
      c.shell = true
      c.erb   = true
    end
  end

  def write_prompt(id, text)
    path = File.join(@dir, "#{id}.md")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
    path
  end

  def test_hyphenated_prompt_id_loads_the_file
    write_prompt('code-review', 'Review the code.')
    assert_equal 'Review the code.', @handler.fetch_prompt('code-review').to_s
  end

  def test_folder_prompt_id_loads_the_file
    write_prompt('dev/review', 'Dev review.')
    assert_equal 'Dev review.', @handler.fetch_prompt('dev/review').to_s
  end

  def test_path_based_prompt_id_loads_the_file
    path = write_prompt('elsewhere', 'From a path.')
    assert_equal 'From a path.', @handler.fetch_prompt(path.delete_suffix('.md')).to_s
  end

  def test_piped_single_word_is_text_not_a_file
    @config.executable_prompt_content = 'hello'
    assert_equal 'hello', @handler.fetch_prompt('__EXECUTABLE_PROMPT__').to_s
  end

  def test_piped_text_ending_in_md_is_text_not_a_file
    @config.executable_prompt_content = 'summarize notes.md'
    assert_equal 'summarize notes.md', @handler.fetch_prompt('__EXECUTABLE_PROMPT__').to_s
  end

  def test_front_matter_pipeline_string_is_split_on_commas
    write_prompt('first', "---\npipeline: second, third\n---\nGo.")
    @handler.fetch_prompt('first')
    assert_equal %w[second third], @config.pipeline
  end

  def test_front_matter_config_pipeline_string_is_split_on_commas
    write_prompt('first', "---\nconfig:\n  pipeline: second,third\n---\nGo.")
    @handler.fetch_prompt('first')
    assert_equal %w[second third], @config.pipeline
  end

  def test_pipeline_list
    assert_equal %w[a b], AIA::PromptHandler.pipeline_list('a, b')
    assert_equal %w[a b c], AIA::PromptHandler.pipeline_list(['a', 'b,c'])
    assert_equal %w[a], AIA::PromptHandler.pipeline_list('a')
    assert_empty AIA::PromptHandler.pipeline_list(nil)
  end

  def test_prompt_file_path
    assert_equal '/p/a/b.md', AIA::SkillUtils.prompt_file_path('a/b', dir: '/p', extname: '.md')
    assert_equal File.expand_path('~/x.md'), AIA::SkillUtils.prompt_file_path('~/x', dir: '/p', extname: '.md')
    assert_equal '/abs/y.txt', AIA::SkillUtils.prompt_file_path('/abs/y.txt', dir: '/p', extname: '.md')
  end
end

class IncludedParameterTest < Minitest::Test
  # Other tests leave PM's global erb setting off.
  def setup
    PM.configure { it.erb = true }
  end

  def test_parameter_declared_only_in_included_file_is_asked_for
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'child.md'), "---\nparameters:\n  name: null\n---\nHi <%= name %>.")
      parent = File.join(dir, 'parent.md')
      File.write(parent, "Start. <%= include 'child.md' %>")

      collector = mock('input_collector')
      collector.expects(:collect).with({ 'name' => nil }).returns({ 'name' => 'Pat' })
      orchestrator = AIA::PipelineOrchestrator.new(
        robot: nil, prompt_handler: nil, input_collector: collector,
        ui_presenter: nil, session_tracker: nil
      )

      text = orchestrator.send(:render_prompt, PM.parse(Pathname.new(parent)))
      assert_equal 'Start. Hi Pat.', text
    end
  end

  def test_unanswered_parameter_still_raises
    parsed = PM.parse_string("---\nparameters:\n  name: null\n---\n<%= name %>")
    collector = mock('input_collector')
    collector.expects(:collect).once.returns({ 'name' => nil })
    orchestrator = AIA::PipelineOrchestrator.new(
      robot: nil, prompt_handler: nil, input_collector: collector,
      ui_presenter: nil, session_tracker: nil
    )

    assert_raises(PM::MissingParameterError) { orchestrator.send(:render_prompt, parsed) }
  end

  def test_missing_parameter_names
    assert_equal %w[a b], AIA::PipelineOrchestrator.missing_parameter_names('Missing required parameters: a, b')
  end
end
