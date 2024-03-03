# lib/aia/tools/llm.rb

require_relative 'backend_common'

class AIA::Llm < AIA::Tools
  include AIA::BackendCommon

  meta(
    name:     'llm',
    role:     :backend,
    desc:     "llm on the command line using local and remote models",
    url:      "https://llm.datasette.io/",
    install:  "brew install llm",
  )


  DEFAULT_PARAMETERS = [
    # "--verbose",          # enable verbose logging (if applicable)
    # Add default parameters here
  ].join(' ').freeze

  DIRECTIVES = %w[
    api_key
    frequency_penalty
    max_tokens
    model
    presence_penalty
    stop_sequence
    temperature
    top_p
  ]
end

__END__

#########################################################

llm, version 0.13.1

Usage: llm [OPTIONS] COMMAND [ARGS]...

  Access large language models from the command-line

  Documentation: https://llm.datasette.io/

  To get started, obtain an OpenAI key and set it like this:

      $ llm keys set openai
      Enter key: ...

  Then execute a prompt like this:

      llm 'Five outrageous names for a pet pelican'

Options:
  --version  Show the version and exit.
  --help     Show this message and exit.

Commands:
  prompt*       Execute a prompt
  aliases       Manage model aliases
  chat          Hold an ongoing chat with a model.
  collections   View and manage collections of embeddings
  embed         Embed text and store or return the result
  embed-models  Manage available embedding models
  embed-multi   Store embeddings for multiple strings at once
  install       Install packages from PyPI into the same environment as LLM
  keys          Manage stored API keys for different models
  logs          Tools for exploring logged prompts and responses
  models        Manage available models
  openai        Commands for working directly with the OpenAI API
  plugins       List installed plugins
  similar       Return top N similar IDs from a collection
  templates     Manage stored prompt templates
  uninstall     Uninstall Python packages from the LLM environment

  
