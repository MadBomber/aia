# test/core_ext/string_wrap_test.rb
#
# frozen_string_literal: true

require_relative "../test_helper"
require_relative '../../lib/core_ext/string_wrap'

class StringWrapTest < Minitest::Test
  def test_wrap_with_default_width
    assert_equal <<~RESULT.chomp, "This is a single line".wrap
      This is a single line
    RESULT
  end

  def test_string_wrap_with_specific_line_width
                      #....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    test_string     = "This is a long line that needs to be wrapped around at some point"
    expected_result = 
                    [ "This is a",
                      "long line",
                      "that needs",
                      "to be",
                      "wrapped",
                      "around at",
                      "some point" ].join("\n")
    
    assert_equal expected_result, test_string.wrap(line_width: 10)
  end

  def test_string_wrap_with_string_indent
                      #....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    test_string     = "This line has an indentation as a string."
    expected_result = 
                    [ "> This line has",
                      "> an",
                      "> indentation",
                      "> as a string." ].join("\n")
    
    assert_equal expected_result, test_string.wrap(line_width: 15, indent: "> ")
  end

  def test_string_wrap_with_integer_indent
                      #....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    test_string     = "This line has an indentation as an integer."
    expected_result = 
                    [ "  This line has",
                      "  an",
                      "  indentation",
                      "  as an",
                      "  integer." ].join("\n")
    
    assert_equal expected_result, test_string.wrap(line_width: 15, indent: 2)
  end

  def test_string_wrap_preserving_paragraphs
    # ....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    test_string = <<~TEST_STRING
      Paragraph one still part of paragraph one.

      Paragraph two and the next line.
    TEST_STRING

    # ....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    expected_result = <<~EXPECTED_RESULT.chomp
      Paragraph one
      still part of
      paragraph one.

      Paragraph two
      and the next
      line.
    EXPECTED_RESULT

    assert_equal expected_result, test_string.wrap(line_width: 15)
  end

  def test_string_wrap_with_newlines_in_paragraph
                      #....^....1....^....2....^....3....^....4....^....5....^....6....^....7....^....8....^....9....^
    test_string     = "This paragraph\nhas newlines\nat odd places."
    expected_result = 
                    [ "This",
                      "paragraph",
                      "has",
                      "newlines",
                      "at odd",
                      "places." ].join("\n")
    
    assert_equal expected_result, test_string.wrap(line_width: 10)
  end
end

