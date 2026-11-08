# frozen_string_literal: true

require_relative 'lib/aia/version'

Gem::Specification.new do |spec|
  spec.name     = 'aia'
  spec.version  = AIA::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary      = 'Command-line AI assistant: Markdown prompts with directives, ERB and shell, chat with crews of robots, ' \
                      'MCP servers, and any RubyLLM provider including coding-agent CLIs.'
  spec.description  = <<~DESC
    AIA runs large language models from the terminal. Prompts are Markdown files with YAML front matter: parameters
    that AIA asks for, directives such as /include and /shell, ERB and shell expansion, and keys that pick the model,
    temperature or a special mode. Run a prompt once, chain prompts into a pipeline, make a prompt file executable,
    or open an interactive chat with history, checkpoints and skills.

    Every session is a crew of robots built on robot_lab. Name several models to compare them side by side, ask for a
    consensus or a debate, have two independent answers reconciled with /verify, or decompose and delegate work to
    specialists. Robots use RubyLLM tools and MCP servers through ruby_llm 2.1's built-in client, with per-tool
    approval and automatic tool filtering. Any provider RubyLLM registers can be used, local or remote, plus optional
    ruby_llm-providers-* gems that run Claude Code, Codex or GitHub Copilot as models. Requires Ruby 4.0.9 or newer.
  DESC

  spec.homepage     = 'https://github.com/MadBomber/aia'
  spec.license      = 'MIT'

  spec.required_ruby_version = '>= 4.0.9'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['documentation_uri'] = 'https://madbomber.github.io/aia'
  spec.metadata['source_code_uri']  = spec.homepage
  spec.metadata['changelog_uri']    = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Ship only what an installed gem runs: the library, the executable, and
  # the top-level docs. Dev tooling, docs/, examples/ and planning notes
  # stay in the repository.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      (f.start_with?('lib/') && !f.end_with?('AGENTS.md')) || %w[bin/aia README.md CHANGELOG.md LICENSE].include?(f)
    end
  end

  spec.bindir         = 'bin'
  spec.executables    = %w[aia]
  spec.require_paths  = %w[lib]

  # Pin bigdecimal to 4.x — Ruby 4 ships it as a default gem, but some transitive
  # deps declare >= 3.0 which can cause RubyGems to activate 3.x first.
  spec.add_dependency 'bigdecimal',   '>= 4.0'

  # Core dependencies
  spec.add_dependency 'robot_lab',    '~> 0.6'     # Execution engine: robots, networks, tools, MCP, memory
  spec.add_dependency 'myway_config'               # AIA-specific config (CLI settings, prompts, UI)
  spec.add_dependency 'prompt_manager', '~> 1.2'   # Prompt parsing/directive DSL
  spec.add_dependency 'lumberjack', '~> 2.1'       # Structured logging, 3 loggers (aia, llm, mcp); 2.x API (LogFile shift_age/autoflush)
  spec.add_dependency 'activesupport'              # Required by robot_lab (missing from its gemspec)
  spec.add_dependency 'simple_flow'
  spec.add_dependency 'trak_flow'

  # CLI & UI
  spec.add_dependency 'reline'                     # Interactive chat input with history
  spec.add_dependency 'tty-screen'                 # Terminal width detection
  spec.add_dependency 'tty-spinner'                # Loading animation and concurrent MCP connection spinners
  spec.add_dependency 'tty-table',    '~> 0.12'    # Adaptive terminal-width table rendering for metrics
  spec.add_dependency 'classifier',  '~> 2.3'      # TF-IDF similarity (Option A tool filtering)
  spec.add_dependency 'word_wrapper'               # Terminal text wrapping for tool listings
  spec.add_dependency 'amazing_print'              # Config dump formatting (--dump, /config)
  spec.add_dependency 'clipboard'                  # System clipboard access (/paste directive)

  # Utilities
  spec.add_dependency 'faraday'                    # HTTP client for /webpage directive
  spec.add_dependency 'listen'                     # File-watch for live plugin reload (polling fallback if absent)
  spec.add_dependency 'shellwords'                 # Shell escaping

  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'ostruct'                 # OpenStruct test doubles; a bundled gem since Ruby 4.0
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov_lcov_formatter'
  spec.add_development_dependency 'tocer'
  spec.add_development_dependency 'webmock'

  spec.post_install_message = <<~MSG

    ╔══════════════════════════════════════════════════════════════╗
    ║#{"AIA — AI Assistant v#{AIA::VERSION}".center(62)}║
    ║                                                              ║
    ║  Prompts as Markdown, crews of robots, MCP servers, and      ║
    ║  any RubyLLM provider, including coding-agent CLIs.          ║
    ╚══════════════════════════════════════════════════════════════╝

    Get started:  aia --help
    What is new:  https://github.com/MadBomber/aia/blob/main/CHANGELOG.md
    Full docs:    https://madbomber.github.io/aia

  MSG
end
