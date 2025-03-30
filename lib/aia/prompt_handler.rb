# lib/aia/prompt_handler.rb

require 'prompt_manager'
require_relative 'prompt_processor'
require 'prompt_manager/storage/file_system_adapter'
require 'erb'


module AIA
  class PromptHandler
    def initialize
      @prompts_dir         = AIA.config.prompts_dir
      @roles_dir           = AIA.config.roles_dir
      @directive_processor = AIA::DirectiveProcessor.new

      PromptManager::Prompt.storage_adapter =
        PromptManager::Storage::FileSystemAdapter.config do |c|
          c.prompts_dir      = @prompts_dir
          c.prompt_extension = '.txt'  # default
          c.params_extension = '.json' # default
        end.new

      @prompt_processor = PromptProcessor.new
    end


    def get_prompt(prompt_id, role_id = nil)
      # Get the prompt using the gem's functionality
      prompt = PromptManager::Prompt.get(
        id:                  prompt_id,
        shell_flag:          AIA.shell?,
        erb_flag:            AIA.erb?,
        directive_processor: @directive_processor,
        external_binding:    binding
      )

      if role_id
        role_prompt = PromptManager::Prompt.get(
          id:                  role_id,
          shell_flag:          AIA.shell?,
          erb_flag:            AIA.erb?,
          directive_processor: @directive_processor,
          external_binding:    binding
        )

        prompt.text = <<~TEXT
          #{role_prompt.text}
          #{prompt.text}
        TEXT
      end

      process_prompt(prompt)
    end


    def process_prompt(prompt)
      @prompt_processor.process(prompt)
    end
  end
end
