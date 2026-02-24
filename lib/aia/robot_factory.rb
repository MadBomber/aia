# frozen_string_literal: true

# lib/aia/robot_factory.rb
#
# The core new abstraction in AIA v2.
# Builds RobotLab::Robot or RobotLab::Network instances from AIA configuration.
# Replaces the entire lib/aia/adapter/ directory from v1.

module AIA
  class RobotFactory
    class << self
      # Build a Robot or Network from the current AIA config
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot, RobotLab::Network] the built robot or network
      def build(config = AIA.config)
        configure_robot_lab(config)
        load_tools(config)

        if config.pipeline.length > 1
          build_pipeline_network(config)
        elsif config.models.length > 1
          build_multi_model(config)
        else
          build_single_robot(config)
        end
      rescue RubyLLM::ModelNotFoundError => e
        model_names = config.models.map(&:name).join(', ')
        $stderr.puts "ERROR: #{e.message}"
        $stderr.puts "Requested model(s): #{model_names}"
        $stderr.puts "Run 'aia --available-models' to see available models."
        $stdout.puts "ERROR: #{e.message}"
        exit 1
      end

      # Rebuild robot(s) after config changes (e.g., /model, /config directives).
      # Supports conversation history transfer modes.
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

        RobotLab.create_network(name: "aia-concurrent-mcp") do
          server_groups.each_with_index do |group, i|
            build_opts = {
              name:          "mcp-worker-#{i}",
              model:         model_spec.name,
              system_prompt: system_prompt,
              local_tools:   tools,
              mcp_servers:   group.map { |s| RobotFactory.send(:normalize_mcp_config, s) },
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider
            robot = RobotLab.build(**build_opts)
            task :"mcp_worker_#{i}", robot, depends_on: :none
          end

          synth_opts = {
            name:          "mcp-synthesizer",
            model:         model_spec.name,
            system_prompt: "You are a synthesizer. Merge the following results from " \
                           "multiple specialized queries into a coherent response. " \
                           "Preserve all relevant information. Resolve contradictions.",
            config:        run_config
          }
          synth_opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider
          synthesizer = RobotLab.build(**synth_opts)
          task :synthesize, synthesizer,
               depends_on: server_groups.each_index.map { |i| :"mcp_worker_#{i}" }
        end
      end

      # Build a single robot for one model
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot]
      def build_single_robot(config)
        model_spec = config.models.first
        build_opts = {
          name:          "aia-#{model_spec.internal_id}",
          system_prompt: resolve_system_prompt(config, model_spec),
          model:         model_spec.name,
          local_tools:   filtered_tools(config),
          mcp_servers:   mcp_server_configs(config),
          on_content:    build_streaming_callback(config),
          config:        build_run_config(config)
        }
        build_opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider

        RobotLab.build(**build_opts)
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

      # Map AIA provider aliases to RubyLLM provider slugs for chat creation.
      # 'lms' maps to 'openai' since LM Studio is OpenAI-compatible.
      def resolve_provider(model_spec)
        case model_spec.provider
        when 'lms' then 'openai'
        else model_spec.provider
        end
      end

      # Load tools from require_libs and tool paths
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

        # Discover loaded tools via ObjectSpace
        tools = discover_tools
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

      # Discover RubyLLM::Tool subclasses from ObjectSpace
      def discover_tools
        ObjectSpace.each_object(Class).select do |klass|
          next false unless defined?(RubyLLM::Tool) && klass < RubyLLM::Tool
          begin
            klass.new
            true
          rescue ArgumentError, LoadError, StandardError
            false
          end
        end
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

        # Deduplicate by name
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

      # Build MCP server configs for robot_lab from AIA config.
      # Converts AIA's flat format (name, command, args, env, timeout)
      # to robot_lab's nested transport format:
      #   { name: "server", transport: { type: "stdio", command: "cmd", args: [...] } }
      def mcp_server_configs(config)
        return [] if config.flags.no_mcp
        servers = config.mcp_servers || []
        return [] if servers.empty?

        # Apply mcp_use/mcp_skip filters
        use_list  = Array(config.mcp_use)
        skip_list = Array(config.mcp_skip)

        if !use_list.empty?
          servers = servers.select { |s| server_config_name(s) }
                          .select { |s| use_list.include?(server_config_name(s)) }
        elsif !skip_list.empty?
          servers = servers.reject { |s| skip_list.include?(server_config_name(s)) }
        end

        # Convert to robot_lab's expected format
        servers.map { |s| normalize_mcp_config(s) }
      end

      # Extract server name from a config entry (handles string/symbol keys and objects)
      def server_config_name(s)
        if s.is_a?(Hash)
          s[:name] || s['name']
        elsif s.respond_to?(:name)
          s.name
        end
      end

      # Convert AIA's flat MCP config to robot_lab's nested transport format
      def normalize_mcp_config(server)
        server = server.is_a?(Hash) ? server.transform_keys(&:to_sym) : server.to_h.transform_keys(&:to_sym)

        # Already in robot_lab format (has transport key)
        return server if server[:transport]

        # Convert flat format to nested transport
        name = server[:name]
        transport = { type: 'stdio' }
        transport[:command] = server[:command] if server[:command]
        transport[:args]    = Array(server[:args]) if server[:args]
        transport[:env]     = server[:env] if server[:env]

        result = { name: name, transport: transport }
        result[:timeout] = server[:timeout] if server[:timeout]
        result
      end

      # Resolve system prompt from config (including role)
      def resolve_system_prompt(config, model_spec = nil)
        system_prompt = config.prompts.system_prompt

        # Load role content if specified
        role_id = model_spec&.role || config.prompts.role
        if role_id && !role_id.empty?
          role_content = load_role_content(config, role_id)
          if role_content
            system_prompt = [system_prompt, role_content].compact.join("\n\n")
          end
        end

        system_prompt
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

      # Build RunConfig from AIA configuration.
      # Only includes non-default penalty values since some providers
      # (e.g., Anthropic) reject unsupported parameters.
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

      # Replay conversation history from an old robot to a new one.
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

      # Decide between consensus and parallel multi-model
      def build_multi_model(config)
        if config.flags.consensus
          build_consensus_network(config)
        else
          build_parallel_network(config)
        end
      end

      # Build a network where each prompt in the pipeline is a sequential step
      def build_pipeline_network(config)
        prompts = config.pipeline
        run_config = build_run_config(config)
        tools = filtered_tools(config)
        mcp = mcp_server_configs(config)
        model_spec = config.models.first

        RobotLab.create_network(name: "aia-pipeline") do
          prev = nil
          prompts.each_with_index do |prompt_id, i|
            task_name = :"step_#{i}"
            build_opts = {
              name:          "aia-pipeline-#{i}",
              system_prompt: nil,
              model:         model_spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider
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
        model_specs = config.models
        aia_config = config

        RobotLab.create_network(name: "aia-parallel") do
          model_specs.each do |spec|
            build_opts = {
              name:          "aia-#{spec.internal_id}",
              system_prompt: RobotFactory.send(:resolve_system_prompt, aia_config, spec),
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.send(:resolve_provider, spec) if spec.provider
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
        model_specs = config.models
        primary = model_specs.first
        aia_config = config

        RobotLab.create_network(name: "aia-consensus") do
          # All models run in parallel
          model_specs.each do |spec|
            build_opts = {
              name:          "aia-#{spec.internal_id}",
              system_prompt: RobotFactory.send(:resolve_system_prompt, aia_config, spec),
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            }
            build_opts[:provider] = RobotFactory.send(:resolve_provider, spec) if spec.provider
            robot = RobotLab.build(**build_opts)
            task spec.internal_id.to_sym, robot, depends_on: :none
          end

          # Synthesizer collects all responses
          synth_opts = {
            name:          "aia-synthesizer",
            system_prompt: "You are a synthesizer. Review the responses from multiple AI models and create a unified, coherent response that captures the best insights from each.",
            model:         primary.name,
            config:        run_config
          }
          synth_opts[:provider] = RobotFactory.send(:resolve_provider, primary) if primary.provider
          synthesizer = RobotLab.build(**synth_opts)
          task :consensus, synthesizer,
               depends_on: model_specs.map { |s| s.internal_id.to_sym }
        end
      end
    end
  end
end
