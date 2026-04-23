# lib/aia/prompt_pipeline.rb
# frozen_string_literal: true

require "pm"

module AIA
  class PromptPipeline
    include AIA::SkillUtils

    def initialize(prompt_handler, chat_processor, ui_presenter, input_collector)
      @prompt_handler  = prompt_handler
      @chat_processor  = chat_processor
      @ui_presenter    = ui_presenter
      @input_collector = input_collector
      @include_context_flag = true
    end

    # Process all prompts in the pipeline sequentially
    def process_all
      prompt_count = 0
      total_prompts = AIA.config.pipeline.size

      until AIA.config.pipeline.empty?
        prompt_count += 1
        prompt_id = AIA.config.pipeline.shift

        puts "\n--- Processing prompt #{prompt_count}/#{total_prompts}: #{prompt_id} ---" if AIA.verbose? && total_prompts > 1

        process_single(prompt_id)
      end
    end

    # Process a single prompt with all its requirements
    def process_single(prompt_id)
      return if prompt_id.nil? || prompt_id.empty?

      prompt_text = build_prompt_text(prompt_id)
      return unless prompt_text

      send_and_get_response(prompt_text)
    end

    def build_prompt_text(prompt_id)
      role_id = AIA.config.prompts.role

      begin
        prompt_parsed = @prompt_handler.fetch_prompt(prompt_id)
      rescue StandardError => e
        warn "Error processing prompt '#{prompt_id}': #{e.message}"
        AIA::LoggerManager.aia_logger.error("Error processing prompt '#{prompt_id}': #{e.message}")
        return nil
      end

      return nil unless prompt_parsed

      role_parsed = nil
      unless role_id.nil? || role_id.empty?
        begin
          role_parsed = @prompt_handler.fetch_role(role_id)
        rescue StandardError => e
          warn "Warning: Could not load role '#{role_id}': #{e.message}"
          AIA::LoggerManager.aia_logger.warn("Could not load role '#{role_id}': #{e.message}")
        end
      end

      # Merge parameters from role and prompt
      all_params = {}
      all_params.merge!(role_parsed.metadata.parameters) if role_parsed&.metadata&.parameters
      all_params.merge!(prompt_parsed.metadata.parameters) if prompt_parsed.metadata&.parameters

      # Collect parameter values from user
      values = @input_collector.collect(all_params)

      # Render role, skills, and prompt.
      # Order: role (personality) → skills (task instructions) → prompt (user request)
      parts = []
      parts << role_parsed.to_s(values) if role_parsed
      load_skills(AIA.config.prompts.skills).each { |body| parts << body }
      parts << prompt_parsed.to_s(values)

      if @include_context_flag
        # Process stdin content
        if AIA.config.stdin_content && !AIA.config.stdin_content.strip.empty?
          parts << PM.parse(AIA.config.stdin_content).to_s
        end
      end

      prompt_text = parts.join("\n\n")

      if @include_context_flag
        prompt_text = add_context_files(prompt_text)
        @include_context_flag = false
      end

      prompt_text
    end

    # Load skill bodies for the given skill IDs in order.
    # Each skill lives at skills_dir/<name>/SKILL.md; supports prefix matching.
    # Path-based IDs (starting with /, ~/, ./, ../) are resolved as direct paths.
    # Returns only the body content (front matter stripped).
    def load_skills(skill_ids)
      return [] if skill_ids.nil? || skill_ids.empty?

      skills_dir = AIA.config.skills.dir

      Array(skill_ids).filter_map do |skill_name|
        skill_name = skill_name.to_s.strip
        next if skill_name.empty?

        unless path_based_id?(skill_name) || Dir.exist?(skills_dir)
          warn "Warning: No skill matching '#{skill_name}' found in #{skills_dir}"
          next
        end

        skill_dir = find_skill_dir(skill_name, skills_dir)
        unless skill_dir
          if path_based_id?(skill_name)
            warn "Warning: No skill directory found at '#{File.expand_path(skill_name)}'"
          else
            warn "Warning: No skill matching '#{skill_name}' found in #{skills_dir}"
          end
          next
        end

        next skill_body(File.read(skill_dir)) if File.file?(skill_dir)

        skill_path = File.join(skill_dir, 'SKILL.md')
        unless File.exist?(skill_path)
          warn "Warning: Skill '#{skill_name}' has no SKILL.md in #{skill_dir}"
          next
        end

        skill_body(File.read(skill_path))
      end
    end

    # Add context files to prompt text
    def add_context_files(prompt_text)
      return prompt_text unless AIA.config.context_files && !AIA.config.context_files.empty?

      context = AIA.config.context_files.map do |file|
        File.read(file) rescue "Error reading file: #{file}"
      end.join("\n\n")

      "#{prompt_text}\n\nContext:\n#{context}"
    end

    private

    # Send prompt to AI and handle the response
    def send_and_get_response(prompt_text)
      response_data = @chat_processor.process_prompt(prompt_text)

      if response_data.is_a?(Hash)
        content = response_data[:content]
        metrics = response_data[:metrics]
        multi_metrics = response_data[:multi_metrics]
      else
        content = response_data
        metrics = nil
        multi_metrics = nil
      end

      @chat_processor.output_response(content)

      if AIA.config.flags.tokens
        if multi_metrics
          @ui_presenter.display_multi_model_metrics(multi_metrics)
        elsif metrics
          @ui_presenter.display_token_metrics(metrics)
        end
      end

      # Process any directives in the response
      directive_processor = DirectiveProcessor.new
      if directive_processor.directive?(content)
        directive_result = directive_processor.process(content, nil)
        puts "\nDirective output: #{directive_result}" if directive_result && !directive_result.strip.empty?
      end
    end
  end
end
