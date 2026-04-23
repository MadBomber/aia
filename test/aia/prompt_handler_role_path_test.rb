require_relative '../test_helper'
require 'ostruct'
require 'fileutils'
require 'tmpdir'
require 'tempfile'
require_relative '../../lib/aia'

class PromptHandlerRolePathTest < Minitest::Test
  def setup
    AIA.stubs(:config).returns(OpenStruct.new(
      models: [OpenStruct.new(name: 'test-model')],
      llm: OpenStruct.new(temperature: 0.7, max_tokens: 2048),
      flags: OpenStruct.new(chat: false, fuzzy: false, erb: false, shell: false),
      tools: OpenStruct.new(paths: []),
      context_files: [],
      prompts: OpenStruct.new(
        dir: '/tmp/test_prompts',
        extname: '.md',
        roles_dir: '/tmp/test_prompts/roles',
        roles_prefix: 'roles',
        role: nil,
        parameter_regex: '\\{\\{\\w+\\}\\}'
      ),
      prompt_id: 'test_prompt'
    ))
    @handler = AIA::PromptHandler.new
  end

  def teardown
    super
  end

  def test_fetch_role_with_absolute_path
    role_file = Tempfile.new(['role', '.md'])
    role_file.write("You are an expert.")
    role_file.close

    result = @handler.send(:fetch_role, role_file.path)
    assert_equal "You are an expert.", result.to_s
  ensure
    role_file.unlink if role_file
  end

  def test_fetch_role_with_absolute_path_no_extension
    Dir.mktmpdir do |dir|
      role_path = File.join(dir, 'my-role')
      File.write("#{role_path}.md", "You are a teacher.")

      result = @handler.send(:fetch_role, role_path)
      assert_equal "You are a teacher.", result.to_s
    end
  end

  def test_fetch_role_with_absolute_path_no_extension_md_file
    Dir.mktmpdir do |dir|
      role_path = File.join(dir, 'my-role')
      File.write("#{role_path}.md", "You are a mentor.")

      result = @handler.send(:fetch_role, role_path)
      assert_equal "You are a mentor.", result.to_s
    end
  end

  def test_fetch_role_path_not_found_warns
    _, err = capture_io do
      @handler.send(:fetch_role, '/nonexistent/path/to/role')
    end
    assert_match(/not found/i, err)
  end
end
