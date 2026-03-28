# frozen_string_literal: true

# lib/aia/fact_asserter.rb
#
# Translates AIA state (config, input, session tracker, decisions)
# into KBS facts via kb.assert(...). Extracted from RuleRouter to
# improve single-responsibility and testability.

module AIA
  class FactAsserter
    # Dispatch fact assertions based on the KB being evaluated.
    #
    # @param kb the KBS knowledge base
    # @param kb_name [Symbol] which KB (:classify, :model_select, :route, :gate)
    # @param config the AIA configuration
    # @param input [String, nil] optional user input text
    def assert_facts_for(kb, kb_name, config, input)
      case kb_name
      when :classify
        assert_context_facts(kb, config)
        assert_turn_facts(kb, input) if input
      when :model_select
        assert_model_facts(kb, config)
      when :route
        assert_mcp_facts(kb, config)
        assert_tool_facts(kb, config)
        assert_turn_facts(kb, input) if input
      when :gate
        assert_context_stats(kb, config)
        assert_turn_facts(kb, input) if input
        assert_session_facts(kb)
      end
    end

    # Assert upstream decisions as facts for downstream KBs.
    #
    # @param kb the KBS knowledge base
    # @param kb_name [Symbol] which KB
    # @param decisions [AIA::Decisions] the accumulated decisions
    def assert_decision_facts(kb, kb_name, decisions)
      case kb_name
      when :model_select
        decisions.classifications.each do |c|
          kb.assert(:classification_decision, **c)
        end
      when :route
        decisions.classifications.each do |c|
          kb.assert(:classification_decision, **c)
        end
        decisions.model_decisions.each do |m|
          kb.assert(:model_decision_upstream, **m)
        end
      when :gate
        decisions.model_decisions.each do |m|
          kb.assert(:model_decision, **m)
        end
      end
    end

    # Assert response outcome and session stats for the learn KB.
    #
    # @param kb the KBS knowledge base
    # @param outcome [Hash] response outcome data
    def assert_response_facts(kb, outcome)
      kb.assert(:response_outcome, **outcome) if outcome.is_a?(Hash) && outcome.any?

      tracker = AIA.session_tracker
      kb.assert(:session_stats, **tracker.to_facts) if tracker
    end

    # Public tool info helpers — also used by RuleRouter#register_tools.

    def tool_name(tool_class)
      if tool_class.respond_to?(:name)
        tool_class.name.to_s
      else
        tool_class.to_s
      end
    end

    def tool_description(tool_class)
      if tool_class.respond_to?(:description)
        tool_class.description.to_s
      else
        ""
      end
    rescue StandardError
      ""
    end

    private

    # =========================================================================
    # Fact Assertion Methods
    # =========================================================================

    def assert_context_facts(kb, config)
      Array(config.context_files).each do |file|
        ext = File.extname(file).downcase
        kb.assert(:context_file,
          path: file,
          extension: ext,
          exists: File.exist?(file)
        )
      end
    end

    def assert_context_stats(kb, config)
      total_size = Array(config.context_files).sum do |f|
        File.exist?(f) ? File.size(f) : 0
      end
      kb.assert(:context_stats,
        total_size: total_size,
        large: total_size > 100_000
      )
    end

    def assert_model_facts(kb, config)
      config.models.each do |spec|
        model_info = find_model_info(spec.name)

        if model_info
          kb.assert(:model,
            name:            spec.name,
            role:            spec.role,
            provider:        model_info_provider(model_info),
            context_window:  model_info_context_window(model_info),
            supports_vision: model_info_vision(model_info),
            supports_audio:  model_info_audio(model_info),
            cost_tier:       classify_cost(model_info)
          )
        else
          kb.assert(:model, name: spec.name, role: spec.role)
        end
      end
    end

    def assert_mcp_facts(kb, config)
      return if config.flags&.no_mcp

      Array(config.mcp_servers).each do |server|
        kb.assert(:mcp_server,
          name:   server[:name] || server["name"],
          topics: server[:topics] || server["topics"] || [],
          active: true
        )
      end
    end

    def assert_tool_facts(kb, config)
      tools = all_registered_tools(config)
      tools.each do |tool_class|
        name = tool_name(tool_class)
        desc = tool_description(tool_class)
        server = tool_class.respond_to?(:mcp) ? tool_class.mcp&.to_s : nil
        kb.assert(:tool,
          name:        name,
          description: desc,
          server:      server,
          active:      true
        )
      end
    end

    def assert_turn_facts(kb, input)
      kb.assert(:turn_input,
        text: input,
        length: input.length
      )
    end

    def assert_session_facts(kb)
      tracker = AIA.session_tracker
      return unless tracker

      kb.assert(:session_stats, **tracker.to_facts)
    end

    # =========================================================================
    # Model Info Helpers
    # =========================================================================

    def find_model_info(model_name)
      return nil unless defined?(RubyLLM) && RubyLLM.respond_to?(:models)
      RubyLLM.models.find(model_name)
    rescue StandardError
      nil
    end

    def model_info_provider(info)
      info.respond_to?(:provider) ? info.provider : nil
    end

    def model_info_context_window(info)
      info.respond_to?(:context_window) ? info.context_window : nil
    end

    def model_info_vision(info)
      if info.respond_to?(:supports?)
        info.supports?(:vision)
      else
        false
      end
    rescue StandardError
      false
    end

    def model_info_audio(info)
      if info.respond_to?(:supports?)
        info.supports?(:audio)
      else
        false
      end
    rescue StandardError
      false
    end

    def classify_cost(model_info)
      input_cost = if model_info.respond_to?(:input_price_per_million)
                     model_info.input_price_per_million || 0
                   else
                     0
                   end

      case input_cost
      when 0..1     then "low"
      when 1..10    then "medium"
      when 10..50   then "high"
      else               "premium"
      end
    end

    # =========================================================================
    # Tool Collection Helpers
    # =========================================================================

    # Collect local + MCP tools so route rules can match against all of them.
    def all_registered_tools(config)
      local = Array(config.loaded_tools)
      mcp   = collect_robot_mcp_tools
      local + mcp
    end

    # Retrieve MCP tools from the robot (injected via MCPConnectionManager),
    # falling back to RubyLLM::MCP.clients for --require registered clients.
    def collect_robot_mcp_tools
      robot = AIA.client
      if robot
        if robot.respond_to?(:mcp_tools) && robot.mcp_tools&.any?
          return Array(robot.mcp_tools)
        end
        if robot.respond_to?(:robots) && robot.robots.is_a?(Hash)
          first = robot.robots.values.first
          tools = Array(first&.mcp_tools)
          return tools if tools.any?
        end
      end
      return [] unless defined?(RubyLLM::MCP)
      RubyLLM::MCP.clients.values.flat_map(&:tools)
    end
  end
end
