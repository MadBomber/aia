# test/aia/tools/fzf_test.rb

require 'test_helper'
require_relative '../../../lib/aia/tools'
require_relative '../../../lib/aia/tools/fzf'

class TestFZF < Minitest::Test
  def setup
    # Example setup for testing
    @list       = ['file1', 'file2', 'file3']
    @directory  = '/path/to/files'
    @query      = 'search_term'
    @subject    = 'Test Files'
    @prompt     = 'Choose file:'
    @extension  = '.rb'

    # Instantiate a new Fzf object with test data
    @fzf = AIA::Fzf.new(
      list:       @list,
      directory:  @directory,
      query:      @query,
      subject:    @subject,
      prompt:     @prompt,
      extension:  @extension
    )
  end

  def test_initialize
    # Check if object initializes with correct attributes
    assert_equal @list, @fzf.list
    assert_equal @directory, @fzf.directory
    assert_equal @query, @fzf.query
    assert_equal @subject, @fzf.subject
    assert_equal @prompt, @fzf.prompt
    assert_equal @extension, @fzf.extension
  end

  def test_build_command
    # Ensure build_command creates the expected command string
    @fzf.build_command
    result = @fzf.command
    assert result.start_with?('cat')
    assert result.include?(' | fzf ')
  end

  def test_run
    # Test to ensure `run` behaves as expected
    @fzf.stub :puts, nil do
      @fzf.stub :`, "file2\n" do
        result = @fzf.run
        assert_equal "file2", result
      end
    end
  end
end
