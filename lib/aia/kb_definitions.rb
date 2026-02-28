# frozen_string_literal: true

# lib/aia/kb_definitions.rb
#
# Static knowledge base definitions for the rule engine.
# Extracted from RuleRouter to improve single-responsibility.
# Each method builds a KBS::KnowledgeBase with domain-specific rules.

require 'kbs/dsl'

module AIA
  module KBDefinitions
    module_function

    # Build all five knowledge bases.
    #
    # @param decisions [AIA::Decisions] the decisions container
    # @return [Hash{Symbol => KBS::KnowledgeBase}]
    def build_all_kbs(decisions)
      {
        classify:     build_classification_kb(decisions),
        model_select: build_model_selection_kb(decisions),
        route:        build_routing_kb(decisions),
        gate:         build_quality_gate_kb(decisions),
        learn:        build_learning_kb(decisions),
      }
    end

    # KB 1: Input Classification
    # Categorizes user prompts by domain, complexity, and intent.
    def build_classification_kb(decisions)
      KBS.knowledge_base do
        # Domain classification rules
        rule "code_request" do
          on :turn_input do
            text matches(/\b(refactor|debug|implement|function|class|method|test|bug|fix|compile|lint)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "code", source: "code_request")
          end
        end

        rule "data_request" do
          on :turn_input do
            text matches(/(sql|database|\bquery\b|\btable\b|\bschema\b|\brecord\b|\bselect\b|\binsert\b|\bmigration\b|\bredis\b|\bmongo)/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "data", source: "data_request")
          end
        end

        rule "image_request" do
          on :turn_input do
            text matches(/\b(draw|image|picture|diagram|generate.*image|create.*image|photo|illustration)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "image", source: "image_request")
          end
        end

        rule "planning_request" do
          on :turn_input do
            text matches(/\b(plan|task|project|roadmap|milestone|schedule|workflow|organize|prioritize)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, domain: "planning", source: "planning_request")
          end
        end

        # Context-based classification
        rule "image_context_detection" do
          on :context_file, extension: one_of('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp')
          perform do |facts|
            decisions.add(:classification, domain: "image", source: "image_context")
          end
        end

        rule "audio_context_detection" do
          on :context_file, extension: one_of('.mp3', '.wav', '.ogg', '.m4a', '.flac', '.aac')
          perform do |facts|
            decisions.add(:classification, domain: "audio", source: "audio_context")
          end
        end

        rule "code_context_detection" do
          on :context_file, extension: one_of('.rb', '.py', '.js', '.ts', '.go', '.rs', '.java', '.c', '.cpp', '.swift')
          perform do |facts|
            decisions.add(:classification, domain: "code", source: "code_context")
          end
        end

        # Complexity classification
        rule "short_factual_query" do
          on :turn_input do
            length less_than(100)
          end
          perform do |facts|
            decisions.add(:classification, domain: "general", complexity: "low", source: "short_query")
          end
        end

        rule "complex_query" do
          on :turn_input do
            length greater_than(500)
          end
          perform do |facts|
            decisions.add(:classification, complexity: "high", source: "long_query")
          end
        end

        # Intent detection for model switching
        rule "model_switch_request" do
          on :turn_input do
            text matches(/\b(switch|use|try|change)\b.*\b(to|model)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch",
              raw_text: facts[0][:text], source: "model_switch_request")
          end
        end

        rule "model_compare_request" do
          on :turn_input do
            text matches(/\b(compare|hear from|also.*ask|get.*opinion)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_compare",
              raw_text: facts[0][:text], source: "model_compare_request")
          end
        end

        rule "cheaper_model_request" do
          on :turn_input do
            text matches(/\b(cheap|fast|quick|budget|less expensive|save)\b.*\b(model|one)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch_capability",
              capability: "cheap", raw_text: facts[0][:text], source: "cheaper_model_request")
          end
        end

        rule "better_model_request" do
          on :turn_input do
            text matches(/\b(best|better|smart|powerful|premium)\b.*\b(model|one)\b/i)
          end
          perform do |facts|
            decisions.add(:classification, type: :intent, action: "model_switch_capability",
              capability: "best", raw_text: facts[0][:text], source: "better_model_request")
          end
        end
      end
    end

    # KB 2: Model Selection
    # Reads classification decisions and matches to model capabilities.
    def build_model_selection_kb(decisions)
      KBS.knowledge_base do
        rule "vision_model_needed" do
          on :classification_decision, domain: "image"
          on :model, supports_vision: true
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "vision capability needed")
          end
        end

        rule "audio_model_needed" do
          on :classification_decision, domain: "audio"
          on :model, supports_audio: true
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "audio capability needed")
          end
        end

        rule "cheap_model_for_simple" do
          on :classification_decision, complexity: "low"
          on :model, cost_tier: "low"
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "simple query — save cost")
          end
        end

        rule "powerful_model_for_complex" do
          on :classification_decision, complexity: "high"
          on :model, cost_tier: satisfies { |t| t == "high" || t == "premium" }
          perform do |facts|
            decisions.add(:model_decision,
              model: facts[1][:name],
              reason: "complex query — needs capable model")
          end
        end
      end
    end

    # KB 3: MCP/Tool Routing
    # MCP routing rules are built-in (MCP servers declare topics).
    # Tool routing rules are built dynamically by DynamicRuleBuilder
    # after RobotFactory discovers the actual loaded tools.
    def build_routing_kb(decisions)
      KBS.knowledge_base do
        rule "code_mcp_routing" do
          on :classification_decision, domain: "code"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("code") || t.include?("files")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "code domain")
          end
        end

        rule "data_mcp_routing" do
          on :classification_decision, domain: "data"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("data") || t.include?("sql")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "data domain")
          end
        end

        rule "planning_mcp_routing" do
          on :classification_decision, domain: "planning"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("planning") || t.include?("tasks")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "planning domain")
          end
        end

        rule "search_mcp_routing" do
          on :classification_decision, domain: "general"
          on :mcp_server, topics: satisfies { |t| t.is_a?(Array) && (t.include?("search") || t.include?("web")) }
          perform do |facts|
            decisions.add(:mcp_activate, server: facts[1][:name], reason: "general search")
          end
        end
      end
    end

    # KB 4: Quality Gates
    # Pre-send checks that can warn or block.
    def build_quality_gate_kb(decisions)
      KBS.knowledge_base do
        rule "prompt_too_vague" do
          on :turn_input do
            length less_than(10)
          end
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Prompt seems vague. Consider adding more detail.")
          end
        end

        rule "large_context_warning" do
          on :context_stats, large: true
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Context exceeds 100KB. Consider a model with a larger context window.")
          end
        end

        rule "cost_warning" do
          on :session_stats, total_cost: greater_than(5.0)
          perform do |facts|
            decisions.add(:gate, action: "warn",
              message: "Session cost is over $5. Consider a cheaper model.")
          end
        end
      end
    end

    # KB 5: Post-Response Learning
    # Runs after LLM responds to track outcomes.
    def build_learning_kb(decisions)
      KBS.knowledge_base do
        rule "track_model_switch" do
          on :response_outcome, user_switched_model: true
          perform do |facts|
            decisions.add(:learning, signal: "model_dissatisfaction",
              model: facts[0][:model])
          end
        end

        rule "track_success" do
          on :response_outcome, accepted: true
          perform do |facts|
            decisions.add(:learning, signal: "model_success",
              model: facts[0][:model])
          end
        end

        rule "cost_tracking" do
          on :session_stats, total_cost: greater_than(0)
          perform do |facts|
            decisions.add(:learning, signal: "cost_update",
              total: facts[0][:total_cost])
          end
        end
      end
    end
  end
end
