# lib/aia/config/defaults.rb

require 'yaml'
require 'toml-rb'
require 'date'
require 'prompt_manager'

module AIA
  module ConfigModules
    module Defaults
      DEFAULT_CONFIG = OpenStruct.new({
        adapter:      'ruby_llm', # 'ruby_llm' or ???
        #
        aia_dir:      File.join(ENV['HOME'], '.aia'),
        config_file:  File.join(ENV['HOME'], '.aia', 'config.yml'),
        out_file:     'temp.md',
        log_file:     File.join(ENV['HOME'], '.prompts', '_prompts.log'),
        context_files: [],
        #
        prompts_dir:  File.join(ENV['HOME'], '.prompts'),
        prompt_extname: PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION,
        #
        roles_prefix: 'roles',
        roles_dir:    File.join(ENV['HOME'], '.prompts', 'roles'),
        role:         '',

        #
        system_prompt: '',

        # Tools
        tools:          '',  # Comma-separated string of loaded tool names (set by adapter)
        allowed_tools:  nil, # nil means all tools are allowed; otherwise an Array of Strings which are the tool names
        rejected_tools: nil, # nil means no tools are rejected
        tool_paths:     [],  # Strings - absolute and relative to tools

        # Flags
        markdown: true,
        shell:    true,
        erb:      true,
        chat:     false,
        clear:    false,
        terse:    false,
        verbose:  false,
        debug:    $DEBUG_ME,
        fuzzy:    false,
        speak:    false,
        append:   false, # Default to not append to existing out_file

        # workflow
        pipeline: [],

        # PromptManager::Prompt Tailoring
        parameter_regex: PromptManager::Prompt.parameter_regex.to_s,

        # LLM tuning parameters
        temperature:          0.7,
        max_tokens:           2048,
        top_p:                1.0,
        frequency_penalty:    0.0,
        presence_penalty:     0.0,

        # Audio Parameters
        voice:                'alloy',
        speak_command:        'afplay', # 'afplay' for audio files on MacOS

        # Image Parameters
        image_size:           '1024x1024',
        image_quality:        'standard',
        image_style:          'vivid',

        # Models
        model:                ['gpt-4o-mini'],
        consensus:            nil, # nil/false = individual responses; true = consensus response
        speech_model:         'tts-1',
        transcription_model:  'whisper-1',
        embedding_model:      'text-embedding-ada-002',
        image_model:          'dall-e-3',

        # Model Regristery
        refresh:              7, # days between refreshes of model info; 0 means every startup
        last_refresh:         Date.today - 1,

        # Ruby libraries to require for Ruby binding
        require_libs: [],

        # MCP Servers (nil means not configured, set in config file)
        mcp_servers: nil,
      }).freeze
    end
  end
end
