require_relative '../test_helper'
require 'tempfile'
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
    refute_nil @fzf.command
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

  def test_build_command_creates_proper_command
    command = @fzf.command
    
    # Should contain basic fzf command structure
    assert_match(/cat .* \| fzf/, command)
    
    # Should include default parameters
    assert_match(/--tabstop=2/, command)
    assert_match(/--header-first/, command)
    assert_match(/--delimiter :/, command)
    assert_match(/--preview-window=down:50%:wrap/, command)
    
    # Should include custom header
    assert_match(/--header='Test Items which contain: test/, command)
    
    # Should include preview command  
    assert_includes command, "--preview='cat /test/dir/{1}.md'"
    
    # Should include custom prompt
    assert_match(/--prompt=Choose\\ one:/, command)
  end

  def test_build_command_handles_special_characters_in_prompt
    fzf = AIA::Fzf.new(
      list: @list,
      directory: @directory,
      prompt: "What's your choice?"
    )
    
    # Should properly escape special characters
    assert_match(/--prompt=What\\'s\\ your\\ choice\\?/, fzf.command)
  end

  def test_tempfile_path_creates_tempfile_with_list_content
    # Access the private method
    tempfile_path = @fzf.send(:tempfile_path)
    
    assert File.exist?(tempfile_path)
    
    content = File.read(tempfile_path)
    @list.each do |item|
      assert_includes content, item
    end
  end

  def test_tempfile_path_returns_same_path_on_multiple_calls
    path1 = @fzf.send(:tempfile_path)
    path2 = @fzf.send(:tempfile_path)
    
    assert_equal path1, path2
  end

  def test_run_with_successful_selection
    # Mock the command execution to return a selection
    @fzf.expects(:`).with(@fzf.command).returns("item2\n")
    
    result = @fzf.run
    
    assert_equal 'item2', result
  end

  def test_run_with_empty_selection
    # Mock the command execution to return empty string (user cancelled)
    @fzf.expects(:`).with(@fzf.command).returns('')
    
    result = @fzf.run
    
    assert_nil result
  end

  def test_run_with_whitespace_only_selection
    # Mock the command execution to return whitespace
    @fzf.expects(:`).with(@fzf.command).returns("   \n  ")
    
    result = @fzf.run
    
    assert_nil result
  end

  def test_run_strips_whitespace_from_selection
    # Mock the command execution to return selection with whitespace
    @fzf.expects(:`).with(@fzf.command).returns("  item1  \n")
    
    result = @fzf.run
    
    assert_equal 'item1', result
  end

  def test_run_cleans_up_tempfile
    # Mock the tempfile to verify cleanup
    mock_tempfile = mock('tempfile')
    mock_tempfile.expects(:unlink)
    @fzf.instance_variable_set(:@tempfile, mock_tempfile)
    
    @fzf.expects(:`).returns('item1')
    
    @fzf.run
  end

  def test_run_cleans_up_tempfile_even_on_exception
    # Mock an exception during command execution
    @fzf.expects(:`).raises(StandardError.new('Command failed'))
    
    # Mock the tempfile to verify cleanup still happens
    mock_tempfile = mock('tempfile')
    mock_tempfile.expects(:unlink)
    @fzf.instance_variable_set(:@tempfile, mock_tempfile)
    
    assert_raises(StandardError) do
      @fzf.run
    end
  end

  def test_unlink_tempfile_handles_nil_tempfile
    @fzf.instance_variable_set(:@tempfile, nil)
    
    # Should not raise an error
    @fzf.send(:unlink_tempfile)
    # If we get here without an exception, the test passes
    assert true
  end

  def test_unlink_tempfile_calls_unlink_on_tempfile
    mock_tempfile = mock('tempfile')
    mock_tempfile.expects(:unlink)
    @fzf.instance_variable_set(:@tempfile, mock_tempfile)
    
    @fzf.send(:unlink_tempfile)
  end

  def test_integration_with_empty_list
    fzf = AIA::Fzf.new(list: [], directory: '/test')
    
    # Should handle empty list gracefully
    tempfile_path = fzf.send(:tempfile_path)
    content = File.read(tempfile_path)
    
    assert_equal '', content.strip
  end

  def test_integration_with_special_characters_in_list
    special_list = ['item with spaces', 'item-with-dashes', 'item_with_underscores']
    fzf = AIA::Fzf.new(list: special_list, directory: '/test')
    
    tempfile_path = fzf.send(:tempfile_path)
    content = File.read(tempfile_path)
    
    special_list.each do |item|
      assert_includes content, item
    end
  end
end