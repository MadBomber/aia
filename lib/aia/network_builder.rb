# frozen_string_literal: true

# lib/aia/network_builder.rb
#
# Stateless module for building RobotLab::Network instances.
# Extracted from RobotFactory to reduce its size and isolate
# the network-specific construction logic.

module AIA
  module NetworkBuilder
    module_function

    # Build a network where each prompt in the pipeline is a sequential step.
    #
    # @param config [AIA::Config]
    # @param namer [RobotNamer]
    # @return [RobotLab::Network]
    def build_pipeline_network(config, namer)
      prompts = config.pipeline
      run_config = RobotFactory.build_run_config(config)
      tools = ToolLoader.filtered_tools(config)
      mcp = RobotFactory.mcp_server_configs(config)
      model_spec = config.models.first

      RobotLab.create_network(name: "aia-pipeline") do
        prev = nil
        prompts.each_with_index do |_prompt_id, i|
          task_name = :"step_#{i}"
          build_opts = {
            name:          "#{namer.name_for(model_spec.name)}-s#{i}",
            system_prompt: nil,
            model:         model_spec.name,
            local_tools:   tools,
            mcp_servers:   mcp,
            config:        run_config
          }
          build_opts[:provider] = RobotFactory.resolve_provider(model_spec) if model_spec.provider
          robot = RobotLab.build(**build_opts)
          task task_name, robot, depends_on: prev ? [prev] : :none
          prev = task_name
        end
      end
    end

    # Build a network where multiple models run in parallel.
    #
    # @param config [AIA::Config]
    # @param namer [RobotNamer]
    # @return [RobotLab::Network]
    def build_parallel_network(config, namer)
      run_config = RobotFactory.build_run_config(config)
      tools = ToolLoader.filtered_tools(config)
      mcp = RobotFactory.mcp_server_configs(config)
      aia_config = config

      roster = config.models.map { |spec| { name: namer.name_for(spec.name), spec: spec } }

      RobotLab.create_network(name: "aia-parallel") do
        roster.each do |entry|
          spec = entry[:spec]
          identity = SystemPromptAssembler.build_identity_prompt(entry[:name], spec, roster)
          base_prompt = SystemPromptAssembler.resolve_system_prompt(aia_config, spec)
          system_prompt = [identity, base_prompt].compact.join("\n\n")

          build_opts = {
            name:          entry[:name],
            system_prompt: system_prompt,
            model:         spec.name,
            local_tools:   tools,
            mcp_servers:   mcp,
            config:        run_config
          }
          build_opts[:provider] = RobotFactory.resolve_provider(spec) if spec.provider
          robot = RobotLab.build(**build_opts)
          task spec.internal_id.to_sym, robot, depends_on: :none
        end
      end
    end

    # Build a consensus network: all models run in parallel, then a
    # synthesizer merges the results.
    #
    # @param config [AIA::Config]
    # @param namer [RobotNamer]
    # @return [RobotLab::Network]
    def build_consensus_network(config, namer)
      run_config = RobotFactory.build_run_config(config)
      tools = ToolLoader.filtered_tools(config)
      mcp = RobotFactory.mcp_server_configs(config)
      primary = config.models.first
      aia_config = config

      roster = config.models.map { |spec| { name: namer.name_for(spec.name), spec: spec } }

      RobotLab.create_network(name: "aia-consensus") do
        roster.each do |entry|
          spec = entry[:spec]
          identity = SystemPromptAssembler.build_identity_prompt(entry[:name], spec, roster)
          base_prompt = SystemPromptAssembler.resolve_system_prompt(aia_config, spec)
          system_prompt = [identity, base_prompt].compact.join("\n\n")

          build_opts = {
            name:          entry[:name],
            system_prompt: system_prompt,
            model:         spec.name,
            local_tools:   tools,
            mcp_servers:   mcp,
            config:        run_config
          }
          build_opts[:provider] = RobotFactory.resolve_provider(spec) if spec.provider
          robot = RobotLab.build(**build_opts)
          task spec.internal_id.to_sym, robot, depends_on: :none
        end

        synth_opts = {
          name:          "Weaver",
          system_prompt: "You are a synthesizer. Review the responses from multiple AI models and create a unified, coherent response that captures the best insights from each.",
          model:         primary.name,
          config:        run_config
        }
        synth_opts[:provider] = RobotFactory.resolve_provider(primary) if primary.provider
        synthesizer = RobotLab.build(**synth_opts)
        task :consensus, synthesizer,
             depends_on: config.models.map { |s| s.internal_id.to_sym }
      end
    end

    # Build a concurrent MCP network where independent server groups
    # run in parallel with a synthesizer to merge results.
    #
    # @param config [AIA::Config]
    # @param namer [RobotNamer]
    # @param server_groups [Array<Array<Hash>>]
    # @return [RobotLab::Network]
    def build_concurrent_mcp_network(config, namer, server_groups)
      run_config = RobotFactory.build_run_config(config)
      tools = ToolLoader.filtered_tools(config)
      model_spec = config.models.first
      system_prompt = SystemPromptAssembler.resolve_system_prompt(config, model_spec)

      network = RobotLab.create_network(name: "aia-concurrent-mcp") do
        server_groups.each_with_index do |group, i|
          build_opts = {
            name:          "#{namer.name_for(model_spec.name)}-w#{i}",
            model:         model_spec.name,
            system_prompt: system_prompt,
            local_tools:   tools,
            mcp_servers:   group.map { |s| RobotFactory.normalize_mcp_config(s) },
            config:        run_config
          }
          build_opts[:provider] = RobotFactory.resolve_provider(model_spec) if model_spec.provider
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
        synth_opts[:provider] = RobotFactory.resolve_provider(model_spec) if model_spec.provider
        synthesizer = RobotLab.build(**synth_opts)
        task :synthesize, synthesizer,
             depends_on: server_groups.each_index.map { |i| :"mcp_worker_#{i}" }
      end

      RobotFactory.initialize_network_memory(network, config)
      RobotFactory.setup_memory_subscriptions(network, config)
      network
    end
  end
end
