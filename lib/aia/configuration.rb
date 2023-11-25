# lib/aia/configuration.rb

module AIA::Configuration
  HOME            = Pathname.new(ENV['HOME'])
  PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))
  
  AI_CLI_PROGRAM  = "mods"
  EDITOR          = ENV['EDITOR'] || 'edit'
  MY_NAME         = Pathname.new(__FILE__).basename.to_s.split('.')[0]
  MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
  OUTPUT          = Pathname.pwd + "temp.md"
  PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"

  def setup_defaults 
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
