# frozen_string_literal: true

# lib/aia/robot_factory.rb
#
# The core new abstraction in AIA v2.
# Builds RobotLab::Robot or RobotLab::Network instances from AIA configuration.
# Replaces the entire lib/aia/adapter/ directory from v1.

require_relative 'robot_namer'

module AIA
  class RobotFactory
    class << self
      # Build a Robot or Network from the current AIA config
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot, RobotLab::Network] the built robot or network
      def build(config = AIA.config)
        @namer = RobotNamer.new(first_name: 'Tobor')
        configure_robot_lab(config)
        if @tool_cache
          config.loaded_tools = @tool_cache
          config.tool_names = @tool_cache.map { |t| t.respond_to?(:name) ? t.name : t.class.name }.join(', ')
        else
          load_tools(config)
        end

        if config.pipeline.length > 1
          build_pipeline_network(config)
        elsif config.models.length > 1
          build_multi_model(config)
        else
          build_single_robot(config)
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
          replay_history(old_robot, new_robot)
        when :summarize
          summarize_history(old_robot, new_robot)
        end

        new_robot
      end

      # Clear the cached tool discovery results.
      # Call when tool paths change via /config directive.
      def clear_tool_cache!
        @tool_cache = nil
      end

      # Build a concurrent MCP network where independent server groups
      # run in parallel with a synthesizer to merge results.
      #
      # @param config [AIA::Config] the AIA configuration
      # @param server_groups [Array<Array<Hash>>] groups of MCP server configs
      # @return [RobotLab::Network]
      def build_concurrent_mcp_network(config, server_groups)
        run_config = build_run_config(config)
        tools = filtered_tools(config)
        model_spec = config.models.first
        system_prompt = resolve_system_prompt(config, model_spec)
        namer = @namer

        network = RobotLab.create_network(name: "aia-concurrent-mcp") do
          server_groups.each_with_index do |group, i|
            build_opts = {
              name:          "#{namer.name_for(model_spec.name)}-w#{i}",
              model:         model_spec.name,
              system_prompt: system_prompt,
              local_tools:   tools,
              mcp_servers:   group.map { |s| RobotFactory.normalize_mcp_config( s) },
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.resolve_provider( model_spec) if model_spec.provider
            robot = RobotLab.build(**build_opts)
            task :"mcp_worker_#{i}", robot, depends_on: :none
          end

          synth_opts = {
            name:          "Weaver",
            model:         model_spec.name,
            system_prompt: "You are a synthesizer. Merge the following results from " \
                           "multiple specialized queries into a coherent response. " \
                           "Preserve all relevant information. Resolve contradictions.",
            config:        run_config
          }
          synth_opts[:provider] = RobotFactory.resolve_provider( model_spec) if model_spec.provider
          synthesizer = RobotLab.build(**synth_opts)
          task :synthesize, synthesizer,
               depends_on: server_groups.each_index.map { |i| :"mcp_worker_#{i}" }
        end

        initialize_network_memory(network, config)
        setup_memory_subscriptions(network, config)
        network
      end

      # Build a single robot for one model
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot]
      def build_single_robot(config)
        model_spec = config.models.first
        robot_name = @namer.name_for(model_spec.name)
        identity = build_identity_prompt(robot_name, model_spec, [{ name: robot_name, spec: model_spec }])
        base_prompt = resolve_system_prompt(config, model_spec)
        system_prompt = [identity, base_prompt].compact.join("\n\n")

        build_opts = {
          name:          robot_name,
          system_prompt: system_prompt,
          model:         model_spec.name,
          local_tools:   filtered_tools(config),
          mcp_servers:   mcp_server_configs(config),
          on_content:    build_streaming_callback(config),
          config:        build_run_config(config)
        }
        build_opts[:provider] = resolve_provider(model_spec) if model_spec.provider

        RobotLab.build(**build_opts)
      end

      # --- Public helpers used by ExpertRouter, VerificationNetwork, etc. ---

      # Resolve system prompt from config (including role)
      def resolve_system_prompt(config, model_spec = nil)
        system_prompt = config.prompts.system_prompt

        role_id = model_spec&.role || config.prompts.role
        if role_id && !role_id.empty?
          role_content = load_role_content(config, role_id)
          if role_content
            system_prompt = [system_prompt, role_content].compact.join("\n\n")
          end
        end

        system_prompt
      end

      # Filter tools based on allowed/rejected lists
      def filtered_tools(config)
        tools = config.loaded_tools || []
        allowed = config.tools&.allowed
        rejected = config.tools&.rejected

        if allowed && !allowed.empty?
          allowed_list = Array(allowed).map(&:strip).map(&:downcase)
          tools = tools.select do |t|
            name = (t.respond_to?(:name) ? t.name : t.class.name).downcase
            allowed_list.any? { |a| name.include?(a) }
          end
        end

        if rejected && !rejected.empty?
          rejected_list = Array(rejected).map(&:strip).map(&:downcase)
          tools = tools.reject do |t|
            name = (t.respond_to?(:name) ? t.name : t.class.name).downcase
            rejected_list.any? { |r| name.include?(r) }
          end
        end

        seen = {}
        tools.select do |t|
          name = t.respond_to?(:name) ? t.name : t.class.name
          if seen[name]
            false
          else
            seen[name] = true
            true
          end
        end
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

      # Build MCP server configs for robot_lab from AIA config.
      def mcp_server_configs(config)
        return [] if config.flags.no_mcp
        servers = config.mcp_servers || []
        return [] if servers.empty?

        use_list  = Array(config.mcp_use)
        skip_list = Array(config.mcp_skip)

        if !use_list.empty?
          servers = servers.select { |s| Utility.server_name(s) }
                          .select { |s| use_list.include?(Utility.server_name(s)) }
        elsif !skip_list.empty?
          servers = servers.reject { |s| skip_list.include?(Utility.server_name(s)) }
        end

        servers.map { |s| normalize_mcp_config(s) }
      end

      # Normalize MCP server config to robot_lab's nested transport format.
      # McpParser now outputs this format natively; this method provides
      # backward compatibility for any configs that still use flat format.
      def normalize_mcp_config(server)
        server = server.is_a?(Hash) ? server.transform_keys(&:to_sym) : server.to_h.transform_keys(&:to_sym)

        # Already in robot_lab format — pass through
        return server if server[:transport]

        # Legacy flat format: wrap command/args/env into transport
        name = server[:name]
        transport = { type: server[:type] || 'stdio' }
        transport[:command] = server[:command] if server[:command]
        transport[:args]    = Array(server[:args]) if server[:args]
        transport[:env]     = server[:env] if server[:env]

        result = { name: name, transport: transport }
        result[:timeout] = server[:timeout] if server[:timeout]
        result
      end

      # Initialize shared memory for a network with session context.
      # Populates data keys that robots can read during execution.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      # @return [RobotLab::Network]
      def initialize_network_memory(network, config)
        return network unless network.respond_to?(:memory)

        memory = network.memory
        memory.data.session_id  = SecureRandom.hex(8)
        memory.data.model_count = config.models.size
        memory.data.model_names = config.models.map(&:name)
        memory.data.mode        = config.flags.consensus ? :consensus : :parallel
        memory.data.turn_count  = 0

        network
      end

      # Set up memory subscriptions for debug logging and completion tracking.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      def setup_memory_subscriptions(network, config)
        return unless network.respond_to?(:memory)

        memory = network.memory

        if config.flags.debug
          memory.subscribe_pattern("result_*") do |change|
            AIA::LoggerManager.aia_logger.debug(
              "Memory: #{change.key} by #{change.writer} at #{change.timestamp}"
            )
          end
        end

        memory.set(:completed_count, 0)
        memory.subscribe_pattern("result_*") do |change|
          next unless change.created?
          count = memory.get(:completed_count) || 0
          memory.set(:completed_count, count + 1)
        end
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

      # Build a system prompt fragment that tells a robot its name, its
      # model, and the other robots in the network.
      #
      # @param robot_name [String] this robot's creative name
      # @param spec [ModelSpec] this robot's model spec
      # @param roster [Array<Hash>] all robots: [{ name:, spec: }, ...]
      # @return [String]
      def build_identity_prompt(robot_name, spec, roster)
        provider_label = spec.provider ? " (#{spec.provider})" : ""
        lines = ["You are #{robot_name}, powered by #{spec.name}#{provider_label}."]

        if roster.size > 1
          lines << "You are part of a team of AI robots:"
          roster.each do |entry|
            p = entry[:spec].provider ? " (#{entry[:spec].provider})" : ""
            marker = entry[:name] == robot_name ? " ← you" : ""
            lines << "  - #{entry[:name]}: #{entry[:spec].name}#{p}#{marker}"
          end
          lines << "Users can address a specific robot with @name mentions."
        end

        lines.join("\n")
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

      # Load tools from require_libs and tool paths, then cache the result.
      # Subsequent calls to build() skip this entirely if @tool_cache exists.
      def load_tools(config)
        # Load required libraries (may be outside the bundle)
        Array(config.require_libs).each do |lib|
          begin
            require lib
          rescue LoadError
            # Gem not in bundle — find and load it from installed gems directly
            if activate_unbundled_gem(lib)
              require lib rescue warn("Warning: Failed to require '#{lib}' after activation")
            else
              warn "Warning: Failed to require '#{lib}': gem not found"
            end
          end
        end

        # Load tool files from paths
        Array(config.tools&.paths).each do |path|
          expanded = File.expand_path(path)
          if File.exist?(expanded)
            require expanded
          else
            warn "Warning: Tool file not found: #{path}"
          end
        rescue LoadError, StandardError => e
          warn "Warning: Failed to load tool '#{path}': #{e.message}"
        end

        # Eagerly load tools from gems that use zeitwerk lazy loading
        # (e.g., shared_tools provides .load_all_tools for this purpose)
        eager_load_gem_tools

        # Discover loaded tools via ObjectSpace and cache the result
        tools = discover_tools
        @tool_cache = tools
        config.loaded_tools = tools
        config.tool_names = tools.map { |t| t.respond_to?(:name) ? t.name : t.class.name }.join(', ')
      end

      # Activate a gem that isn't in the bundle by scanning installed gem
      # spec directories and prepending its lib paths to $LOAD_PATH.
      def activate_unbundled_gem(name)
        Gem.path.each do |gem_path|
          spec_dir = File.join(gem_path, 'specifications')
          next unless Dir.exist?(spec_dir)

          specs = Dir.glob(File.join(spec_dir, "#{name}-*.gemspec")).filter_map do |f|
            Gem::Specification.load(f)
          end.select { |s| s.name == name }

          next if specs.empty?

          spec = specs.max_by(&:version)
          $LOAD_PATH.unshift(*spec.full_require_paths)
          return true
        end

        false
      end

      # Eagerly load tool classes from gems that use zeitwerk lazy loading.
      # Without this, ObjectSpace won't see tool classes that haven't been
      # referenced yet. Checks for known conventions like .load_all_tools.
      def eager_load_gem_tools
        if defined?(SharedTools) && SharedTools.respond_to?(:load_all_tools)
          SharedTools.load_all_tools
        end
      rescue StandardError => e
        warn "Warning: Failed to eager-load gem tools: #{e.message}"
      end

      # Discover RubyLLM::Tool subclasses from ObjectSpace.
      # Skips tools that report themselves as unavailable via #available?.
      def discover_tools
        ObjectSpace.each_object(Class).select do |klass|
          next false unless defined?(RubyLLM::Tool) && klass < RubyLLM::Tool
          begin
            instance = klass.new
            if instance.respond_to?(:available?) && !instance.available?
              tool_name = instance.respond_to?(:name) ? instance.name : klass.name
              warn "Info: Tool '#{tool_name}' is not available, skipping"
              next false
            end
            true
          rescue ArgumentError, LoadError, StandardError
            false
          end
        end
      end

      # Load role file content
      def load_role_content(config, role_id)
        roles_prefix = config.prompts.roles_prefix
        unless role_id.start_with?(roles_prefix)
          role_id = "#{roles_prefix}/#{role_id}"
        end

        role_file = File.join(config.prompts.dir, "#{role_id}#{config.prompts.extname}")
        return nil unless File.exist?(role_file)

        File.read(role_file)
      rescue => e
        warn "Warning: Could not load role '#{role_id}': #{e.message}"
        nil
      end

      # Replay conversation history from an old robot to a new one.
      #
      # Performance: O(N) API calls where N = number of user messages.
      # Each user message triggers a full LLM round-trip on the new model.
      # For a 10-turn conversation with a local model (~1s/turn), expect ~10s.
      # For a cloud model (~2-5s/turn), expect 20-50s. MCP/tools are disabled
      # during replay to avoid side effects.
      def replay_history(old_robot, new_robot)
        return unless old_robot.respond_to?(:messages)

        old_robot.messages.each do |msg|
          next unless msg.respond_to?(:role) && msg.role == :user
          new_robot.run(msg.content, mcp: :none, tools: :none)
        end
      rescue StandardError => e
        warn "Warning: History replay failed: #{e.message}"
      end

      # Summarize conversation history and inject into new robot.
      #
      # Performance: Exactly 2 API calls regardless of conversation length.
      # 1) Summarize on old model (input tokens proportional to conversation)
      # 2) Inject summary into new model (small fixed-size prompt)
      # Faster than :replay for conversations with >2 turns, but loses
      # per-turn context fidelity. Total latency ~4-10s for cloud models.
      def summarize_history(old_robot, new_robot)
        return unless old_robot.respond_to?(:messages) && old_robot.messages.any?

        summary_lines = old_robot.messages.map do |msg|
          "#{msg.role}: #{msg.content}" if msg.respond_to?(:role)
        end.compact

        return if summary_lines.empty?

        summary_prompt = "Summarize this conversation concisely for context transfer:\n#{summary_lines.join("\n")}"
        summary = old_robot.run(summary_prompt, mcp: :none, tools: :none)
        content = summary.respond_to?(:reply) ? summary.reply : summary.to_s

        new_robot.run("Context from previous conversation: #{content}", mcp: :none, tools: :none)
      rescue StandardError => e
        warn "Warning: History summarization failed: #{e.message}"
      end

      # Stored on_content callback is not used. ChatLoop passes a per-call
      # streaming block to robot.run() that stops the spinner on first chunk
      # and prints content directly. This avoids spinner/stream conflicts.
      def build_streaming_callback(_config)
        nil
      end

      # Decide between consensus and parallel multi-model.
      # Initializes shared memory and subscriptions on the resulting network.
      def build_multi_model(config)
        network = if config.flags.consensus
                    build_consensus_network(config)
                  else
                    build_parallel_network(config)
                  end
        initialize_network_memory(network, config)
        setup_memory_subscriptions(network, config)
        network
      end

      # Build a network where each prompt in the pipeline is a sequential step
      def build_pipeline_network(config)
        prompts = config.pipeline
        run_config = build_run_config(config)
        tools = filtered_tools(config)
        mcp = mcp_server_configs(config)
        model_spec = config.models.first
        namer = @namer

        RobotLab.create_network(name: "aia-pipeline") do
          prev = nil
          prompts.each_with_index do |prompt_id, i|
            task_name = :"step_#{i}"
            build_opts = {
              name:          "#{namer.name_for(model_spec.name)}-s#{i}",
              system_prompt: nil,
              model:         model_spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.resolve_provider( model_spec) if model_spec.provider
            robot = RobotLab.build(**build_opts)
            task task_name, robot, depends_on: prev ? [prev] : :none
            prev = task_name
          end
        end
      end

      # Build a network where multiple models run in parallel
      def build_parallel_network(config)
        run_config = build_run_config(config)
        tools = filtered_tools(config)
        mcp = mcp_server_configs(config)
        aia_config = config

        # Pre-generate names so each robot can see the full roster
        roster = config.models.map { |spec| { name: @namer.name_for(spec.name), spec: spec } }

        RobotLab.create_network(name: "aia-parallel") do
          roster.each do |entry|
            spec = entry[:spec]
            identity = RobotFactory.build_identity_prompt( entry[:name], spec, roster)
            base_prompt = RobotFactory.resolve_system_prompt( aia_config, spec)
            system_prompt = [identity, base_prompt].compact.join("\n\n")

            build_opts = {
              name:          entry[:name],
              system_prompt: system_prompt,
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.resolve_provider( spec) if spec.provider
            robot = RobotLab.build(**build_opts)
            task spec.internal_id.to_sym, robot, depends_on: :none
          end
        end
      end

      # Build a consensus network: all models run in parallel, then a synthesizer merges
      def build_consensus_network(config)
        run_config = build_run_config(config)
        tools = filtered_tools(config)
        mcp = mcp_server_configs(config)
        primary = config.models.first
        aia_config = config

        # Pre-generate names so each robot can see the full roster
        roster = config.models.map { |spec| { name: @namer.name_for(spec.name), spec: spec } }

        RobotLab.create_network(name: "aia-consensus") do
          # All models run in parallel
          roster.each do |entry|
            spec = entry[:spec]
            identity = RobotFactory.build_identity_prompt( entry[:name], spec, roster)
            base_prompt = RobotFactory.resolve_system_prompt( aia_config, spec)
            system_prompt = [identity, base_prompt].compact.join("\n\n")

            build_opts = {
              name:          entry[:name],
              system_prompt: system_prompt,
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.resolve_provider( spec) if spec.provider
            robot = RobotLab.build(**build_opts)
            task spec.internal_id.to_sym, robot, depends_on: :none
          end

          # Synthesizer collects all responses
          synth_opts = {
            name:          "Weaver",
            system_prompt: "You are a synthesizer. Review the responses from multiple AI models and create a unified, coherent response that captures the best insights from each.",
            model:         primary.name,
            config:        run_config
          }
          synth_opts[:provider] = RobotFactory.resolve_provider( primary) if primary.provider
          synthesizer = RobotLab.build(**synth_opts)
          task :consensus, synthesizer,
               depends_on: config.models.map { |s| s.internal_id.to_sym }
        end
      end
    end
  end
end
