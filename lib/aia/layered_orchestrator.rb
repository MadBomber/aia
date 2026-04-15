# frozen_string_literal: true

# lib/aia/layered_orchestrator.rb
#
# Three-tier agent orchestration for complex application builds.
#
# Tier 1 — Orchestrator (Tobor)
#   Receives full application requirements. Decomposes them into
#   independent architectural layers (e.g. infrastructure, data models,
#   auth, routes, views). Each layer is a distinct technical concern.
#
# Tier 2 — Lead Agents (one per layer, run in parallel via Async::Barrier)
#   Each lead agent receives its layer's requirements and breaks them
#   into specific implementation tasks, assigning a specialist type to
#   each task.
#
# Tier 3 — Specialist Robots (one per task, all run in parallel via Async::Barrier)
#   Each specialist receives a focused, concrete task and produces the
#   actual implementation artifact: a code file, migration, spec, or
#   configuration block.
#
# After all layers complete, Tobor synthesizes a final integration
# summary showing how the pieces fit together.

require 'json'
require 'fileutils'
require 'async'

module AIA
  class LayeredOrchestrator
    include ContentExtractor
    include HandlerProtocol

    MAX_LAYERS = 5
    MAX_TASKS_PER_LAYER = 4

    # Tier 1 prompt: decompose requirements into layers
    # Deliberately short and directive to minimise qwen3 think-block noise.
    LAYER_DECOMPOSE_PROMPT = <<~PROMPT
      TASK: Decompose the application requirements below into architectural layers.
      RESPOND WITH ONLY A JSON ARRAY. No explanation. No markdown. No code fences.

      JSON schema (array of objects):
      name        - snake_case layer identifier
      title       - short human-readable title
      description - one sentence describing what this layer covers
      requirements - comma-separated list of things to implement in this layer

      Rules: 3 to %{max_layers} layers. Infrastructure first, UI last.

      APPLICATION REQUIREMENTS:
      %{requirements}

      JSON ARRAY RESPONSE:
    PROMPT

    # Tier 2 prompt: lead agent decomposes its layer into tasks
    TASK_DECOMPOSE_PROMPT = <<~PROMPT
      TASK: Break the %{layer_title} layer into implementation tasks.
      RESPOND WITH ONLY A JSON ARRAY. No explanation. No markdown. No code fences.

      JSON schema (array of objects):
      title      - short task title
      specialist - specialist role name (e.g. sequel-migration-writer)
      artifact   - exact filename to produce (e.g. db/migrations/001_create_users.rb)
      prompt     - self-contained instruction for the specialist

      Rules: 2 to %{max_tasks} tasks. Each task produces exactly one file.

      LAYER: %{layer_title}
      REQUIREMENTS: %{requirements}

      JSON ARRAY RESPONSE:
    PROMPT

    # Layer synthesis prompt
    LAYER_SYNTHESIS_PROMPT = <<~PROMPT
      You implemented the %{layer_title} layer. Here are the artifacts produced
      by your specialist team:

      %{task_results}

      Write a brief (3-5 sentence) integration summary: what was built, how the
      artifacts fit together, and what the next layer depends on from this one.
    PROMPT

    # Final synthesis prompt for Tobor
    FINAL_SYNTHESIS_PROMPT = <<~PROMPT
      All architectural layers of the application have been built by the agent teams.
      Here is what each layer produced:

      %{layer_summaries}

      Original requirements excerpt:
      %{requirements_excerpt}

      Provide a final integration summary:
      1. What was built overall
      2. How the layers connect (what each layer depends on from the layers below it)
      3. The minimal steps to make the application runnable (config, migrations, startup)
    PROMPT

    def initialize(robot:, ui_presenter:, tracker:, build_dir: nil)
      @robot        = robot
      @ui_presenter = ui_presenter
      @tracker      = tracker
      @build_dir    = build_dir || default_build_dir
    end

    def default_build_dir
      File.join(Dir.pwd, "orchestrated_build_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
    end

    # Print orchestration progress to stdout so it appears inline with the chat.
    # (display_info uses $stderr which is invisible in interactive sessions.)
    def say(msg)
      $stdout.puts msg
      $stdout.flush
    end

    attr_writer :robot

    # Entry point called by SpecialModeHandler.
    #
    # @param context [HandlerContext] — reads context.prompt as requirements text
    # @return [String, nil] final synthesis or nil on failure
    def handle(context)
      requirements = context.prompt
      primary      = primary_robot

      FileUtils.mkdir_p(@build_dir)
      say("")
      say("╔══════════════════════════════════════════════════════════╗")
      say("║           LAYERED ORCHESTRATION — 3-TIER BUILD           ║")
      say("╚══════════════════════════════════════════════════════════╝")
      say("Requirements: #{requirements.lines.first.strip}")
      say("Build output: #{@build_dir}")
      say("")

      # Tier 1: Tobor decomposes requirements into layers
      layers = decompose_to_layers(primary, requirements)
      if layers.empty?
        say("Could not decompose requirements into layers. Aborting orchestration.")
        return nil
      end

      display_layer_plan(layers)

      # Tier 2: All lead agents run in parallel (Async::Barrier)
      say("Running #{layers.size} lead agents in parallel...")
      layer_task_map = run_leads_wave(layers)

      if layer_task_map.values.all?(&:empty?)
        say("All lead agents failed. Aborting orchestration.")
        raise OrchestratorError, "All lead agents failed to produce tasks"
      end

      # Tier 3: All specialists run in parallel (Async::Barrier)
      say("")
      say("Running specialists in parallel...")
      specialist_results = run_specialists_wave(layer_task_map)

      # Assemble layer_results for synthesis (same shape as the former sequential approach)
      layer_results = build_layer_results(layers, layer_task_map, specialist_results)

      # Final synthesis by Tobor
      say("")
      say("━━━ Tobor synthesizing all #{layers.size} layers ━━━")
      final_result = synthesize_all(primary, requirements, layers, layer_results)
      final_text   = extract_content(final_result)

      save_final_report(final_text)
      say("Build complete: #{@build_dir}")

      @tracker.record_turn(
        model:  AIA.config.models.first.name,
        input:  requirements,
        result: final_text
      )

      final_text
    rescue StandardError => e
      say("✗ Orchestration error: #{e.class}: #{e.message}")
      e.backtrace&.first(5)&.each { |line| say("    #{line}") }
      nil
    end

    private

    # Return the single primary robot (first robot in a network, or @robot itself)
    def primary_robot
      @robot.is_a?(RobotLab::Network) ? @robot.robots.values.first : @robot
    end

    # Tier 1: use a probe robot to decompose requirements into layer specs
    def decompose_to_layers(robot, requirements)
      say("Tier 1 ▶ #{robot.name} decomposing requirements into layers...")
      probe  = build_probe(robot.name + "-layer-probe")
      prompt = LAYER_DECOMPOSE_PROMPT % {
        requirements: requirements,
        max_layers:   MAX_LAYERS
      }

      result  = probe.run(prompt, mcp: :none, tools: :none)
      content = extract_content(result)
      layers  = parse_json_array(content)

      if layers.empty?
        preview = content.to_s.gsub(/<think>.*?<\/think>/m, '').strip[0, 300]
        say("  ⚠  Layer decomposition parse failed.")
        say("  Raw response preview: #{preview}")
      end

      layers.first(MAX_LAYERS)
    rescue StandardError => e
      say("  ✗ decompose_to_layers failed: #{e.class}: #{e.message}")
      e.backtrace&.first(3)&.each { |line| say("    #{line}") }
      []
    end

    def display_layer_plan(layers)
      say("Tier 1 ▶ #{layers.size} layers identified:")
      layers.each_with_index do |layer, i|
        say("  #{i + 1}. #{layer['title']}: #{layer['description']}")
      end
    end

    # Tier 2 Wave: run all lead agents in parallel via Async::Barrier.
    # Each lead decomposes its layer into task specifications.
    #
    # @param layers [Array<Hash>] layer specs from Tier 1
    # @return [Hash{ String => Array<Hash> }] layer_name => task list ([] on failure)
    def run_leads_wave(layers)
      results = {}

      Sync do
        barrier = Async::Barrier.new
        layers.each do |layer|
          barrier.async do
            probe  = build_probe("#{layer['name']}-lead")
            prompt = TASK_DECOMPOSE_PROMPT % {
              layer_title:  layer['title'],
              requirements: layer['requirements'].to_s,
              max_tasks:    MAX_TASKS_PER_LAYER
            }
            result = probe.run(prompt, mcp: :none, tools: :none)
            tasks  = parse_json_array(extract_content(result)).first(MAX_TASKS_PER_LAYER)
            say("  ✓ #{layer['title']} lead: #{tasks.size} task(s)")
            results[layer['name']] = tasks
          rescue => e
            say("  ✗ #{layer['title']} lead failed: #{e.message}")
            results[layer['name']] = []
          end
        end
        barrier.wait
      end

      results
    end

    # Tier 3 Wave: run all specialists in parallel via Async::Barrier.
    # Flattens tasks from all layers into a single barrier so specialists
    # across all layers execute concurrently.
    #
    # @param layer_task_map [Hash{ String => Array<Hash> }] output of run_leads_wave
    # @return [Hash{ String => Hash }] "layer_name|artifact_path" => result hash
    def run_specialists_wave(layer_task_map)
      jobs = layer_task_map.flat_map do |layer_name, tasks|
        tasks.map { |task| { layer_name: layer_name, task: task } }
      end

      results = {}

      Sync do
        barrier = Async::Barrier.new
        jobs.each do |job|
          barrier.async do
            task  = job[:task]
            key   = "#{job[:layer_name]}|#{task['artifact']}"
            probe = build_probe("#{task['specialist']}-specialist")

            full_prompt = "Artifact to produce: #{task['artifact']}\n\n#{task['prompt']}"
            result      = probe.run(full_prompt, mcp: :none, tools: :none)
            output      = extract_content(result)

            save_artifact(task['artifact'], output)
            say("    ✓ #{task['artifact']}")

            results[key] = {
              task:       task['title'],
              specialist: task['specialist'],
              artifact:   task['artifact'],
              output:     output
            }
          rescue => e
            task = job[:task]
            key  = "#{job[:layer_name]}|#{task['artifact']}"
            say("    ✗ #{task['artifact']} failed: #{e.message}")
            results[key] = {
              task:       task['title'],
              specialist: task['specialist'],
              artifact:   task['artifact'],
              output:     "[FAILED: #{e.message}]"
            }
          end
        end
        barrier.wait
      end

      results
    end

    # Assemble the layer_results array expected by synthesize_all.
    # Shape: [{ layer:, tasks: [result_hashes], summary: }]
    #
    # @param layers [Array<Hash>] original layer specs
    # @param layer_task_map [Hash] output of run_leads_wave
    # @param specialist_results [Hash] output of run_specialists_wave
    # @return [Array<Hash>]
    def build_layer_results(layers, layer_task_map, specialist_results)
      layers.map do |layer|
        tasks_for_layer = layer_task_map[layer['name']] || []
        task_results = tasks_for_layer.map do |task|
          key = "#{layer['name']}|#{task['artifact']}"
          specialist_results[key] || {
            task:       task['title'],
            specialist: task['specialist'],
            artifact:   task['artifact'],
            output:     "[FAILED: no result]"
          }
        end

        summary = synthesize_layer_from_results(layer['title'], task_results)
        say("  ✓ #{layer['title']} synthesis complete")
        { layer: layer['title'], tasks: task_results, summary: summary }
      end
    end

    # Synthesize all task outputs for a layer into an integration summary.
    # Uses a fresh probe robot (no conversation history).
    def synthesize_layer_from_results(layer_title, task_results)
      results_text = task_results.map do |r|
        "### #{r[:task]} — #{r[:artifact]}\n#{r[:output]}"
      end.join("\n\n---\n\n")

      prompt = LAYER_SYNTHESIS_PROMPT % {
        layer_title:  layer_title,
        task_results: results_text
      }

      probe  = build_probe("#{layer_title.downcase.gsub(/\s+/, '-')}-synthesis")
      result = probe.run(prompt, mcp: :none, tools: :none)
      extract_content(result)
    rescue StandardError
      "(layer synthesis failed)"
    end

    # Tobor synthesizes all layer summaries into a final integration report
    def synthesize_all(primary, requirements, layers, layer_results)
      summaries = layer_results.each_with_index.map do |lr, i|
        header = "## Layer #{i + 1}: #{lr[:layer]}"
        tasks  = Array(lr[:tasks]).map { |t| "- #{t[:artifact]}: #{t[:task]}" }.join("\n")
        "#{header}\n#{tasks}\n\nSummary: #{lr[:summary]}"
      end.join("\n\n")

      primary.run(
        FINAL_SYNTHESIS_PROMPT % {
          layer_summaries:      summaries,
          requirements_excerpt: requirements.lines.first(15).join
        },
        mcp: :none, tools: :none
      )
    end

    # Parse JSON array from model output.
    # Tries multiple extraction strategies to handle think blocks,
    # markdown fences, prose before/after the JSON, and partial wrapping.
    def parse_json_array(content)
      return [] if content.nil? || content.strip.empty?

      # Strip think blocks (qwen3 reasoning models wrap output in <think>...)
      text = content.gsub(/<think>.*?<\/think>/m, '').strip

      # Strategy 1: extract content from markdown code fences
      if (m = text.match(/```(?:json)?\s*\n?(.*?)```/m))
        candidate = m[1].strip
        result = try_json_parse(candidate)
        return result unless result.empty?
      end

      # Strategy 2: find the first [...] block in the response
      if (m = text.match(/(\[[\s\S]*\])/m))
        result = try_json_parse(m[1])
        return result unless result.empty?
      end

      # Strategy 3: parse the whole stripped text
      try_json_parse(text)
    end

    def try_json_parse(text)
      result = JSON.parse(text.strip)
      result.is_a?(Array) ? result.select { |e| e.is_a?(Hash) } : []
    rescue JSON::ParserError
      []
    end

    # Build a short-lived probe robot with no conversation history.
    # Uses the primary model spec so the provider is correctly wired.
    def build_probe(name)
      config     = AIA.config
      run_config = RobotFactory.build_run_config(config)
      model_spec = config.models.first

      opts = {
        name:          name,
        model:         model_spec.name,
        system_prompt: nil,
        config:        run_config
      }
      opts[:provider] = RobotFactory.send(:resolve_provider, model_spec) if model_spec.provider

      RobotLab.build(**opts)
    end

    # Write an artifact to the build directory.
    # Strips markdown code fences if the entire output is wrapped in them.
    def save_artifact(artifact_path, content)
      return unless content && !content.strip.empty?

      # Strip a single wrapping code fence if the whole content is fenced
      code = content.strip
      if (m = code.match(/\A```[\w]*\n(.*)\n```\z/m))
        code = m[1]
      end

      dest = File.join(@build_dir, artifact_path)
      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, code)
    rescue StandardError => e
      say("    ⚠  Could not save #{artifact_path}: #{e.message}")
    end

    # Write the integration report to BUILD_DIR/INTEGRATION_REPORT.md
    def save_final_report(text)
      dest = File.join(@build_dir, "INTEGRATION_REPORT.md")
      File.write(dest, text)
      say("Integration report: #{dest}")
    rescue StandardError
      # best-effort
    end
  end
end
