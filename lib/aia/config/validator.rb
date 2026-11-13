# frozen_string_literal: true

require 'timeout'
require 'did_you_mean'
require 'word_wrapper'
require_relative '../skill_utils'
require_relative '../role_catalog'

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
        adopt_pipeline_head(config)
        process_role_configuration(config)
        validate_model_roles(config)
        validate_required_prompt_id(config)
        validate_plugins_dir(config)
        handle_fuzzy_search_prompt_id(config)
        normalize_boolean_flags(config)
        prepare_pipeline(config)
        validate_pipeline_prompts(config)

        config
      end

      def handle_early_exits(config)
        return :early_exit if handle_dump_config(config)       == :early_exit
        return :early_exit if handle_mcp_list(config)          == :early_exit
        return :early_exit if handle_list_tools(config)        == :early_exit
        return :early_exit if handle_list_skills(config)       == :early_exit
        return :early_exit if handle_list_roles(config)        == :early_exit
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
          raise AIA::ConfigurationError, missing_prompt_message(config, bad_files) if missing_prompt_id?(config, remaining_args, bad_files)
          raise AIA::ConfigurationError, "The following files do not exist: #{bad_files.join(', ')}"
        end

        config.context_files ||= []
        config.context_files += remaining_args
      end

      # The first argument looks like a prompt ID (no extension) but names
      # neither a prompt nor a file.
      def missing_prompt_id?(config, remaining_args, bad_files)
        word = remaining_args.first
        config.prompt_id.nil? && bad_files.first == word && File.extname(word).empty?
      end

      def missing_prompt_message(config, bad_files)
        word, *others = bad_files
        dir = config.prompts.dir
        message = "No prompt named '#{word}' in #{dir} (and no file by that name)."
        suggestions = prompt_suggestions(word, dir, config.prompts.extname)
        message += "\nDid you mean: #{suggestions.join(', ')}?" if suggestions.any?
        message += "\nThe following files do not exist: #{others.join(', ')}" if others.any?
        message
      end

      # Prompt IDs under +dir+ that are close spellings of +word+.
      def prompt_suggestions(word, dir, extname)
        return [] unless dir && Dir.exist?(dir)

        ids = Dir.glob("**/*#{extname}", base: dir).map { it.delete_suffix(extname) }
        DidYouMean::SpellChecker.new(dictionary: ids).correct(word).first(3)
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

        config.executable_prompt_content = strip_shebang(content)
        config.stdin_content = nil
        config.prompt_id = '__EXECUTABLE_PROMPT__'
      end

      # Piped text arrives with a leading newline (see process_stdin_content).
      # Drop it, and a "#!" line if the text starts with one, so the front
      # matter that follows is recognized.
      def strip_shebang(content)
        text = content.delete_prefix("\n")
        text.start_with?('#!') ? text.lines[1..].join : text
      end

      # With no prompt ID, --pipeline's first prompt is the one to run.
      def adopt_pipeline_head(config)
        return unless config.prompt_id.nil? || config.prompt_id.empty?

        head = Array(config.pipeline).first
        config.prompt_id = head unless head.nil? || head.empty?
      end

      def validate_required_prompt_id(config)
        return unless config.prompt_id.nil? && config.flags.chat != true && config.flags.fuzzy != true

        raise AIA::ConfigurationError,
              "A prompt ID is required unless you use --chat, --fuzzy, --pipeline or --role, " \
              "pipe the prompt in, or run an executable prompt. Context files alone are not a prompt. " \
              "Use -h or --help for help."
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
        validate_role(config, role)

        return if config.flags&.chat == true

        return unless config.prompt_id.nil? || config.prompt_id.empty?
        config.prompt_id = role
        config.pipeline.prepend(role)
        prompts.role = ''
      end

      # A --role must exist, like a -m MODEL=ROLE role. With --fuzzy a
      # missing role is left to the fzf role picker.
      def validate_role(config, role)
        return if config.flags&.fuzzy == true

        prompts = config.prompts
        AIA::RoleCatalog.validate!(role, dir: prompts.dir, prefix: prompts.roles_prefix, extname: prompts.extname)
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
        if server_config.command.nil? && server_config.url
          puts "    url: #{server_config.url}"
        else
          puts "    command: #{server_config.command || '(no command)'}#{args_str}"
        end
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

      # The servers --mcp-use/--mcp-skip keep. --require libraries are loaded
      # first and entries naming a RubyLLM::MCP subclass are resolved to it,
      # exactly as a session does before connecting.
      def filter_mcp_servers(config)
        AIA::ToolLoader.require_libs(config)
        selected = AIA::MCPDiscovery.select(config.mcp_servers || [], use: config.mcp_use, skip: config.mcp_skip)
        AIA::MCPDiscovery.new.resolve_entries(selected)
      end

      def mcp_filter_active?(config)
        !Array(config.mcp_use).empty? || !Array(config.mcp_skip).empty?
      end

      def require_tool_files(config)
        AIA::ToolLoader.require_tool_files(config)
      end

      # Canonical --list-skills handler. Runs after config is built (so a -c
      # config file's skills.dir is honored) and resolves skills the same way
      # loading does, so what is listed is always loadable.
      def handle_list_skills(config)
        return unless config.respond_to?(:list_skills) && config.list_skills

        puts AIA::SkillUtils.list_skills_markdown(config)
        :early_exit
      end

      # --list-roles, from the configured prompts directory and roles prefix.
      def handle_list_roles(config)
        return unless config.respond_to?(:list_roles) && config.list_roles

        prompts = config.prompts
        puts AIA::RoleCatalog.listing(prompts.dir, prompts.roles_prefix, extname: prompts.extname)
        :early_exit
      end

      # Every -m MODEL=ROLE role must exist in the configured prompts directory.
      def validate_model_roles(config)
        prompts = config.prompts
        Array(config.models).each do |spec|
          role = spec.respond_to?(:role) ? spec.role : nil
          next if role.nil? || role.to_s.empty?

          AIA::RoleCatalog.validate!(role, dir: prompts.dir, prefix: prompts.roles_prefix, extname: prompts.extname)
        end
      end

      # The local tools a session would offer: loaded the same way
      # (--require gems, --tools files, lazily loaded tool gems) and narrowed
      # by --allowed-tools / --rejected-tools.
      def load_local_tools(config)
        ToolLoader.load_tools(config)
        ToolLoader.filtered_tools(config)
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

        servers.each_with_object({}) do |server, groups|
          server_config = McpServerConfig.from_hash(server)
          $stderr.print "MCP: Connecting to #{server_config.name}..."
          $stderr.flush

          tools = collect_server_tools(server, server_config)
          groups[server_config.name] = tools
          $stderr.puts " #{tools.size} tools"
        rescue StandardError => e
          $stderr.puts " error: #{e.message}"
        end
      end

      # Build the server the way MCPConnectionManager does (RobotLab::MCP.build,
      # so --list-tools shows exactly the RubyLLM::MCP::Tools a robot would be
      # handed) and return its tools. Connection failures raise. The server is
      # closed before returning.
      def collect_server_tools(server, server_config)
        mcp = RobotLab::MCP.build(MCPConfigNormalizer.normalize(server))
        Timeout.timeout(server_config.timeout_ms / 1000.0) { mcp.tools }
      ensure
        mcp&.close
      end
      # rubocop:enable Metrics/ModuleLength

      def handle_completion_script(config)
        return unless config.completion

        generate_completion_script(config.completion)
        :early_exit
      end

      def generate_completion_script(shell)
        script_path = File.join(File.dirname(__FILE__), "../aia_completion.#{shell}")

        unless File.exist?(script_path)
          raise AIA::ConfigurationError,
                "ERROR: The shell '#{shell}' is not supported (use bash, zsh or fish)."
        end

        puts File.read(script_path)
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

          prompt_file_path = AIA::SkillUtils.prompt_file_path(prompt_id, dir: config.prompts.dir, extname: config.prompts.extname)
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
                    raise ConfigurationError, "Unsupported config file format: #{ext}. Use .yml or .yaml"
                  end

        begin
          File.write(file, content)
        rescue SystemCallError => e
          raise ConfigurationError, "Cannot write config dump to #{file}: #{e.message}"
        end
        puts "Config successfully dumped to #{file}"
      end
    end
  end
end
