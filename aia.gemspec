# frozen_string_literal: true

require_relative 'lib/aia/version'

Gem::Specification.new do |spec|
  spec.name     = 'aia'
  spec.version  = AIA::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary      = 'Multi-model AI CLI with dynamic prompts, consensus responses, shell & Ruby integration, and seamless chat workflows.'
  spec.description  = <<~DESC
    AIA is a revolutionary CLI console application that brings multi-model AI capabilities to your command line, supporting 20+ providers including OpenAI, Anthropic, and Google. Run multiple AI models simultaneously for comparison, get consensus responses from collaborative AI teams, or compare individual outputs side-by-side. With dynamic prompt management, embedded directives, shell and Ruby integration, interactive chats, and comprehensive history tracking, AIA transforms how you interact with AI. Perfect for developers and AI enthusiasts who want to harness the collective intelligence of multiple AI models from a single, powerful interface.
  DESC

  spec.homepage     = 'https://github.com/MadBomber/aia'
  spec.license      = 'MIT'

  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri']     = spec.homepage
  spec.metadata['source_code_uri']  = spec.homepage
  spec.metadata['changelog_uri']    = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git Gemfile])
    end + ['.version']
  end

  spec.bindir         = 'bin'
  spec.executables    = %w[aia]
  spec.require_paths  = %w[lib]

  # spec.add_dependency "activesupport"
  spec.add_dependency 'amazing_print'
  spec.add_dependency 'async'
  spec.add_dependency 'clipboard'
  spec.add_dependency 'faraday'
  spec.add_dependency 'lumberjack'
  spec.add_dependency 'myway_config'
  spec.add_dependency 'prompt_manager', '~> 1.0.2'
  spec.add_dependency 'reline'
  spec.add_dependency 'ruby_llm'
  spec.add_dependency 'ruby_llm-mcp'
  spec.add_dependency 'shellwords'
  spec.add_dependency 'simple_flow'
  spec.add_dependency 'tty-screen'
  spec.add_dependency 'tty-spinner'
  spec.add_dependency 'word_wrapper'

  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov_lcov_formatter'
  spec.add_development_dependency 'tocer'
  spec.add_development_dependency 'webmock'


  spec.post_install_message = <<~MSG

    ╔══════════════════════════════════════════════════════════════╗
    ║               AIA — AI Assistant Installed!                  ║
    ╚══════════════════════════════════════════════════════════════╝

    ⚠  Note: v0.10+ has breaking changes in config file format and
       environment variable names. See docs for details.

    ⚠  Prompt files now use .md extension (was .txt).
       Run: aia --migrate-prompts to convert existing prompts.

    Multi-model AI from your command line. 20+ providers supported.

    Quick Start:
      aia --help              Show all options
      aia --chat              Start an interactive chat session
      aia --fuzzy             Select a prompt with fuzzy finder
      aia my_prompt_file      Run saved prompt(s) in batch mode

    Setup:
      1. Set your API key(s):  export OPENAI_API_KEY=your_key
                               export ANTHROPIC_API_KEY=your_key
                               ... etc.
      2. Create prompts dir:   mkdir -p ~/.prompts
      3. Initialize config:    aia --dump ~/.config/aia/aia.yml

    Key Features:
      • Dynamic prompts with YAML front matter and ERB directives
      • Consensus mode: run multiple models, get unified responses
      • Shell & Ruby (ERB) integration in prompts
      • Tool callbacks via RubyLLM::Tool
      • MCP Integration via RubyLLM::MCP
      • Session history and checkpoints
      • Pipeline workflows
      • Concurrently run the same prompt against multiple models
      • Get cost estimates for prompts against multiple models

    Documentation:  https://madbomber.github.io/aia
    Source Code:    https://github.com/MadBomber/aia

  MSG

end
