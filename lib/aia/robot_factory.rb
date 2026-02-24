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
      end

      # Rebuild robot(s) after config changes (e.g., /model, /config directives)
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot, RobotLab::Network]
      def rebuild(config = AIA.config)
        build(config)
      end

      # Build a single robot for one model
      #
      # @param config [AIA::Config] the AIA configuration
      # @return [RobotLab::Robot]
      def build_single_robot(config)
        model_spec = config.models.first

        RobotLab.build(
          name:          "aia-#{model_spec.internal_id}",
          system_prompt: resolve_system_prompt(config, model_spec),
          model:         model_spec.name,
          local_tools:   filtered_tools(config),
          mcp_servers:   mcp_server_configs(config),
          on_content:    build_streaming_callback(config),
          config:        build_run_config(config)
        )
      end

      private

      # Configure RobotLab providers from AIA config
      def configure_robot_lab(config)
        # Configure loggers before any API calls
        AIA::LoggerManager.configure_llm_logger
        AIA::LoggerManager.configure_mcp_logger

        RobotLab.config do |c|
          c.ruby_llm do |r|
            r.request_timeout = 120
          end
        end
      end

      # Load tools from require_libs and tool paths
      def load_tools(config)
        # Load required libraries
        Array(config.require_libs).each do |lib|
          begin
            require lib
          rescue LoadError => e
            warn "Warning: Failed to require '#{lib}': #{e.message}"
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
            robot = RobotLab.build(
              name:          "aia-pipeline-#{i}",
              system_prompt: nil,
              model:         model_spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            )
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

        RobotLab.create_network(name: "aia-parallel") do
          config.models.each do |spec|
            robot = RobotLab.build(
              name:          "aia-#{spec.internal_id}",
              system_prompt: RobotFactory.send(:resolve_system_prompt, config, spec),
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            )
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

        RobotLab.create_network(name: "aia-consensus") do
          # All models run in parallel
          config.models.each do |spec|
            robot = RobotLab.build(
              name:          "aia-#{spec.internal_id}",
              system_prompt: RobotFactory.send(:resolve_system_prompt, config, spec),
              model:         spec.name,
              local_tools:   tools,
              mcp_servers:   mcp,
              config:        run_config
            )
            task spec.internal_id.to_sym, robot, depends_on: :none
          end

          # Synthesizer collects all responses
          synthesizer = RobotLab.build(
            name:          "aia-synthesizer",
            system_prompt: "You are a synthesizer. Review the responses from multiple AI models and create a unified, coherent response that captures the best insights from each.",
            model:         primary.name,
            config:        run_config
          )
          task :consensus, synthesizer,
               depends_on: config.models.map { |s| s.internal_id.to_sym }
        end
      end
    end
  end
end
