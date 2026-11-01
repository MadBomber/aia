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
  # :reek:TooManyMethods -- factory facade: every robot/network build variant plus its run-config helpers lives behind one entry point
  class RobotFactory
    # The max_tokens default from defaults.yml — optimised for cloud APIs that treat
    # it as an output-only cap. Local providers (Ollama, LM Studio) bound input+output
    # to a shared context window, so sending this value causes truncation on long turns.
    DEFAULT_LOCAL_MAX_TOKENS = 32_767

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
        apply_tool_cache(config)

        # The interactive session always runs a *crew* (a Network), so robots can
        # be recruited/dropped at runtime. A single model is wrapped in a one-member
        # crew whose chief is that robot; multi-model aggregation networks are
        # already Networks. (Normal turns still stream via the chief — see ChatLoop.)
        if config.models.length > 1
          build_multi_model(config, namer)
        else
          build_crew(build_single_robot(config, namer))
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

      # Reuse the build-time tool cache when present, else load tools fresh.
      def apply_tool_cache(config)
        cached = ToolLoader.cached_tools
        if cached
          config.loaded_tools = cached
          config.tool_names = cached.map { |t| t.respond_to?(:name) ? t.name : t.class.name }.join(', ')
        else
          ToolLoader.load_tools(config)
        end
      end

      # Wrap a single robot in a one-member crew Network so the session can
      # recruit/drop robots at runtime. The robot becomes the crew's chief
      # (the lone pipeline task); normal turns are routed to it directly so
      # token streaming is preserved.
      #
      # @param chief [RobotLab::Robot]
      # @return [RobotLab::Network]
      def build_crew(chief)
        RobotLab.create_network(name: 'aia-crew') do
          task chief.name.to_sym, chief, depends_on: :none
        end
      end

      # Build RunConfig from AIA configuration.
      # Uses the ruby_llm model registry to skip parameters the model doesn't support:
      # - temperature is omitted for models that declare temperature: false in metadata
      # - max_tokens remains a RobotLab::RunConfig field; AIA normalizes it at
      #   the RubyLLM/OpenAI provider boundary for models that need
      #   max_completion_tokens
      # :reek:TooManyStatements -- one guarded param per LLM tuning knob, with provider-specific max_tokens handling
      def build_run_config(config)
        model_spec = config.models.first
        llm        = config.llm
        params     = {}

        temp = llm.temperature
        params[:temperature] = temp if temp && model_supports_temperature?(model_spec)

        max = llm.max_tokens
        # Local providers (Ollama, LM Studio) have a small total context window
        # (input + output combined, typically 32768 tokens for qwen3-class models).
        # Sending the cloud default of 32767 as num_predict leaves almost no room
        # once the input context grows across turns, causing mid-response truncation.
        # Skip max_tokens for local providers when it's still at the cloud default;
        # honour it when the user has explicitly set a smaller value.
        local = model_spec&.local_provider?
        params[:max_tokens] = max if max && !(local && max == DEFAULT_LOCAL_MAX_TOKENS)

        tp = llm.top_p
        params[:top_p] = tp if tp

        fp = llm.frequency_penalty
        params[:frequency_penalty] = fp if fp && fp != 0.0

        pp = llm.presence_penalty
        params[:presence_penalty] = pp if pp && pp != 0.0

        RobotLab::RunConfig.new(**params)
      end

      # Returns false for models that explicitly declare temperature: false in the
      # ruby_llm model registry (e.g. gpt-5.4, o1, o3 reasoning models).
      def model_supports_temperature?(model_spec)
        return true unless model_spec
        info = RubyLLM.models.find(model_spec.name)
        info.metadata[:temperature] != false
      rescue StandardError
        true
      end

      # The MCP servers to hand a robot as RobotLab.build(mcp:).
      #
      # Once MCPConnectionManager.start has run, these are the live
      # RubyLLM::MCP instances it connected, shared by every robot so each
      # server is started once; servers that failed to connect are left out.
      # Before that (or without a manager) they are normalized config Hashes,
      # which robot_lab connects lazily on the robot's first run.
      #
      # @param config [AIA::Config]
      # @param group [Array<Hash>, nil] a subset of server configs (concurrent MCP
      #   networks); defaults to MCPDiscovery's selection (--mcp-use/--mcp-skip)
      # @return [Array<RubyLLM::MCP, Hash>]
      def mcp_servers(config, group = nil)
        return [] if config.flags.no_mcp

        configs = group || MCPDiscovery.new.discover(config)
        manager = AIA.mcp_manager
        return manager.servers_for(configs) if manager&.connected?

        configs.map { |s| MCPConfigNormalizer.normalize(s) }
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

      # Build a RobotLab::Robot for a model spec, applying provider resolution.
      # Centralizes the "set provider if the spec has one, then build" tail that
      # every robot/network builder needs, so provider routing can't be
      # forgotten at a new build site.
      #
      # @param spec [AIA::Config::ModelSpec] the model spec (supplies model: and provider)
      # @param opts [Hash] forwarded to RobotLab.build (name:, system_prompt:,
      #   local_tools:, mcp:, config:, on_content:, ...). Do NOT pass model:.
      # @return [RobotLab::Robot]
      def build_robot(spec, **opts)
        opts[:provider] = resolve_provider(spec) if spec.provider
        RobotLab.build(model: spec.name, **opts)
      end

      # Resolve a spec's provider to a RubyLLM provider slug. Slugs pass
      # through unchanged — RubyLLM's registry is the single source of truth —
      # but the method stays as the seam where optional provider gems get
      # loaded on demand and where a future alias mapping would live.
      def resolve_provider(model_spec)
        provider = model_spec.provider
        ensure_provider_loaded(provider)
        provider
      end

      # Make sure a provider slug is registered with RubyLLM, loading its
      # conventional gem on demand. An unknown provider only warns here —
      # RubyLLM raises its own clear error later when the slug is truly
      # unresolvable.
      def ensure_provider_loaded(provider)
        return if provider.nil? || ProviderRegistry.available?(provider)

        AIA.debug_warn(
          "provider '#{provider}' is not registered with RubyLLM and no " \
          "ruby_llm/providers/#{provider} library could be loaded"
        )
      end

      private

      # Configure RobotLab providers from AIA config
      def configure_robot_lab(config)
        # Configure loggers before any API calls
        AIA::LoggerManager.configure_llm_logger

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

        # Wire audio model settings into RubyLLM config
        configure_audio(config)
      end

      # Wire AIA's audio config into RubyLLM so transcription calls pick up
      # the user-configured model without requiring explicit model: arguments.
      # speech_model has no ruby_llm TTS API backing yet — it is exposed as
      # the SPEECH_MODEL env var for custom speak_command scripts.
      def configure_audio(config)
        transcription_model = config.audio&.transcription_model
        return unless transcription_model

        RubyLLM.configure { |c| c.default_transcription_model = transcription_model }
      end

      # Make every provider named by the configured models available, then
      # apply generic env-var endpoint overrides: <SLUG>_API_BASE sets
      # RubyLLM.config.<slug>_api_base for every registered provider that
      # defines the option. Providers ship their own endpoint defaults, so
      # nothing is set unless the user overrides it.
      def configure_local_providers(config)
        config.models.map(&:provider).compact.uniq.each { |provider| ensure_provider_loaded(provider) }
        ProviderRegistry.apply_env_endpoints
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
