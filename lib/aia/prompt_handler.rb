# lib/aia/prompt_handler.rb
#
# This file handles prompt management for the AIA application.

require 'prompt_manager'
require_relative 'prompt_processor'
require 'prompt_manager/storage/file_system_adapter'
require 'erb'

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # The PromptHandler class is responsible for managing and processing
  # prompts within the AIA application. It interacts with the PromptManager
  # to retrieve and process prompts.
  class PromptHandler
    # Initializes a new PromptHandler with the given configuration.
    #
    # @param config [OpenStruct] the configuration object
    def initialize(config)
      @config = config
      @prompts_dir = config.prompts_dir
      @roles_dir = config.roles_dir

      # Initialize PromptManager with the FileSystemAdapter
      PromptManager::Prompt.storage_adapter =
        PromptManager::Storage::FileSystemAdapter.config do |config|
          config.prompts_dir = @prompts_dir
          config.prompt_extension = '.txt'  # default
          config.params_extension = '.json' # default
        end.new
      @prompt_processor = PromptProcessor.new(config)
    end

    # Retrieves and processes a prompt by its ID, optionally prepending a role.
    #
    # @param prompt_id [String] the ID of the prompt to retrieve
    # @param role_id [String, nil] the ID of the role to prepend (optional)
    # @return [String] the processed prompt text
    def get_prompt(prompt_id, role_id = nil)
      # Get the prompt using the gem's functionality
      prompt = PromptManager::Prompt.get(id: prompt_id)

      if role_id
        # Get the role prompt
        role_prompt = PromptManager::Prompt.get(id: role_id)
        # Prepend role to prompt
        prompt.text = "#{role_prompt.text}
#{prompt.text}"
      end

      # Process the prompt using the gem's functionality
      process_prompt(prompt)
    end

    # Processes a given prompt, handling shell commands, ERB, and directives.
    #
    # @param prompt [PromptManager::Prompt, String] the prompt to process
    # @return [String] the processed prompt text
    def process_prompt(prompt)
      @prompt_processor.process(prompt)
    end
  end
end
