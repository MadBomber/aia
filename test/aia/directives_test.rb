# test/aia/logging_test.rb

require_relative  '../test_helper'

class DirectivesTest < Minitest::Test
  def setup
    AIA::Cli.new("")
    @ad = AIA::Directives.new
  end


  def test_execute_my_directives
    AIA.config.directives = [
      ['box',   '== hello =='], 
      ['xyzzy', 'echo magic'],
    ]

    assert_equal 2, AIA.config.directives.size

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


  def test_config
    initial_directives_count = AIA.config.directives.count
    
    @ad.config('xyzzy := magic')
    
    assert_equal 'magic', AIA.config.xyzzy
  end
end


