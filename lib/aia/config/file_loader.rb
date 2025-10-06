# lib/aia/config/file_loader.rb

require 'yaml'
require 'toml-rb'
require 'erb'
require 'date'

module AIA
  module ConfigModules
    module FileLoader
      class << self
        def load_config_file(file, config)
          if File.exist?(file)
            ext = File.extname(file).downcase
            content = File.read(file)

            # Process ERB if filename ends with .erb
            if file.end_with?('.erb')
              content = ERB.new(content).result
              file = file.chomp('.erb')
              File.write(file, content)
            end

            file_config = case ext
                          when '.yml', '.yaml'
                            YAML.safe_load(content, permitted_classes: [Symbol], symbolize_names: true)
                          when '.toml'
                            TomlRB.parse(content)
                          else
                            raise "Unsupported config file format: #{ext}"
                          end

            file_config.each do |key, value|
              config[key.to_sym] = value
            end
          else
            raise "Config file not found: #{file}"
          end
        end

        def cf_options(file)
          config = OpenStruct.new

          if File.exist?(file)
            content = read_and_process_config_file(file)
            file_config = parse_config_content(content, File.extname(file).downcase)
            apply_file_config_to_struct(config, file_config)
          else
            STDERR.puts "WARNING:Config file not found: #{file}"
          end

          normalize_last_refresh_date(config)
          config
        end

        def read_and_process_config_file(file)
          content = File.read(file)

          # Process ERB if filename ends with .erb
          if file.end_with?('.erb')
            content = ERB.new(content).result
            processed_file = file.chomp('.erb')
            File.write(processed_file, content)
          end

          content
        end

        def parse_config_content(content, ext)
          case ext
          when '.yml', '.yaml'
            YAML.safe_load(content, permitted_classes: [Symbol], symbolize_names: true)
          when '.toml'
            TomlRB.parse(content)
          else
            raise "Unsupported config file format: #{ext}"
          end
        end

        def apply_file_config_to_struct(config, file_config)
          file_config.each do |key, value|
            # Special handling for model array with roles (ADR-005 v2)
            if (key == :model || key == 'model') && value.is_a?(Array) && value.first.is_a?(Hash)
              config[:model] = process_model_array_with_roles(value)
            else
              config[key] = value
            end
          end
        end

        # Process model array with roles from config file (ADR-005 v2)
        # Format: [{model: "gpt-4o", role: "architect"}, ...]
        # Also supports models without roles: [{model: "gpt-4o"}, ...]
        def process_model_array_with_roles(models_array)
          return [] if models_array.nil? || models_array.empty?

          model_specs = []
          model_counts = Hash.new(0)

          models_array.each do |spec|
            model_name = spec[:model] || spec['model']
            role_name = spec[:role] || spec['role']

            model_counts[model_name] += 1
            instance = model_counts[model_name]

            model_specs << {
              model: model_name,
              role: role_name,
              instance: instance,
              internal_id: instance > 1 ? "#{model_name}##{instance}" : model_name
            }
          end

          model_specs
        end

        def normalize_last_refresh_date(config)
          return unless config.last_refresh&.is_a?(String)

          config.last_refresh = Date.strptime(config.last_refresh, '%Y-%m-%d')
        end

        def dump_config(config, file)
          # Implementation for config dump
          ext = File.extname(file).downcase

          config.last_refresh = config.last_refresh.to_s if config.last_refresh.is_a? Date

          config_hash = config.to_h

          # Remove prompt_id to prevent automatic initial pompting in --chat mode
          config_hash.delete(:prompt_id)

          # Remove dump_file key to prevent automatic exit on next load
          config_hash.delete(:dump_file)

          content = case ext
                    when '.yml', '.yaml'
                      YAML.dump(config_hash)
                    when '.toml'
                      TomlRB.dump(config_hash)
                    else
                      raise "Unsupported config file format: #{ext}"
                    end

          File.write(file, content)
          puts "Config successfully dumped to #{file}"
        end

        def generate_completion_script(shell)
          script_path = File.join(File.dirname(__FILE__), "../../aia_completion.#{shell}")

          if File.exist?(script_path)
            puts File.read(script_path)
          else
            STDERR.puts "ERROR: The shell '#{shell}' is not supported or the completion script is missing."
          end
        end
      end
    end
  end
end
