# test/aia/tools/editor_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/tools/editor'


class TestEditor < Minitest::Test
  def setup
    @test_file    = "test.txt"
    @editor_name  = "atom"
    ENV['EDITOR'] = @editor_name  # This is for testing purposes only, to ensure a consistent environment
    @editor       = AIA::Editor.new(file: @test_file)
  end

  def teardown
    ENV['EDITOR'] = nil  # Clean up environment variable after test
  end


  #############################################
  def test_initialize
    assert_equal @editor_name,  @editor.name
    assert_equal @test_file,    @editor.instance_variable_get(:@file)
  end


  def test_discover_editor_with_env_set
    @editor.discover_editor
    assert_equal @editor_name, @editor.name
  end


  def test_discover_editor_without_env_set
    ENV['EDITOR'] = nil
    @editor.discover_editor
    assert_equal "echo", @editor.name
    assert_equal "You have no default editor", @editor.description
  end


  def test_build_command
    @editor.build_command
    expected_command = "#{@editor_name} #{AIA::Editor::DEFAULT_PARAMETERS} #{@test_file}"
    assert_equal expected_command, @editor.command
  end


  def test_run
    @editor.command = "echo 'test_run'"
    output          = @editor.run
    assert_equal "test_run\n", output
  end
end
