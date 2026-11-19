# frozen_string_literal: true

# test/aia/completion_scripts_test.rb

require_relative '../test_helper'
require 'open3'
require 'tmpdir'

class CompletionScriptsTest < Minitest::Test
  SCRIPT_DIR = File.expand_path('../../lib/aia', __dir__)

  def shell_available?(name)
    system("command -v #{name} >/dev/null 2>&1")
  end

  def test_zsh_script_registers_with_compsys
    skip 'zsh not installed' unless shell_available?('zsh')

    Dir.mktmpdir do |dir|
      script = File.join(SCRIPT_DIR, 'aia_completion.zsh')
      cmd = "autoload -Uz compinit; compinit -u -d #{dir}/zcompdump; " \
            "source #{script}; print -r -- \"[${_comps[aia]}]\""
      out, status = Open3.capture2e('zsh', '-f', '-c', cmd)

      assert status.success?, out
      assert_includes out, '[_aia_completion]'
    end
  end

  def test_fish_script_completes_prompt_ids_for_first_argument_only
    skip 'fish not installed' unless shell_available?('fish')

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'hello.md'), 'hi')
      script = File.join(SCRIPT_DIR, 'aia_completion.fish')
      env = { 'AIA_PROMPTS__DIR' => dir }

      first, = Open3.capture2e(env, 'fish', '--no-config', '-c', "source #{script}; complete -C 'aia he'")
      later, = Open3.capture2e(env, 'fish', '--no-config', '-c', "source #{script}; complete -C 'aia hello he'")

      assert_equal 'hello', first.lines.first.to_s.split("\t").first.strip
      refute_includes later.lines.map { |l| l.split("\t").first.strip }, 'hello'
    end
  end
end
