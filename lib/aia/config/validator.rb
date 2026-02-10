# frozen_string_literal: true

require 'word_wrapper'
require_relative '../adapter/gem_activator'

# lib/aia/config/validator.rb
#
# Validates and tailors configuration after it's been loaded.
# Handles prompt ID extraction, context file validation, role processing, etc.

module AIA
  module ConfigValidator
    class << self
      # Tailor and validate the configuration
      #
      # @param config [AIA::Config] the configuration to validate
      # @return [AIA::Config] the validated configuration
      def tailor(config)
        remaining_args = config.remaining_args&.dup || []
        config.remaining_args = nil

        # Process STDIN content if available
        stdin_content = process_stdin_content
        config.stdin_content = stdin_content if stdin_content && !stdin_content.strip.empty?

        # Process arguments and validate
        process_prompt_id_from_args(config, remaining_args)
        validate_and_set_context_files(config, remaining_args)
        handle_executable_prompt(config)
        handle_stdin_as_prompt(config)
        handle_dump_config(config)
        handle_mcp_list(config)
        handle_list_tools(config)
        handle_completion_script(config)
        validate_required_prompt_id(config)
        process_role_configuration(config)
        handle_fuzzy_search_prompt_id(config)
        normalize_boolean_flags(config)
        validate_final_prompt_requirements(config)
        configure_prompt_manager(config)
        prepare_pipeline(config)
        validate_pipeline_prompts(config)

        config
      end

      def process_stdin_content
        stdin_content = String.new

        if !STDIN.tty? && !STDIN.closed?
          begin
            stdin_content << "\n" + STDIN.read
            STDIN.reopen('/dev/tty')
          rescue => _
            # If we can't reopen, continue without error
          end
        end

        stdin_content
      end

      def process_prompt_id_from_args(config, remaining_args)
        return if remaining_args.empty?

        maybe_id = remaining_args.first
        maybe_id_plus = File.join(config.prompts.dir, maybe_id + config.prompts.extname)

        if AIA.bad_file?(maybe_id) && AIA.good_file?(maybe_id_plus)
          config.prompt_id = remaining_args.shift
        end
      end

      def validate_and_set_context_files(config, remaining_args)
        return if remaining_args.empty?

        bad_files = remaining_args.reject { |filename| AIA.good_file?(filename) }
        if bad_files.any?
          STDERR.puts "Error: The following files do not exist: #{bad_files.join(', ')}"
          exit 1
        end

        config.context_files ||= []
        config.context_files += remaining_args
      end

      def handle_executable_prompt(config)
        # Legacy --exec flag path
        if config.executable_prompt && config.context_files && !config.context_files.empty?
          config.executable_prompt_file = config.context_files.pop
          return
        end

        # Auto-detect: no prompt_id, first context_file starts with shebang
        return unless config.prompt_id.nil?
        return unless config.context_files && !config.context_files.empty?

        candidate = config.context_files.first
        return unless File.exist?(candidate) && File.readable?(candidate)

        first_line = File.open(candidate, &:readline).strip rescue nil
        return unless first_line&.start_with?('#!')

        # This is an executable prompt — the file content IS the prompt
        config.context_files.shift
        config.executable_prompt_content = File.read(candidate).lines[1..].join
        config.prompt_id = '__EXECUTABLE_PROMPT__'
      end

      def handle_stdin_as_prompt(config)
        return unless config.prompt_id.nil?
        return unless config.stdin_content && !config.stdin_content.strip.empty?

        content = config.stdin_content

        # Strip shebang line if present (e.g., piped from an executable prompt)
        if content.lines.first&.strip&.start_with?('#!')
          content = content.lines[1..].join
        end

        config.executable_prompt_content = content
        config.stdin_content = nil  # prevent double-processing in build_prompt_text
        config.prompt_id = '__EXECUTABLE_PROMPT__'
      end

      def validate_required_prompt_id(config)
        return unless config.prompt_id.nil? && !(config.flags.chat == true) && !(config.flags.fuzzy == true)

        STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
        exit 1
      end

      def process_role_configuration(config)
        role = config.prompts.role
        return if role.nil? || role.empty?

        roles_prefix = config.prompts.roles_prefix
        unless roles_prefix.nil? || roles_prefix.empty?
          unless role.start_with?(roles_prefix)
            config.prompts.role = "#{roles_prefix}/#{role}"
            role = config.prompts.role
          end
        end

        config.prompts.roles_dir ||= File.join(config.prompts.dir, roles_prefix)

        if config.prompt_id.nil? || config.prompt_id.empty?
          unless role.nil? || role.empty?
            config.prompt_id = role
            config.pipeline.prepend(config.prompt_id)
            config.prompts.role = ''
          end
        end
      end

      def handle_fuzzy_search_prompt_id(config)
        return unless (config.flags.fuzzy == true) && (config.prompt_id.nil? || config.prompt_id.empty?)

        config.prompt_id = '__FUZZY_SEARCH__'
      end

      def normalize_boolean_flags(config)
        normalize_boolean_flag(config.flags, :chat)
        normalize_boolean_flag(config.flags, :fuzzy)
        normalize_boolean_flag(config.flags, :consensus)
      end

      def normalize_boolean_flag(flags_section, flag)
        value = flags_section.send(flag)
        return if [TrueClass, FalseClass].include?(value.class)

        normalized = case value
                     when nil, '', 'false', false
                       false
                     when 'true', true
                       true
                     else
                       true
                     end

        flags_section.send("#{flag}=", normalized)
      end

      def handle_dump_config(config)
        return unless config.dump_file

        dump_config(config, config.dump_file)
        exit 0
      end

      def handle_mcp_list(config)
        return unless config.mcp_list
        return if config.list_tools  # defer to handle_list_tools for combined output

        servers = filter_mcp_servers(config)

        if servers.empty?
          puts "No MCP servers configured."
        else
          label = mcp_filter_active?(config) ? "Active" : "Configured"
          puts "#{label} MCP servers:\n\n"
          servers.each do |server|
            name    = server[:name]    || server['name']    || '(unnamed)'
            command = server[:command] || server['command']  || '(no command)'
            args    = server[:args]    || server['args']     || []
            args_str = args.empty? ? '' : " #{args.join(' ')}"
            puts "  #{name}"
            puts "    command: #{command}#{args_str}"
            puts
          end
        end

        exit 0
      end

      def handle_list_tools(config)
        return unless config.list_tools

        local_tools = load_local_tools(config)
        mcp_tool_groups = {}

        if config.mcp_list
          mcp_tool_groups = load_mcp_tools_grouped(config)
        end

        if local_tools.empty? && mcp_tool_groups.empty?
          $stderr.puts "No tools available."
          exit 0
        end

        if $stdout.tty?
          list_tools_terminal(local_tools, mcp_tool_groups)
        else
          list_tools_markdown(local_tools, mcp_tool_groups)
        end

        exit 0
      end

      def list_tools_terminal(local_tools, mcp_tool_groups)
        width  = (ENV['COLUMNS'] || 80).to_i - 4
        indent = '    '

        unless local_tools.empty?
          puts "Local Tools:\n\n"
          local_tools.each { |tool| print_tool_terminal(tool, width, indent) }
        end

        mcp_tool_groups.each do |server_name, tools|
          puts "MCP: #{server_name} (#{tools.size} tools)\n\n"
          tools.each { |tool| print_tool_terminal(tool, width, indent) }
        end
      end

      def print_tool_terminal(tool, width, indent)
        name = tool.respond_to?(:name) ? tool.name : tool.class.name
        desc = tool.respond_to?(:description) ? tool.description.to_s.strip : ''

        puts "  #{name}"
        unless desc.empty?
          brief = first_sentences(desc, 3)
          wrapped = WordWrapper::MinimumRaggedness.new(width, brief).wrap
          wrapped.split("\n").each { |line| puts "#{indent}#{line}" }
        end
        puts
      end

      def list_tools_markdown(local_tools, mcp_tool_groups)
        total = local_tools.size + mcp_tool_groups.values.sum(&:size)
        sources = 1 + mcp_tool_groups.size

        puts "# Available Tools"
        puts
        puts "> #{total} tools from #{sources} source#{'s' if sources > 1}"
        puts

        unless local_tools.empty?
          puts "## Local Tools (#{local_tools.size})"
          puts
          local_tools.each { |tool| print_tool_markdown(tool) }
        end

        mcp_tool_groups.each do |server_name, tools|
          puts "## MCP: #{server_name} (#{tools.size})"
          puts
          tools.each { |tool| print_tool_markdown(tool) }
        end
      end

      def print_tool_markdown(tool)
        name = tool.respond_to?(:name) ? tool.name : tool.class.name
        desc = tool.respond_to?(:description) ? tool.description.to_s.strip : ''

        puts "### `#{name}`"
        puts
        unless desc.empty?
          puts nest_markdown_headings(desc, 3)
          puts
        end
      end

      # Adjusts any markdown headings in text so they nest under the
      # given parent heading level. e.g. with parent_level=3 (###),
      # a "# Foo" becomes "#### Foo" and "## Bar" becomes "##### Bar".
      # Handles headings with optional leading whitespace.
      def nest_markdown_headings(text, parent_level)
        text.gsub(/^[ \t]*(\#{1,6})\s/) do |match|
          existing = $1
          "#" * (existing.length + parent_level) + " "
        end
      end

      def filter_mcp_servers(config)
        servers  = config.mcp_servers || []
        use_list  = Array(config.mcp_use)
        skip_list = Array(config.mcp_skip)

        if !use_list.empty?
          servers.select { |s| use_list.include?(s[:name] || s['name']) }
        elsif !skip_list.empty?
          servers.reject { |s| skip_list.include?(s[:name] || s['name']) }
        else
          servers
        end
      end

      def mcp_filter_active?(config)
        !Array(config.mcp_use).empty? || !Array(config.mcp_skip).empty?
      end

      def load_local_tools(config)
        # Load required libraries (with gem activation and lazy-load triggering)
        Array(config.require_libs).each do |lib|
          begin
            Adapter::GemActivator.activate_gem_for_require(lib)
            require lib
            Adapter::GemActivator.trigger_tool_loading(lib)
          rescue LoadError => e
            warn "Warning: Failed to require '#{lib}': #{e.message}"
            warn "Hint: Make sure the gem is installed: gem install #{lib}"
          rescue StandardError => e
            warn "Warning: Error in library '#{lib}': #{e.class} - #{e.message}"
          end
        end

        # Load tool files
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

        # Scan ObjectSpace for RubyLLM::Tool subclasses
        ObjectSpace.each_object(Class).select do |klass|
          next false unless klass < RubyLLM::Tool

          begin
            klass.new
            true
          rescue ArgumentError, LoadError, StandardError
            false
          end
        end
      end

      def first_sentences(text, count)
        # Normalize whitespace: collapse newlines and multiple spaces
        normalized = text.gsub(/\s*\n\s*/, ' ').gsub(/\s{2,}/, ' ').strip
        sentences  = normalized.scan(/[^.!?]*[.!?]/)
        result     = sentences.first(count).join.strip
        result.empty? ? normalized : result
      end

      def load_mcp_tools_grouped(config)
        servers = filter_mcp_servers(config)
        return {} if servers.empty?

        # Suppress MCP logger noise during listing
        quiet_mcp_logger

        groups = {}
        default_timeout = 8_000

        servers.each do |server|
          name    = server[:name]    || server['name']
          command = server[:command] || server['command']
          args    = server[:args]    || server['args'] || []
          env     = server[:env]     || server['env']  || {}

          raw_timeout = server[:timeout] || server['timeout'] || default_timeout
          timeout = raw_timeout.to_i < 1000 ? (raw_timeout.to_i * 1000) : raw_timeout.to_i
          timeout = [timeout, 30_000].min

          mcp_config = { command: command, args: Array(args) }
          mcp_config[:env] = env unless env.empty?

          begin
            $stderr.print "MCP: Connecting to #{name}..."
            $stderr.flush

            client = begin
              RubyLLM::MCP.add_client(
                name: name, transport_type: :stdio,
                config: mcp_config, request_timeout: timeout, start: false
              )
            rescue ArgumentError
              RubyLLM::MCP.add_client(
                name: name, transport_type: :stdio,
                config: mcp_config, start: false
              )
            end

            client = RubyLLM::MCP.clients[name]
            client.start

            if client.alive?
              server_tools = client.tools rescue []
              groups[name] = server_tools
              $stderr.puts " #{server_tools.size} tools"
            else
              $stderr.puts " failed"
            end
          rescue StandardError => e
            $stderr.puts " error: #{e.message}"
          end
        end

        groups
      end

      def quiet_mcp_logger
        if defined?(RubyLLM::MCP) && RubyLLM::MCP.respond_to?(:config)
          mcp_config = RubyLLM::MCP.config
          if mcp_config.respond_to?(:logger=)
            quiet = Logger.new(File::NULL)
            mcp_config.logger = quiet
          end
        end
      end

      def handle_completion_script(config)
        return unless config.completion

        generate_completion_script(config.completion)
        exit
      end

      def generate_completion_script(shell)
        script_path = File.join(File.dirname(__FILE__), "../aia_completion.#{shell}")

        if File.exist?(script_path)
          puts File.read(script_path)
        else
          STDERR.puts "ERROR: The shell '#{shell}' is not supported or the completion script is missing."
        end
      end

      def validate_final_prompt_requirements(config)
        chat_mode = config.flags.chat == true
        fuzzy_mode = config.flags.fuzzy == true
        if !chat_mode && !fuzzy_mode && (config.prompt_id.nil? || config.prompt_id.empty?) && (config.context_files.nil? || config.context_files.empty?)
          STDERR.puts "Error: A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
          exit 1
        end
      end

      def configure_prompt_manager(config)
        # PM v1.0.0 uses ERB parameters (<%= param %>) instead of regex-based extraction.
        # parameter_regex is deprecated and ignored.
        if config.prompts.parameter_regex
          warn "Warning: --regex / parameter_regex is deprecated. PM v1.0.0 uses ERB parameters (<%= param %>)."
        end
      end

      def prepare_pipeline(config)
        return if config.prompt_id.nil? || config.prompt_id.empty? || config.prompt_id == config.pipeline.first

        config.pipeline.prepend(config.prompt_id)
      end

      def validate_pipeline_prompts(config)
        return if config.pipeline.empty?

        and_exit = false

        config.pipeline.each do |prompt_id|
          next if prompt_id.nil? || prompt_id.empty? || prompt_id == '__FUZZY_SEARCH__' || prompt_id == '__EXECUTABLE_PROMPT__'

          prompt_file_path = File.join(config.prompts.dir, "#{prompt_id}#{config.prompts.extname}")
          unless File.exist?(prompt_file_path)
            STDERR.puts "Error: Prompt ID '#{prompt_id}' does not exist at #{prompt_file_path}"
            and_exit = true
          end
        end

        exit(1) if and_exit
      end

      # Dump configuration to file
      #
      # @param config [AIA::Config] the configuration to dump
      # @param file [String] the file path to dump to
      def dump_config(config, file)
        ext = File.extname(file).downcase

        config_hash = config.to_h

        # Remove runtime keys
        config_hash.delete(:prompt_id)
        config_hash.delete(:dump_file)

        content = case ext
                  when '.yml', '.yaml'
                    require 'yaml'
                    YAML.dump(config_hash.transform_keys(&:to_s))
                  else
                    raise "Unsupported config file format: #{ext}. Use .yml or .yaml"
                  end

        File.write(file, content)
        puts "Config successfully dumped to #{file}"
      end
    end
  end
end
