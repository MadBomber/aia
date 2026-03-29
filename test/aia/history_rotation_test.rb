# frozen_string_literal: true
# test/aia/history_rotation_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'tmpdir'

class HistoryRotationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @history_file = File.join(@tmpdir, "_prompts.log")

    @config = OpenStruct.new(
      flags:    OpenStruct.new(chat: false, debug: false, no_mcp: true),
      models:   [OpenStruct.new(name: 'gpt-4o-mini')],
      output:   OpenStruct.new(
        file:         File.join(@tmpdir, "output.md"),
        append:       false,
        history_file: @history_file
      ),
      context_files: [],
      pipeline: []
    )
    AIA.stubs(:config).returns(@config)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_rotate_history_renames_file_when_over_limit
    # Create a file that exceeds the 10MB threshold
    File.write(@history_file, "x" * (10 * 1024 * 1024 + 1))

    session = AIA::Session.allocate
    session.send(:rotate_history_log_if_needed)

    refute File.exist?(@history_file), "Original file should be gone"
    assert File.exist?("#{@history_file}.1"), "Archive file should exist"
  end

  def test_rotate_history_leaves_small_file_alone
    File.write(@history_file, "small content")

    session = AIA::Session.allocate
    session.send(:rotate_history_log_if_needed)

    assert File.exist?(@history_file), "Small file should not be rotated"
    refute File.exist?("#{@history_file}.1"), "Archive should not exist"
  end

  def test_rotate_history_does_nothing_when_no_history_file
    # No file created — should not raise
    session = AIA::Session.allocate
    session.send(:rotate_history_log_if_needed)
    assert true  # just verify no exception
  end
end
