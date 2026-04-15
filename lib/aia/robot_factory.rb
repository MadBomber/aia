# frozen_string_literal: true

# lib/aia/robot_factory.rb
#
# The core new abstraction in AIA v2.
# Builds RobotLab::Robot or RobotLab::Network instances from AIA configuration.
# Replaces the entire lib/aia/adapter/ directory from v1.

require 'pm'
require_relative 'robot_namer'
require_relative 'tool_loader'
require_relative 'system_prompt_assembler'
require_relative 'network_builder'
require_relative 'history_transfer'

module AIA
  class RobotFactory
    class << self
      # One-time startup configuration of RobotLab loggers and providers.
      # Must be called once before the first build (e.g., in AIA.run).
      #
      # @param config [AIA::Config] the AIA configuration
      def setup(config)
        configure_robot_lab(config)
      end

      # Build a Robot or Network from the current AIA config
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot, RobotLab::Network] the built robot or network
      def build(config = AIA.config)
        namer = RobotNamer.new(first_name: 'Tobor')
        if ToolLoader.cached_tools
          config.loaded_tools = ToolLoader.cached_tools
          config.tool_names = ToolLoader.cached_tools.map { |t| t.respond_to?(:name) ? t.name : t.class.name }.join(', ')
        else
          ToolLoader.load_tools(config)
        end

        if config.pipeline.length > 1
          NetworkBuilder.build_pipeline_network(config, namer)
        elsif config.models.length > 1
          build_multi_model(config, namer)
        else
          build_single_robot(config, namer)
        end
      rescue RubyLLM::ModelNotFoundError => e
        model_names = config.models.map(&:name).join(', ')
        raise AIA::ConfigurationError,
              "#{e.message}\nRequested model(s): #{model_names}\nRun 'aia --available-models' to see available models."
      end

      # Rebuild robot(s) after config changes (e.g., /model, /config directives).
      # Supports conversation history transfer modes.
      # Reuses cached tools from the initial build (I4/I5).
      #
      # @param config [AIA::Config] the AIA configuration
      # @param history_mode [Symbol] :clean, :replay, or :summarize
      # @return [RobotLab::Robot, RobotLab::Network]
      def rebuild(config = AIA.config, history_mode: :clean)
        old_robot = AIA.client
        new_robot = build(config)

        case history_mode
        when :replay
          HistoryTransfer.replay_history(old_robot, new_robot)
        when :summarize
          HistoryTransfer.summarize_history(old_robot, new_robot)
        end

        new_robot
      end

      # --- Forwarding wrappers for backward compatibility ---

      def clear_tool_cache!
        ToolLoader.clear_cache!
      end

      def filtered_tools(config)
        ToolLoader.filtered_tools(config)
      end

      def resolve_system_prompt(config, model_spec = nil)
        SystemPromptAssembler.resolve_system_prompt(config, model_spec)
      end

      def build_identity_prompt(robot_name, spec, roster)
        SystemPromptAssembler.build_identity_prompt(robot_name, spec, roster)
      end

      # Build a concurrent MCP network where independent server groups
      # run in parallel with a synthesizer to merge results.
      #
      # @param config [AIA::Config] the AIA configuration
      # @param server_groups [Array<Array<Hash>>] groups of MCP server configs
      # @return [RobotLab::Network]
      def build_concurrent_mcp_network(config, server_groups)
        namer = RobotNamer.new(first_name: 'Tobor')
        NetworkBuilder.build_concurrent_mcp_network(config, namer, server_groups)
      end

      # Build a single robot for one model.
      # Delegates to RobotBuilder for single-robot construction.
      #
      # @param config [AIA::Config] the AIA configuration
      # @param namer [AIA::RobotNamer] fresh namer for this build
      # @return [RobotLab::Robot]
      def build_single_robot(config, namer)
        RobotBuilder.build(config, namer: namer)
      end

      # Build RunConfig from AIA configuration.
      def build_run_config(config)
        params = {
          temperature: config.llm.temperature,
          top_p:       config.llm.top_p,
          max_tokens:  config.llm.max_tokens
        }

        fp = config.llm.frequency_penalty
        params[:frequency_penalty] = fp if fp && fp != 0.0

        pp = config.llm.presence_penalty
        params[:presence_penalty] = pp if pp && pp != 0.0

        RobotLab::RunConfig.new(**params)
      end

      # Normalize all configured MCP server configs for robot_lab.
      # Filtering/selection is MCPDiscovery's responsibility — this just normalizes shape.
      def mcp_server_configs(config)
        return [] if config.flags.no_mcp
        Array(config.mcp_servers).map { |s| MCPConfigNormalizer.normalize(s) }
      end

      # Normalize a single MCP server config to robot_lab's nested transport format.
      # Delegates to MCPConfigNormalizer.
      def normalize_mcp_config(server)
        MCPConfigNormalizer.normalize(server)
      end

      # Initialize shared memory for a network with session context.
      # Delegates to NetworkMemoryManager.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      # @return [RobotLab::Network]
      def initialize_network_memory(network, config)
        NetworkMemoryManager.initialize_memory(network, config)
      end

      # Set up memory subscriptions for debug logging and completion tracking.
      # Delegates to NetworkMemoryManager.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      def setup_memory_subscriptions(network, config)
        NetworkMemoryManager.setup_subscriptions(network, config)
      end

      # Attach a shared TypedBus message bus to all robots in a network.
      #
      # @param network [RobotLab::Network]
      # @return [TypedBus::MessageBus, nil]
      def attach_bus(network)
        return nil unless network.respond_to?(:robots)

        bus = TypedBus::MessageBus.new
        network.robots.each_value { |robot| robot.with_bus(bus) }
        bus
      end

      # Map AIA provider aliases to RubyLLM provider slugs.
      def resolve_provider(model_spec)
        case model_spec.provider
        when 'lms' then 'openai'
        else model_spec.provider
        end
      end

      private

      # Configure RobotLab providers from AIA config
      def configure_robot_lab(config)
        # Configure loggers before any API calls
        AIA::LoggerManager.configure_llm_logger
        AIA::LoggerManager.configure_mcp_logger

        # Route RobotLab's internal logging through AIA's MCP logger
        # so entries go to the configured log files instead of STDOUT.
        # Must use direct assignment — block form doesn't set runtime attrs.
        RobotLab.config.logger = AIA::LoggerManager.mcp_logger

        RobotLab.config do |c|
          c.ruby_llm do |r|
            r.request_timeout = 120
          end
        end

        # RobotLab's after_load sets PM.config.prompts_dir to its own default ('prompts').
        # Restore AIA's configured prompts dir so PM.parse finds the correct files.
        PM.configure { |c| c.prompts_dir = AIA.config.prompts.dir }

        # Configure local provider API endpoints from environment variables
        configure_local_providers(config)
      end

      # Set API base URLs for local providers (Ollama, LM Studio) so
      # RubyLLM can reach them. Reads from standard env vars.
      def configure_local_providers(config)
        providers_used = config.models.map(&:provider).compact.uniq
        return if providers_used.empty?

        RubyLLM.configure do |c|
          if providers_used.include?('ollama')
            c.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434')
          end

          if providers_used.include?('lms')
            # LM Studio exposes an OpenAI-compatible API.
            # Set openai_api_base to LM Studio's endpoint.
            c.openai_api_base = ENV.fetch('LMS_API_BASE', 'http://localhost:1234')
          end
        end
      end

      # Decide between consensus and parallel multi-model.
      # Initializes shared memory and subscriptions on the resulting network.
      #
      # @param config [AIA::Config] the AIA configuration
      # @param namer [AIA::RobotNamer] fresh namer for this build
      def build_multi_model(config, namer)
        network = if config.flags.consensus
                    NetworkBuilder.build_consensus_network(config, namer)
                  else
                    NetworkBuilder.build_parallel_network(config, namer)
                  end
        initialize_network_memory(network, config)
        setup_memory_subscriptions(network, config)
        network
      end
    end
  end
end
