require_relative '../test_helper'
require 'tempfile'
require 'open3'
require_relative '../../lib/aia'
require_relative '../../lib/aia/fzf'

class FzfTest < Minitest::Test
  def setup
    # Only skip if fzf is truly not available (check with full path)
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1') || File.exist?('/opt/homebrew/bin/fzf')

    @list = ['item1', 'item2', 'item3']
    @directory = '/test/dir'
    @fzf = AIA::Fzf.new(
      list: @list,
      directory: @directory,
      query: 'test',
      subject: 'Test Items',
      prompt: 'Choose one:',
      extension: '.md'
    )
  end

  def test_initialization_with_all_parameters
    assert_equal @list, @fzf.list
    assert_equal @directory, @fzf.directory
    assert_equal 'test', @fzf.query
    assert_equal 'Test Items', @fzf.subject
    assert_equal 'Choose one:', @fzf.prompt
    assert_equal '.md', @fzf.extension
  end

  def test_initialization_with_required_parameters_only
    fzf = AIA::Fzf.new(list: @list, directory: @directory)

    assert_equal @list, fzf.list
    assert_equal @directory, fzf.directory
    assert_equal '', fzf.query
    assert_equal 'Prompt IDs', fzf.subject
    assert_equal 'Select one:', fzf.prompt
    assert_equal '.md', fzf.extension
  end

  def test_default_parameters_constant
    expected_defaults = %w[
      --tabstop=2
      --header-first
      --prompt='Search term: '
      --delimiter :
      --preview-window=down:50%:wrap
    ]

    assert_equal expected_defaults, AIA::Fzf::DEFAULT_PARAMETERS
  end

  def test_build_command_creates_fzf_args_array
    fzf_args = @fzf.instance_variable_get(:@fzf_args)

    refute_nil fzf_args
    assert_kind_of Array, fzf_args

    joined = fzf_args.join(' ')

    # Should include default parameters
    assert_includes joined, '--tabstop=2'
    assert_includes joined, '--header-first'
    assert_includes joined, '--delimiter'
    assert_includes joined, '--preview-window=down:50%:wrap'

    # Should include header with subject and query (shell-escaped)
    header_arg = fzf_args.find { |a| a.start_with?('--header=') }
    refute_nil header_arg
    assert_includes header_arg, 'Test'
    assert_includes header_arg, 'test'

    # Should include preview with escaped directory
    preview_arg = fzf_args.find { |a| a.start_with?('--preview=') }
    refute_nil preview_arg
    assert_includes preview_arg, '/test/dir'
    assert_includes preview_arg, '.md'

    # Should include custom prompt (last --prompt= wins)
    prompt_args = fzf_args.select { |a| a.start_with?('--prompt=') }
    assert(prompt_args.any? { |a| a.include?('Choose') })
  end

  def test_build_command_handles_special_characters_in_prompt
    fzf = AIA::Fzf.new(
      list: @list,
      directory: @directory,
      prompt: "What's your choice?"
    )

    fzf_args = fzf.instance_variable_get(:@fzf_args)
    prompt_args = fzf_args.select { |a| a.start_with?('--prompt=') }
    # Shellwords.escape handles the special characters; the custom prompt is the last one
    assert(prompt_args.any? { |a| a.include?('What') })
  end

  def test_run_passes_correct_stdin_data
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)
    expected_input = @list.join("\n")
    Open3.expects(:capture2).with { |*_args, **kwargs| kwargs[:stdin_data] == expected_input }.returns(["item1\n", mock_status])

    @fzf.run
  end

  def test_run_with_successful_selection
    # Mock Open3.capture2 to return a selection
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)
    Open3.expects(:capture2).with('fzf', *@fzf.instance_variable_get(:@fzf_args), stdin_data: @list.join("\n")).returns(["item2\n", mock_status])

    result = @fzf.run

    assert_equal 'item2', result
  end

  def test_run_with_empty_selection
    # Mock Open3.capture2 to return empty string (user cancelled)
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(false)
    Open3.expects(:capture2).with('fzf', *@fzf.instance_variable_get(:@fzf_args), stdin_data: @list.join("\n")).returns(['', mock_status])

    result = @fzf.run

    assert_nil result
  end

  def test_run_with_whitespace_only_selection
    # Mock Open3.capture2 to return whitespace
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)
    Open3.expects(:capture2).with('fzf', *@fzf.instance_variable_get(:@fzf_args), stdin_data: @list.join("\n")).returns(["   \n  ", mock_status])

    result = @fzf.run

    assert_nil result
  end

  def test_run_strips_whitespace_from_selection
    # Mock Open3.capture2 to return selection with whitespace
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)
    Open3.expects(:capture2).with('fzf', *@fzf.instance_variable_get(:@fzf_args), stdin_data: @list.join("\n")).returns(["  item1  \n", mock_status])

    result = @fzf.run

    assert_equal 'item1', result
  end

  def test_run_uses_stdin_data_not_tempfile
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)
    Open3.expects(:capture2).with { |*args, **kwargs| kwargs.key?(:stdin_data) }.returns(["item1\n", mock_status])

    @fzf.run
  end

  def test_tempfile_path_method_removed
    refute AIA::Fzf.method_defined?(:tempfile_path),
      "Fzf#tempfile_path dead code should have been removed"
  end

  def test_run_passes_list_items_as_stdin
    fzf = AIA::Fzf.new(list: ['alpha', 'beta'], directory: '/test')
    mock_status = mock('status')
    mock_status.stubs(:success?).returns(true)

    Open3.expects(:capture2).with { |*_args, **kwargs| kwargs[:stdin_data] == "alpha\nbeta" }.returns(["alpha\n", mock_status])

    result = fzf.run
    assert_equal 'alpha', result
  end
end
