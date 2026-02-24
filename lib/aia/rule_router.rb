# frozen_string_literal: true

# lib/aia/rule_router.rb
#
# Wraps KBS (Knowledge-Based System) for intelligent prompt/model/tool routing.
# Evaluates rules before robot.run() to modify config based on context.

require 'kbs/dsl'

module AIA
  class RuleRouter
    def initialize
      @suggestions = []
      @kb = build_knowledge_base
      load_user_rules
    end

    # Evaluate rules against the current configuration.
    # Called once before RobotFactory.build.
    #
    # @param config the AIA configuration
    def evaluate(config)
      return unless config.rules&.enabled

      @suggestions.clear
      @kb.reset
      assert_config_facts(config)
      @kb.run
      apply_decisions(config)
    rescue StandardError => e
      warn "Warning: Rule evaluation failed: #{e.message}"
    end

    # Evaluate rules for a single chat turn.
    # Called before each robot.run(input) in the chat loop.
    #
    # @param config the AIA configuration
    # @param input [String] the user's chat input
    def evaluate_turn(config, input)
      return unless config.rules&.enabled

      @suggestions.clear
      @kb.reset
      assert_config_facts(config)
      assert_turn_facts(input)
      @kb.run
      apply_decisions(config)
    rescue StandardError => e
      warn "Warning: Turn rule evaluation failed: #{e.message}"
    end

    private

    def build_knowledge_base
      suggestions = @suggestions

      KBS.knowledge_base do
        # Default rule: image files in context -> suggest vision model
        rule "image_context_detection" do
          on :context_file, extension: one_of('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp')
          perform do |facts|
            suggestions << { type: :model_hint, value: "vision-capable model recommended" }
          end
        end

        # Default rule: audio files in context -> suggest transcription
        rule "audio_context_detection" do
          on :context_file, extension: one_of('.mp3', '.wav', '.ogg', '.m4a', '.flac', '.aac')
          perform do |facts|
            suggestions << { type: :model_hint, value: "audio-capable model recommended" }
          end
        end

        # Default rule: large context -> note for user
        rule "large_context_warning" do
          on :context_stats, large: true
          perform do |facts|
            suggestions << { type: :context_warning, value: "large context detected, consider a model with a bigger context window" }
          end
        end
      end
    end

    def load_user_rules
      rules_dir = AIA.config&.rules&.dir
      return unless rules_dir

      rules_dir = File.expand_path(rules_dir)
      return unless Dir.exist?(rules_dir)

      Dir.glob(File.join(rules_dir, '*.rb')).sort.each do |rule_file|
        load rule_file
      rescue StandardError => e
        warn "Warning: Failed to load rule file '#{rule_file}': #{e.message}"
      end
    end

    def assert_config_facts(config)
      # Assert context file facts
      Array(config.context_files).each do |file|
        ext = File.extname(file).downcase
        @kb.assert(:context_file,
          path: file,
          extension: ext,
          exists: File.exist?(file)
        )
      end

      # Assert context size stats
      total_size = Array(config.context_files).sum do |f|
        File.exist?(f) ? File.size(f) : 0
      end
      @kb.assert(:context_stats,
        total_size: total_size,
        large: total_size > 100_000
      )

      # Assert model facts
      config.models.each do |spec|
        @kb.assert(:model, name: spec.name, role: spec.role)
      end

      # Assert flag facts
      @kb.assert(:flags,
        chat:      config.flags.chat,
        consensus: config.flags.consensus,
        debug:     config.flags.debug
      )
    end

    def assert_turn_facts(input)
      @kb.assert(:turn_input,
        text: input,
        length: input.length
      )
    end

    def apply_decisions(config)
      @suggestions.each do |suggestion|
        case suggestion[:type]
        when :context_warning
          warn "Note: #{suggestion[:value]}" if config.flags.verbose
        when :model_hint
          warn "Note: #{suggestion[:value]}" if config.flags.verbose
        end
      end
    end
  end
end
