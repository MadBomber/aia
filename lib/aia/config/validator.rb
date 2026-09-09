# frozen_string_literal: true

require 'word_wrapper'
require_relative '../skill_utils'

# lib/aia/config/validator.rb
#
# Validates and tailors configuration after it's been loaded.
# Handles prompt ID extraction, context file validation, role processing, etc.

module AIA
  # rubocop:disable Metrics/ModuleLength
  module ConfigValidator
    class << self
      # Tailor and validate the configuration
      #
      # @param config [AIA::Config] the configuration to validate
      # @return [AIA::Config] the validated configuration
      # :reek:TooManyStatements -- top-level validation pipeline: one named step per line, executed in fixed order
      def tailor(config)
        remaining_args = config.remaining_args&.dup || []
        config.remaining_args = nil

        # Process STDIN content if available
        stdin_content = process_stdin_content
        config.stdin_content = stdin_content if stdin_content && !stdin_content.strip.empty?

        # Tool files may define AIA::Directive subclasses used by PromptManager.
        require_tool_files(config)

        # Process arguments and validate
        process_prompt_id_from_args(config, remaining_args)
        validate_and_set_context_files(config, remaining_args)
        handle_executable_prompt(config)
        handle_stdin_as_prompt(config)
        return :early_exit if handle_early_exits(config) == :early_exit
        validate_required_prompt_id(config)
        process_role_configuration(config)
        validate_plugins_dir(config)
        handle_fuzzy_search_prompt_id(config)
        normalize_boolean_flags(config)
        validate_final_prompt_requirements(config)
        prepare_pipeline(config)
        validate_pipeline_prompts(config)

        config
      end

      def handle_early_exits(config)
        return :early_exit if handle_dump_config(config)       == :early_exit
        return :early_exit if handle_mcp_list(config)          == :early_exit
        return :early_exit if handle_list_tools(config)        == :early_exit
        return :early_exit if handle_list_skills(config)       == :early_exit
        :early_exit if handle_completion_script(config) == :early_exit
      end

      def process_stdin_content
        stdin_content = String.new

        if !$stdin.tty? && !$stdin.closed?
          begin
            stdin_content << ("\n" + $stdin.read)
            $stdin.reopen('/dev/tty')
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

        return unless AIA.bad_file?(maybe_id) && AIA.good_file?(maybe_id_plus)
        config.prompt_id = remaining_args.shift
      end

      def validate_and_set_context_files(config, remaining_args)
        return if remaining_args.empty?

        bad_files = remaining_args.reject { |filename| AIA.good_file?(filename) }
        if bad_files.any?
          # Detect likely flag typos: "_B" instead of "-B", "_CD" instead of "-CD", etc.
          flag_typos = bad_files.grep(/\A_[A-Za-z]/)
          if flag_typos.any?
            suggestions = flag_typos.map { |f| "-#{f[1..]}" }.join(', ')
            raise AIA::ConfigurationError,
                  "Unknown argument(s): #{flag_typos.join(', ')}\n" \
                  "Did you mean: #{suggestions}?\n" \
                  "Flags require a dash prefix (e.g., -B not _B)."
          end
          raise AIA::ConfigurationError, "The following files do not exist: #{bad_files.join(', ')}"
        end

        config.context_files ||= []
        config.context_files += remaining_args
      end

      def handle_executable_prompt(config)
        return unless config.prompt_id.nil?

        files = config.context_files
        return unless files && !files.empty?

        candidate = files.first
        return unless File.exist?(candidate) && File.readable?(candidate)

        first_line = File.open(candidate, &:readline).strip rescue nil
        return unless first_line&.start_with?('#!')

        files.shift
        config.executable_prompt_content = File.read(candidate).lines[1..].join
        config.prompt_id = '__EXECUTABLE_PROMPT__'
      end

      def handle_stdin_as_prompt(config)
        return unless config.prompt_id.nil?
        content = config.stdin_content
        return unless content && !content.strip.empty?

        if content.lines.first&.strip&.start_with?('#!')
          content = content.lines[1..].join
        end

        config.executable_prompt_content = content
        config.stdin_content = nil
        config.prompt_id = '__EXECUTABLE_PROMPT__'
      end

      def validate_required_prompt_id(config)
        return unless config.prompt_id.nil? && config.flags.chat != true && config.flags.fuzzy != true

        raise AIA::ConfigurationError,
              "A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
      end

      def process_role_configuration(config)
        prompts = config.prompts
        role    = prompts.role
        return if role.nil? || role.empty?

        roles_prefix = prompts.roles_prefix
        unless AIA::SkillUtils.path_based_id?(role) || roles_prefix.nil? || roles_prefix.empty? || role.start_with?(roles_prefix)
          role = "#{roles_prefix}/#{role}"
          prompts.role = role
        end

        prompts.roles_dir ||= File.join(prompts.dir, roles_prefix.to_s)

        return if config.flags&.chat == true

        return unless config.prompt_id.nil? || config.prompt_id.empty?
        config.prompt_id = role
        config.pipeline.prepend(role)
        prompts.role = ''
      end

      def validate_plugins_dir(config)
        plugins_dir = config.paths&.plugins_dir
        return if plugins_dir.nil? || plugins_dir.to_s.strip.empty?
        return if Dir.exist?(plugins_dir)

        $stderr.puts "Warning: configured plugins directory does not exist: #{plugins_dir}"
      end

      def handle_fuzzy_search_prompt_id(config)
        return unless (config.flags.fuzzy == true) && (config.prompt_id.nil? || config.prompt_id.empty?)

        config.prompt_id = '__FUZZY_SEARCH__'
      end

      def normalize_boolean_flags(config)
        flags = config.flags
        normalize_boolean_flag(flags, :chat)
        normalize_boolean_flag(flags, :fuzzy)
        normalize_boolean_flag(flags, :consensus)
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
        :early_exit
      end

      def handle_mcp_list(config)
        return unless config.mcp_list
        return if config.list_tools

        servers = filter_mcp_servers(config)

        if servers.empty?
          puts "No MCP servers configured."
        else
          label = mcp_filter_active?(config) ? "Active" : "Configured"
          puts "#{label} MCP servers:\n\n"
          servers.each { |server| print_mcp_server(McpServerConfig.from_hash(server)) }
        end

        :early_exit
      end

      def print_mcp_server(server_config)
        args_str = server_config.args.empty? ? '' : " #{server_config.args.join(' ')}"
        puts "  #{server_config.name || '(unnamed)'}"
        puts "    command: #{server_config.command || '(no command)'}#{args_str}"
        puts
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
          return :early_exit
        end

        if $stdout.tty?
          list_tools_terminal(local_tools, mcp_tool_groups)
        else
          list_tools_markdown(local_tools, mcp_tool_groups)
        end

        :early_exit
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
        name = ToolIntrospection.tool_name(tool)
        desc = ToolIntrospection.tool_description(tool).strip

        puts "  #{name}"
        unless desc.empty?
          brief = first_sentences(desc, 3)
          wrapped = WordWrapper::MinimumRaggedness.new(width, brief).wrap
          wrapped.split("\n").each { |line| puts "#{indent}#{line}" }
        end
        puts
      end

      # :reek:TooManyStatements -- sequential markdown report: header, local tools section, one section per MCP server
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
        name = ToolIntrospection.tool_name(tool)
        desc = ToolIntrospection.tool_description(tool).strip

        puts "### `#{name}`"
        puts
        return if desc.empty?
        puts nest_markdown_headings(desc, 3)
        puts
      end

      def nest_markdown_headings(text, parent_level)
        text.gsub(/^[ \t]*(\#{1,6})\s/) do |_match|
          existing = ::Regexp.last_match(1)
          ("#" * (existing.length + parent_level)) + " "
        end
      end

      def filter_mcp_servers(config)
        servers = config.mcp_servers || []
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

      def require_tool_files(config)
        Array(config.tools&.paths).each do |path|
          expanded = File.expand_path(path)
          if File.exist?(expanded)
            require expanded
          else
            $stderr.puts "Warning: Tool file not found: #{path}"
          end
        rescue LoadError, StandardError => e
          $stderr.puts "Warning: Failed to load tool '#{path}': #{e.message}"
        end
      end

      # Canonical --list-skills handler. Runs after config is built (so a -c
      # config file's skills.dir is honored) and resolves skills the same way
      # loading does, so what is listed is always loadable.
      def handle_list_skills(config)
        return unless config.respond_to?(:list_skills) && config.list_skills

        puts AIA::SkillUtils.list_skills_markdown(config)
        :early_exit
      end

      def load_local_tools(config)
        require_configured_libs(config)
        require_tool_files(config)
        instantiable_tool_classes
      end

      # :reek:DuplicateMethodCall -- each e.message belongs to a different rescue clause exception; nothing to hoist
      def require_configured_libs(config)
        Array(config.require_libs).each do |lib|
          require lib
        rescue LoadError => e
          $stderr.puts "Warning: Failed to require '#{lib}': #{e.message}"
          $stderr.puts "Hint: Make sure the gem is installed: gem install #{lib}"
        rescue StandardError => e
          $stderr.puts "Warning: Error in library '#{lib}': #{e.class} - #{e.message}"
        end
      end

      # Scan ObjectSpace for RubyLLM::Tool subclasses that can be instantiated.
      def instantiable_tool_classes
        ObjectSpace.each_object(Class).select do |klass|
          next false unless defined?(RubyLLM::Tool) && klass < RubyLLM::Tool

          begin
            klass.new
            true
          rescue StandardError
            false
          end
        end
      end

      def first_sentences(text, count)
        normalized = text.gsub(/\s*\n\s*/, ' ').gsub(/\s{2,}/, ' ').strip
        sentences  = normalized.scan(/[^.!?]*[.!?]/)
        result     = sentences.first(count).join.strip
        result.empty? ? normalized : result
      end

      # :reek:TooManyStatements -- per-server connect loop with progress prints on each outcome path
      def load_mcp_tools_grouped(config)
        servers = filter_mcp_servers(config)
        return {} if servers.empty?

        quiet_mcp_logger

        servers.each_with_object({}) do |server, groups|
          server_config = McpServerConfig.from_hash(server)
          $stderr.print "MCP: Connecting to #{server_config.name}..."
          $stderr.flush

          tools = collect_server_tools(server_config)
          if tools
            groups[server_config.name] = tools
            $stderr.puts " #{tools.size} tools"
          else
            $stderr.puts " failed"
          end
        rescue StandardError => e
          $stderr.puts " error: #{e.message}"
        end
      end

      # Connect to one server and return its tools, or nil when the client
      # never comes alive.
      def collect_server_tools(server_config)
        mcp_add_client(server_config)
        client = RubyLLM::MCP.clients[server_config.name]
        client.start
        return nil unless client.alive?

        client.tools rescue []
      end

      def mcp_add_client(server_config)
        mcp_config = { command: server_config.command, args: server_config.args }
        mcp_config[:env] = server_config.env unless server_config.env.empty?

        RubyLLM::MCP.add_client(
          name: server_config.name, transport_type: :stdio,
          config: mcp_config, request_timeout: server_config.timeout_ms, start: false
        )
      rescue ArgumentError
        # Older ruby_llm-mcp versions do not accept request_timeout
        RubyLLM::MCP.add_client(
          name: server_config.name, transport_type: :stdio,
          config: mcp_config, start: false
        )
      end
      # rubocop:enable Metrics/ModuleLength

      def quiet_mcp_logger
        return unless defined?(RubyLLM::MCP) && RubyLLM::MCP.respond_to?(:config)
        mcp_config = RubyLLM::MCP.config
        return unless mcp_config.respond_to?(:logger=)
        quiet = Logger.new(File::NULL)
        mcp_config.logger = quiet
      end

      def handle_completion_script(config)
        return unless config.completion

        generate_completion_script(config.completion)
        :early_exit
      end

      def generate_completion_script(shell)
        script_path = File.join(File.dirname(__FILE__), "../aia_completion.#{shell}")

        if File.exist?(script_path)
          puts File.read(script_path)
        else
          $stderr.puts "ERROR: The shell '#{shell}' is not supported or the completion script is missing."
        end
      end

      def validate_final_prompt_requirements(config)
        chat_mode = config.flags.chat == true
        fuzzy_mode = config.flags.fuzzy == true
        no_prompt = config.prompt_id.nil? || config.prompt_id.empty?
        no_context = config.context_files.nil? || config.context_files.empty?
        return unless !chat_mode && !fuzzy_mode && no_prompt && no_context
        raise AIA::ConfigurationError,
              "A prompt ID is required unless using --chat, --fuzzy, or providing context files. Use -h or --help for help."
      end

      def prepare_pipeline(config)
        prompt_id = config.prompt_id
        return if prompt_id.nil? || prompt_id.empty? || prompt_id == config.pipeline.first

        config.pipeline.prepend(prompt_id)
      end

      def validate_pipeline_prompts(config)
        return if config.pipeline.empty?

        and_exit = false

        config.pipeline.each do |prompt_id|
          next if prompt_id.nil? || prompt_id.empty? || prompt_id == '__FUZZY_SEARCH__' || prompt_id == '__EXECUTABLE_PROMPT__'

          prompt_file_path = File.join(config.prompts.dir, "#{prompt_id}#{config.prompts.extname}")
          unless File.exist?(prompt_file_path)
            $stderr.puts "Error: Prompt ID '#{prompt_id}' does not exist at #{prompt_file_path}"
            and_exit = true
          end
        end

        raise AIA::ConfigurationError, "One or more prompt IDs do not exist." if and_exit
      end

      def dump_config(config, file)
        ext = File.extname(file).downcase

        config_hash = config.to_h

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
