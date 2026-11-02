# frozen_string_literal: true

# test/aia/migrate_prompts_test.rb
#
# bin/migrate_prompts converts old .txt prompts to .md. The CLI part is
# skipped when MIGRATE_PROMPTS_NO_CLI is defined.

require_relative '../test_helper'
require 'open3'
require 'rbconfig'

MIGRATE_PROMPTS_NO_CLI = true
MIGRATE_PROMPTS = File.expand_path('../../bin/migrate_prompts', __dir__)
load MIGRATE_PROMPTS

class MigratePromptsTest < Minitest::Test
  def setup
    @migrator = PromptMigrator.new(dry_run: false, verbose: false, force: false, reprocess: false, args: [])
  end

  def front_matter(lines)
    parsed = @migrator.send(:parse_file, lines, 'demo')
    yaml   = @migrator.send(:build_yaml_string, parsed, {})
    [YAML.safe_load(yaml), parsed]
  end

  def body_for(line)
    @migrator.send(:parse_file, [line], 'demo')[:body_lines]
  end

  def test_shell_inserts_the_command_output
    assert_equal ["<%= `git log -5 --oneline` %>"], body_for('//shell git log -5 --oneline')
  end

  def test_shell_keeps_quotes_in_the_command_as_written
    assert_equal [%q(<%= `echo "it's here"` %>)], body_for(%q(//shell echo "it's here"))
  end

  def test_shell_with_a_placeholder_interpolates_the_parameter
    assert_equal ["<%= `ls \#{dir}` %>"], body_for('//shell ls [DIR]')
    assert_equal ["<%= `\#{cmd}` %>"], body_for('//shell [CMD]')
  end

  def test_shell_erb_renders_to_the_output
    assert_equal "it's here\n", ERB.new(body_for(%q(//shell echo "it's here")).first).result
    assert_equal "a b\n", ERB.new(body_for('//shell echo [WORDS]').first).result_with_hash(words: 'a b')
  end

  def test_root_keys_stay_at_the_top_level
    meta, = front_matter(['//config model gpt-4o', '//config temperature 0.3', '//config shell = false'])

    assert_equal 'gpt-4o', meta['model']
    assert_in_delta 0.3, meta['temperature']
    assert_equal false, meta['shell']
    refute meta.key?('config')
  end

  def test_other_settings_go_under_config
    meta, = front_matter(['//config tokens true', '//config max_tokens 500', '//config llm.top_k 40'])

    assert_equal({ 'flags' => { 'tokens' => true }, 'llm' => { 'max_tokens' => 500, 'top_k' => 40 } }, meta['config'])
  end

  def test_unknown_keys_go_under_config_with_a_warning
    meta, parsed = front_matter(['//config terse true'])

    assert_equal({ 'terse' => true }, meta['config'])
    assert(parsed[:warnings].any? { it.include?("'terse'") })
  end

  def test_config_paths_match_aia
    expected = AIA::Config::CLI_TO_NESTED_MAP
               .to_h { |flat, path| [flat.to_s, path.join('.')] }
               .except(*PromptMigrator::ROOT_KEYS)

    assert_equal expected.sort.to_h, PromptMigrator::CONFIG_PATHS.sort.to_h
  end

  def test_reports_even_with_warnings_turned_off
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'demo.txt'), "Hello [NAME]\n")
      _, err, status = Open3.capture3({ 'RUBYOPT' => '-W0' }, RbConfig.ruby, MIGRATE_PROMPTS, '--dry-run', dir)

      assert status.success?
      assert_includes err, 'demo'
    end
  end
end
