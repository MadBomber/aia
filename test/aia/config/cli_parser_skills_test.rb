# frozen_string_literal: true

require_relative '../../test_helper'

class CLIParserSkillsOptionsTest < Minitest::Test
  def parse(args)
    options = {}
    parser = AIA::CLIParser.send(:create_option_parser, options)
    parser.parse(args)
    options
  end

  def test_skills_dir_option
    options = parse(['--skills-dir', '/custom/skills'])
    assert_equal '/custom/skills', options[:skills_dir]
  end

  def test_skills_prefix_option
    options = parse(['--skills-prefix', 'my_skills'])
    assert_equal 'my_skills', options[:skills_prefix]
  end

  def test_skill_short_option_single
    options = parse(['-s', 'summarizer'])
    assert_equal ['summarizer'], options[:skills]
  end

  def test_skill_long_option_single
    options = parse(['--skill', 'summarizer'])
    assert_equal ['summarizer'], options[:skills]
  end

  def test_skill_option_comma_separated
    options = parse(['--skill', 'summarizer,formatter'])
    assert_equal ['summarizer', 'formatter'], options[:skills]
  end

  def test_skill_option_strips_whitespace
    options = parse(['--skill', ' summarizer , formatter '])
    assert_equal ['summarizer', 'formatter'], options[:skills]
  end

  def test_list_skills_option
    options = parse(['--list-skills'])
    assert_equal true, options[:list_skills]
  end

  def test_list_skills_does_not_exit
    exited = false
    begin
      parse(['--list-skills'])
    rescue SystemExit
      exited = true
    end
    refute exited, '--list-skills should not exit from the parser'
  end
end
