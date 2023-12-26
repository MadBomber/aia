# test/aia/tools/subl_test.rb

require "minitest/autorun"
require_relative "../../../lib/aia/tools/subl"

module AIA
  class TestSubl < Minitest::Test
    def setup
      @subl = AIA::Subl.new(file: "test_file.txt")
    end
    
    def test_initialize_with_file
      assert_equal "test_file.txt", @subl.instance_variable_get(:@file)
    end
    
    def test_build_command
      @subl.build_command
      expected_command = "subl --new-window --wait test_file.txt"
      assert_equal expected_command, @subl.command
    end
    
    def test_run_invokes_system_call
      @subl.command = "echo 'Hello World!'"
      output = @subl.run
      assert_equal "Hello World!\n", output
    end
    
    def test_run_with_empty_file
      @subl = AIA::Subl.new(file: "")
      @subl.build_command

      assert_match (/subl --new-window --wait $/), @subl.command
    end
  end
end


