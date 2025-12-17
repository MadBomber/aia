# lib/aia/config/base.rb

require 'ostruct'
require 'date'
require_relative 'defaults'
require_relative 'cli_parser'
require_relative 'file_loader'
require_relative 'validator'

module AIA
  module ConfigModules
    module Base
      class << self
        # Delegate to other config modules
        def cli_options
          CLIParser.cli_options
        end

        def cf_options(file)
          FileLoader.cf_options(file)
        end

        def dump_config(config, file)
          FileLoader.dump_config(config, file)
        end

        def generate_completion_script(shell)
          FileLoader.generate_completion_script(shell)
        end

        def tailor_the_config(config)
          Validator.tailor_the_config(config)
        end

        def validate_pipeline_prompts(config)
          Validator.validate_pipeline_prompts(config)
        end

        def normalize_boolean_flag(config, flag)
          Validator.normalize_boolean_flag(config, flag)
        end

        def process_tools_option(path_list, config)
          CLIParser.process_tools_option(path_list, config)
        end

        def validate_and_set_context_files(config, remaining_args)
          Validator.validate_and_set_context_files(config, remaining_args)
        end

        def setup_mode_options(opts, config)
          CLIParser.setup_mode_options(opts, config)
        end

        def parse_config_content(content, ext)
          FileLoader.parse_config_content(content, ext)
        end

        def normalize_last_refresh_date(config)
          FileLoader.normalize_last_refresh_date(config)
        end

        def process_prompt_id_from_args(config, remaining_args)
          Validator.process_prompt_id_from_args(config, remaining_args)
        end

        def process_role_configuration(config)
          Validator.process_role_configuration(config)
        end

        def prepare_pipeline(config)
          Validator.prepare_pipeline(config)
        end

        def setup_model_options(opts, config)
          CLIParser.setup_model_options(opts, config)
        end

        def setup_ai_parameters(opts, config)
          CLIParser.setup_ai_parameters(opts, config)
        end

        def read_and_process_config_file(file)
          FileLoader.read_and_process_config_file(file)
        end

        def process_stdin_content
          Validator.process_stdin_content
        end

        def process_allowed_tools_option(tools_list, config)
          CLIParser.process_allowed_tools_option(tools_list, config)
        end

        def process_rejected_tools_option(tools_list, config)
          CLIParser.process_rejected_tools_option(tools_list, config)
        end

        def normalize_boolean_flags(config)
          Validator.normalize_boolean_flags(config)
        end

        def handle_executable_prompt(config)
          Validator.handle_executable_prompt(config)
        end

        def handle_fuzzy_search_prompt_id(config)
          Validator.handle_fuzzy_search_prompt_id(config)
        end

        def create_option_parser(config)
          CLIParser.create_option_parser(config)
        end

        def apply_file_config_to_struct(config, file_config)
          FileLoader.apply_file_config_to_struct(config, file_config)
        end

        def configure_prompt_manager(config)
          Validator.configure_prompt_manager(config)
        end

        def setup
          default_config  = Defaults::DEFAULT_CONFIG.dup
          cli_config      = cli_options
          envar_config    = envar_options(default_config, cli_config)

          file = envar_config.config_file   unless envar_config.config_file.nil?
          file = cli_config.config_file     unless cli_config.config_file.nil?

          cf_config     = cf_options(file)

          config        = OpenStruct.merge(
                            default_config,
                            cf_config    || {},
                            envar_config || {},
                            cli_config   || {}
                          )

          config = tailor_the_config(config)
          load_libraries(config)
          load_tools(config)
          load_mcp_servers(config)

          if config.dump_file
            dump_config(config, config.dump_file)
          end

          config
        end

        def load_libraries(config)
          return if config.require_libs.empty?

          exit_on_error = false

          config.require_libs.each do |library|
            begin
              require(library)
              # Check if the library provides tools that need eager loading
              # Convert library name to module constant (e.g., 'shared_tools' -> 'SharedTools')
              eager_load_tools_from_library(library)
            rescue => e
              STDERR.puts "Error loading library '#{library}' #{e.message}"
            exit_on_error = true
            end
          end

          exit(1) if exit_on_error

          config
        end

        # Attempt to eager load tools from a required library
        # Libraries that use Zeitwerk need their tools eager loaded so they
        # appear in ObjectSpace for AIA's tool discovery
        def eager_load_tools_from_library(library)
          # Convert library name to module constant (e.g., 'shared_tools' -> 'SharedTools')
          module_name = library.split('/').first.split('_').map(&:capitalize).join

          begin
            mod = Object.const_get(module_name)
            if mod.respond_to?(:load_all_tools)
              mod.load_all_tools
            end
          rescue NameError
            # Module doesn't exist with expected name, skip
          end
        end

        def load_tools(config)
          return if config.tool_paths.empty?

          require_all_tools(config)

          config
        end

        def require_all_tools(config)
          exit_on_error = false

          config.tool_paths.each do |tool_path|
            begin
              # expands path based on PWD
              absolute_tool_path = File.expand_path(tool_path)
              require(absolute_tool_path)
            rescue => e
              STDERR.puts "Error loading tool '#{tool_path}' #{e.message}"
            exit_on_error = true
            end
          end

          exit(1) if exit_on_error
        end

        def load_mcp_servers(config)
          servers = config.mcp_servers

          return config if servers.nil? || (servers.respond_to?(:empty?) && servers.empty?)

          servers.each do |server|
            name    = server[:name]    || server["name"]
            command = server[:command] || server["command"]
            args    = server[:args]    || server["args"] || []
            env     = server[:env]     || server["env"]  || {}
            timeout = server[:timeout] || server["timeout"] || 8000  # default 8 seconds in ms

            unless name && command
              STDERR.puts "WARNING: MCP server entry missing name or command: #{server.inspect}"
              next
            end

            # Resolve command path if not absolute
            resolved_command = resolve_command_path(command)
            unless resolved_command
              STDERR.puts "WARNING: MCP server '#{name}' command not found: #{command}"
              next
            end

            begin
              RubyLLM::MCP.add_client(
                name:            name,
                transport_type:  :stdio,
                request_timeout: timeout,
                config: {
                  command:  resolved_command,
                  args:     args,
                  env:      env
                }
              )
            rescue => e
              STDERR.puts "ERROR: Failed to load MCP server '#{name}': #{e.message}"
            end
          end

          config
        end

        def resolve_command_path(command)
          # If already absolute path, verify it exists
          if command.start_with?('/')
            return File.executable?(command) ? command : nil
          end

          # Search in PATH
          ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
            full_path = File.join(dir, command)
            return full_path if File.executable?(full_path)
          end

          nil
        end

        # envar values are always String object so need other config
        # layers to know the prompter type for each key's value
        def envar_options(default, cli_config)
          config = OpenStruct.merge(default, cli_config)
          envars = ENV.keys.select { |key, _| key.start_with?('AIA_') }
          envars.each do |envar|
            key   = envar.sub(/^AIA_/, '').downcase.to_sym
            value = ENV[envar]

            value = case config[key]
                    when TrueClass, FalseClass
                      value.downcase == 'true'
                    when Integer
                      value.to_i
                    when Float
                      value.to_f
                    when Array
                      # Special handling for :model to support inline role syntax (ADR-005 v2)
                      if key == :model && value.include?('=')
                        CLIParser.parse_models_with_roles(value)
                      else
                        value.split(',').map(&:strip)
                      end
                    else
                      value # defaults to String
                    end
            config[key] = value
          end

          config
        end
      end
    end
  end
end
