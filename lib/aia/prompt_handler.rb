# frozen_string_literal: true

require 'prompt_manager'

module AIA
  class PromptHandler
    def initialize(config)
      @config = config
      @prompts_dir = config.prompts_dir
      @roles_dir = config.roles_dir || File.join(@prompts_dir, 'roles')
      
      # Initialize PromptManager
      PromptManager.config do |c|
        c.prompts_dir = @prompts_dir
      end
    end

    def get_prompt(prompt_id, role_id = nil)
      prompt = PromptManager::Prompt.get(id: prompt_id)
      
      if role_id
        role_storage = PromptManager::Storage.new(dir: @roles_dir)
        role_prompt = PromptManager::Prompt.get(id: role_id, storage: role_storage)
        # Prepend role to prompt
        prompt.text = "#{role_prompt.text}\n#{prompt.text}"
      end
      
      process_prompt(prompt)
    end

    def process_prompt(prompt)
      text = prompt.text.dup
      
      # Process directives
      text = process_directives(text)
      
      # Process shell commands if enabled
      if @config.shell
        text = text.gsub(/\$\((.*?)\)/) { `#{Regexp.last_match(1)}`.chomp }
      end
      
      # Process ERB if enabled
      if @config.erb
        text = ERB.new(text).result(binding)
      end
      
      # Add terse instruction if requested
      if @config.terse
        text += "\n\nPlease be terse in your response."
      end
      
      text
    end
    
    def process_text(text)
      # Process directives
      text = process_directives(text.dup)
      
      # Process shell commands if enabled
      if @config.shell
        text = text.gsub(/\$\((.*?)\)/) { `#{Regexp.last_match(1)}`.chomp }
      end
      
      # Process ERB if enabled
      if @config.erb
        text = ERB.new(text).result(binding)
      end
      
      text
    end
    
    def process_directives(text)
      return text unless text

      lines = text.split("\n")
      result_lines = []
      
      lines.each do |line|
        if line.start_with?("//")
          directive, *args = line[2..-1].strip.split(/\s+/, 2)
          args = args.first || ""
          
          case directive
          when "config"
            # Process config directive
            key, value = args.split(/\s*=\s*/, 2)
            @config[key.strip.to_sym] = parse_value(value.strip)
          when "include"
            # Include another file
            file_path = args.strip
            if File.exist?(file_path)
              result_lines << File.read(file_path)
            else
              result_lines << "# Error: File not found: #{file_path}"
            end
          when "shell"
            # Execute shell command
            result_lines << `#{args}`.chomp
          when "ruby"
            # Execute Ruby code
            result = eval(args)
            result_lines << result.to_s
          when "next"
            # Set next prompt
            @config.next = args.strip
          when "pipeline"
            # Set pipeline
            @config.pipeline = args.strip.split(',')
          else
            # Unknown directive, keep it as is
            result_lines << line
          end
        else
          result_lines << line
        end
      end
      
      result_lines.join("\n")
    end
    
    def parse_value(value)
      case value.downcase
      when 'true'
        true
      when 'false'
        false
      when /^\d+$/
        value.to_i
      when /^\d+\.\d+$/
        value.to_f
      when /^\[.*\]$/
        value[1..-2].split(',').map(&:strip)
      else
        value
      end
    end
  end
end
