# frozen_string_literal: true

# test/aia/user_rules_test.rb
#
# Tests the full user rule loading chain:
#   1. Rule files in config.rules.dir are loaded at startup
#   2. AIA.rules_for(:kb_name) registers rule blocks
#   3. RuleRouter applies user rules to KBs
#   4. User rules fire and produce decisions via AIA.decisions

require_relative '../test_helper'
require_relative '../../lib/aia'
require 'tmpdir'
require 'fileutils'

class UserRulesTest < Minitest::Test
  def setup
    @rules_dir = Dir.mktmpdir('aia_user_rules_test')

    @config = OpenStruct.new(
      models: [OpenStruct.new(name: 'gpt-4o-mini', role: nil)],
      pipeline: [],
      context_files: [],
      mcp_servers: [],
      flags: OpenStruct.new(
        chat: false, debug: false, verbose: false,
        consensus: false, no_mcp: false
      ),
      rules: OpenStruct.new(
        dir: @rules_dir,
        enabled: true
      )
    )

    AIA.stubs(:config).returns(@config)
    AIA.clear_user_rules!
  end

  def teardown
    FileUtils.rm_rf(@rules_dir) if @rules_dir && Dir.exist?(@rules_dir)
    AIA.clear_user_rules!
    AIA.decisions = nil
    super
  end

  # =========================================================================
  # File Loading
  # =========================================================================

  def test_loads_rule_files_from_rules_dir
    write_rule_file('01_test.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "user_test_rule" do
          on :turn_input do
            text matches(/testing123/)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "test", source: "user_file")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new

    assert_equal 1, AIA.user_rules[:classify].size
  end

  def test_loads_multiple_rule_files_alphabetically
    write_rule_file('02_second.rb', <<~RUBY)
      AIA.rules_for(:gate) do
        rule "second_rule" do
          on :context_stats, large: true
          perform { |f| }
        end
      end
    RUBY

    write_rule_file('01_first.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "first_rule" do
          on :turn_input do
            text matches(/first/)
          end
          perform { |f| }
        end
      end
    RUBY

    router = AIA::RuleRouter.new

    assert_equal 1, AIA.user_rules[:classify].size
    assert_equal 1, AIA.user_rules[:gate].size
  end

  def test_skips_missing_rules_dir
    @config.rules.dir = '/nonexistent/path/aia_rules'

    # Should not raise
    router = AIA::RuleRouter.new

    assert_empty AIA.user_rules[:classify]
  end

  def test_skips_nil_rules_dir
    @config.rules.dir = nil

    router = AIA::RuleRouter.new

    assert_empty AIA.user_rules[:classify]
  end

  def test_handles_malformed_rule_file_gracefully
    write_rule_file('01_bad.rb', <<~RUBY)
      raise "intentional error in user rule file"
    RUBY

    # Should not crash — the error is rescued and warned
    router = nil
    capture_io do
      router = AIA::RuleRouter.new
    end

    refute_nil router
    # The bad file should not have registered any rules
    assert_empty AIA.user_rules[:classify]
  end

  # =========================================================================
  # Rule Application to KBs
  # =========================================================================

  def test_user_classify_rule_fires_on_matching_input
    write_rule_file('01_custom.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "detect_kubernetes" do
          on :turn_input do
            text matches(/\\b(kubernetes|k8s|kubectl|helm|pod)\\b/i)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "devops", subdomain: "kubernetes", source: "user_k8s_rule")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new
    decisions = router.evaluate_turn(@config, "deploy this to the kubernetes cluster using kubectl")

    k8s = decisions.classifications.select { |c| c[:subdomain] == "kubernetes" }
    refute_empty k8s, "Expected user kubernetes classification rule to fire"
    assert_equal "user_k8s_rule", k8s.first[:source]
  end

  def test_user_classify_rule_does_not_fire_on_non_matching_input
    write_rule_file('01_custom.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "detect_kubernetes" do
          on :turn_input do
            text matches(/\\b(kubernetes|k8s|kubectl)\\b/i)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "devops", source: "user_k8s_rule")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new
    decisions = router.evaluate_turn(@config, "write a function to sort an array")

    k8s = decisions.classifications.select { |c| c[:source] == "user_k8s_rule" }
    assert_empty k8s, "Kubernetes rule should not fire for unrelated input"
  end

  def test_user_gate_rule_fires
    write_rule_file('01_gate.rb', <<~RUBY)
      AIA.rules_for(:gate) do
        rule "custom_context_limit" do
          on :context_stats, large: true
          perform do |facts|
            AIA.decisions.add(:gate, action: "warn",
              message: "User rule: context is large")
          end
        end
      end
    RUBY

    temp_file = File.join(Dir.tmpdir, "user_rules_test_large_#{$$}.txt")
    File.write(temp_file, "x" * 200_000)
    @config.context_files = [temp_file]

    router = AIA::RuleRouter.new
    decisions = router.evaluate(@config)

    user_gates = decisions.gate_actions.select { |g| g[:message]&.include?("User rule") }
    refute_empty user_gates, "Expected user gate rule to fire for large context"
  ensure
    File.delete(temp_file) if temp_file && File.exist?(temp_file)
  end

  def test_user_rules_coexist_with_builtin_rules
    write_rule_file('01_custom.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "detect_security" do
          on :turn_input do
            text matches(/\\b(security|vulnerability|CVE|exploit)\\b/i)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "security", source: "user_security_rule")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new

    # Input that matches both a built-in rule (code) and user rule (security)
    decisions = router.evaluate_turn(@config, "fix this security vulnerability in the function")

    builtin = decisions.classifications.select { |c| c[:source] == "code_request" }
    user    = decisions.classifications.select { |c| c[:source] == "user_security_rule" }

    refute_empty builtin, "Built-in code_request rule should still fire"
    refute_empty user,    "User security rule should also fire"
  end

  # =========================================================================
  # AIA.decisions global access
  # =========================================================================

  def test_aia_decisions_is_set_on_router_init
    router = AIA::RuleRouter.new

    refute_nil AIA.decisions
    assert_instance_of AIA::Decisions, AIA.decisions
    assert_same router.decisions, AIA.decisions
  end

  def test_user_rule_can_add_decisions_via_aia_decisions
    write_rule_file('01_global.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "global_access_test" do
          on :turn_input do
            text matches(/global_test_marker/)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "test", source: "global_access")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new
    decisions = router.evaluate_turn(@config, "this contains global_test_marker in it")

    found = decisions.classifications.select { |c| c[:source] == "global_access" }
    refute_empty found, "User rule should be able to add decisions via AIA.decisions"
  end

  # =========================================================================
  # Multiple KBs targeted from same file
  # =========================================================================

  def test_single_file_can_target_multiple_kbs
    write_rule_file('01_multi.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "multi_classify" do
          on :turn_input do
            text matches(/multi_test/)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "multi", source: "multi_classify")
          end
        end
      end

      AIA.rules_for(:gate) do
        rule "multi_gate" do
          on :context_stats, large: true
          perform do |facts|
            AIA.decisions.add(:gate, action: "warn", message: "multi gate fired")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new

    assert_equal 1, AIA.user_rules[:classify].size
    assert_equal 1, AIA.user_rules[:gate].size
  end

  # =========================================================================
  # Rules disabled
  # =========================================================================

  def test_user_rules_still_load_when_rules_disabled
    @config.rules.enabled = false

    write_rule_file('01_test.rb', <<~RUBY)
      AIA.rules_for(:classify) do
        rule "loaded_but_not_fired" do
          on :turn_input do
            text matches(/anything/)
          end
          perform do |facts|
            AIA.decisions.add(:classification, domain: "test", source: "should_not_fire")
          end
        end
      end
    RUBY

    router = AIA::RuleRouter.new

    # Rules are loaded (registered in AIA.user_rules)
    assert_equal 1, AIA.user_rules[:classify].size

    # But they don't fire because rules are disabled
    decisions = router.evaluate_turn(@config, "anything goes here")
    assert_empty decisions.classifications
  end

  private

  def write_rule_file(filename, content)
    File.write(File.join(@rules_dir, filename), content)
  end
end
