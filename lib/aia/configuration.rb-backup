# lib/aia/configuration.rb

HOME            = Pathname.new(ENV['HOME'])
PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))

AI_CLI_PROGRAM  = "mods"
MY_NAME         = "aia"
MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
OUTPUT          = Pathname.pwd + "temp.md"
PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"


module AIA::Configuration
  def setup_configuration
    @prompt     = nil

    PromptManager::Prompt.storage_adapter = 
      PromptManager::Storage::FileSystemAdapter.config do |config|
        config.prompts_dir        = PROMPTS_DIR
        config.prompt_extension   = '.txt'
        config.params_extension   = '.json'
        config.search_proc        = nil
        # TODO: add the rgfzz script for search_proc
      end.new
  end


  # Get the additional CLI arguments intended for the
  # backend gen-AI processor.
  def extract_extra_options
    extra_index = @arguments.index('--')
    if extra_index.nil?
      @extra_options = []
    else
      @extra_options = @arguments.slice!(extra_index..-1)[1..]
    end
  end
end



__END__

# lib/aia/configuration.rb

require 'pathname'
require 'yaml'
require 'toml-rb'

class AIA::Configuration
  attr_accessor :config

  def initialize(config_file_path)
    @config = parse_config_file(config_file_path)
  end

  private

  def parse_config_file(config_file_path)
    case config_file_path.extname.downcase
    when '.yaml', '.yml'
      YAML.safe_load(config_file_path.read)
    when '.toml'
      TomlRB.parse(config_file_path.read)
    else
      raise "Unsupported config file type: #{config_file_path.extname}"
    end
  end
end

# processing CLI flags and options from the config file

require 'yaml'
require 'toml-rb'
require 'shellwords'

# Define a method to load the configuration file
def load_config(config_file)
  if File.extname(config_file) == '.yaml'
    YAML.load_file(config_file)
  elsif File.extname(config_file) == '.toml'
    TomlRB.load_file(config_file)
  else
    raise ArgumentError, 'Unsupported configuration file format'
  end
end

# Define a method to determine if a value is boolean
def boolean?(value)
  [true, false].include?(value)
end

# Define a method to convert configuration options to command-line arguments
def config_to_cli_args(config)
  args = []
  config.each do |key, value|
    key_string = "--#{key.tr('_', '-')}" # Replace underscores by hyphens for multi-word flags
    if boolean?(value)
      # For boolean flags, add the key only if the value is true
      args << key_string if value
    else
      # For options with values, add the key and the escaped value
      args << key_string << Shellwords.escape(value.to_s)
    end
  end
  args.join(' ')
end

# Assume the configuration file is passed as the first argument
config_file = ARGV[0]
unless config_file
  puts 'Usage: generate_cli_command.rb <CONFIG_FILE>'
  exit(1)
end

# Load the configuration file
config = load_config(config_file)

# Generate the command-line arguments
cli_args = config_to_cli_args(config)

# Output the command line for the third-party CLI utility
puts "Command line options: #{cli_args}"





