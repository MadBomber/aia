# frozen_string_literal: true

require_relative '../test_helper'

class DirectiveParseSearchTermsTest < Minitest::Test
  def setup
    # Use a concrete subclass to access the private instance method
    @directive = Class.new(AIA::Directive).new
  end

  def parse(args)
    @directive.send(:parse_search_terms, args)
  end

  def test_empty_args_returns_empty_arrays
    pos, neg = parse([])
    assert_equal [], pos
    assert_equal [], neg
  end

  def test_bare_token_is_positive
    pos, neg = parse(['ruby'])
    assert_equal ['ruby'], pos
    assert_equal [], neg
  end

  def test_plus_prefix_is_positive
    pos, neg = parse(['+ruby'])
    assert_equal ['ruby'], pos
    assert_equal [], neg
  end

  def test_dash_prefix_is_negative
    pos, neg = parse(['-ruby'])
    assert_equal [], pos
    assert_equal ['ruby'], neg
  end

  def test_tilde_prefix_is_negative
    pos, neg = parse(['~ruby'])
    assert_equal [], pos
    assert_equal ['ruby'], neg
  end

  def test_bang_prefix_is_negative
    pos, neg = parse(['!ruby'])
    assert_equal [], pos
    assert_equal ['ruby'], neg
  end

  def test_mixed_positive_and_negative
    pos, neg = parse(['ruby', '-java', 'python', '~cobol'])
    assert_equal ['ruby', 'python'], pos
    assert_equal ['java', 'cobol'], neg
  end

  def test_tokens_are_downcased
    pos, neg = parse(['Ruby', '-Java', '+PYTHON'])
    assert_equal ['ruby', 'python'], pos
    assert_equal ['java'], neg
  end

  def test_single_arg_with_multiple_space_separated_tokens
    pos, neg = parse(['ruby -java python'])
    assert_equal ['ruby', 'python'], pos
    assert_equal ['java'], neg
  end

  def test_multiple_args_each_with_multiple_tokens
    pos, neg = parse(['ruby python', '-java -cobol'])
    assert_equal ['ruby', 'python'], pos
    assert_equal ['java', 'cobol'], neg
  end
end
