# test/aia/logging_test.rb

require_relative  '../test_helper'

class DirectivesTest < Minitest::Test
  # Utility Class for a Prompt Mock
  class MockPrompt
    def directives
      []
    end
  end


  def setup
    AIA::Cli.new("")
    @ad = AIA::Directives.new(prompt: MockPrompt.new)
  end


  def test_execute_my_directives
    AIA.config.directives = [
      ['box',   '== hello =='], 
      ['shell', 'echo "hello"'],
      ['xyzzy', 'echo magic'],
    ]

    assert_equal 3, AIA.config.directives.size

    @ad.execute_my_directives

    assert_equal 1, AIA.config.directives.size
  end


  def test_box
    out, err = capture_io do
      @ad.box('== hello ==')
    end

    expected = <<~EOS
      ===========
      == hello ==
      ===========
    EOS

    assert_equal expected, out
  end


  def test_shell
    out, err = capture_io do
      @ad.shell('echo hello world')
    end

    assert_equal "hello world\n", out
  end


  def test_ruby
    assert_equal 3, @ad.ruby('1 + 2')
  end


  def test_config
    initial_directives_count = AIA.config.directives.count
    
    @ad.config('xyzzy := magic')
    
    assert_equal 'magic', AIA.config.xyzzy
  end
end


