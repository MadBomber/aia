# test/aia/logging_test.rb

require 'test_helper'

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
    out = capture_io do
      @ad.box('== hello ==')
    end

    expected = <<~EOS
      ===========
      == hello ==
      ===========
    EOS

    assert_equal expected, out[0]
  end


  def test_config
    @ad.config('xyzzy := magic')
    
    assert_equal 'magic', AIA.config.xyzzy
  end
end
