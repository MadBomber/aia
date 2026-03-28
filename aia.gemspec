# frozen_string_literal: true

require_relative 'lib/aia/version'

Gem::Specification.new do |spec|
  spec.name     = 'aia'
  spec.version  = AIA::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary      = 'Multi-model AI CLI with dynamic prompts, consensus responses, shell & Ruby integration, and seamless chat workflows.'
  spec.description  = <<~DESC
    AIA is a powerful CLI console application that brings multi-model AI capabilities to your command line, supporting 20+ providers including OpenAI, Anthropic, and Google. Built on robot_lab for robust robot orchestration and kbs for intelligent rule-based routing, AIA v2 provides a thin CLI shell over a rich execution engine. Run multiple AI models simultaneously for comparison, get consensus responses from collaborative AI teams, or compare individual outputs side-by-side. With dynamic prompt management, embedded directives, shell and Ruby integration, interactive chats, and comprehensive history tracking, AIA transforms how you interact with AI.
  DESC

  spec.homepage     = 'https://github.com/MadBomber/aia'
  spec.license      = 'MIT'

  spec.required_ruby_version = '>= 4.0.0'

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

  # Core dependencies
  spec.add_dependency 'robot_lab',    '~> 0.0.9'              # Execution engine: robots, networks, tools, MCP, memory
  spec.add_dependency 'kbs',          '~> 0.2.1'              # RETE rule engine for intelligent routing
  spec.add_dependency 'myway_config'               # AIA-specific config (CLI settings, prompts, UI)
  spec.add_dependency 'lumberjack'                 # Structured logging with 3 loggers (aia, llm, mcp)
  spec.add_dependency 'activesupport'              # Required by robot_lab (missing from its gemspec)
  spec.add_dependency 'simple_flow'
  spec.add_dependency 'trak_flow'

  # CLI & UI
  spec.add_dependency 'reline'                     # Interactive chat input with history
  spec.add_dependency 'tty-screen'                 # Terminal width detection
  spec.add_dependency 'tty-spinner'                # Loading animation and concurrent MCP connection spinners
  spec.add_dependency 'tty-table',    '~> 0.12'   # Adaptive terminal-width table rendering for metrics
  spec.add_dependency 'classifier',  '~> 2.3'     # TF-IDF similarity, Bayes classification, LSI semantic search
  spec.add_dependency 'zvec'                       # Embedded vector database for semantic tool search (Option C)
  spec.add_dependency 'sqlite-vec'                 # SQLite-vec extension for semantic tool search (Option D)
  spec.add_dependency 'informers'                  # ONNX-based text embeddings for semantic search
  spec.add_dependency 'word_wrapper'               # Terminal text wrapping for tool listings
  spec.add_dependency 'amazing_print'              # Config dump formatting (--dump, /config)
  spec.add_dependency 'clipboard'                  # System clipboard access (/paste directive)

  # Utilities
  spec.add_dependency 'faraday'                    # HTTP client for /webpage directive
  spec.add_dependency 'shellwords'                 # Shell escaping

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
    ║               AIA — AI Assistant v2.0                        ║
    ║                                                              ║
    ║  v2 is powered by robot_lab + kbs for robust orchestration   ║
    ║  Full CLI backward compatibility with v1                     ║
    ╚══════════════════════════════════════════════════════════════╝

    Get started:  aia --help
    Full docs:    https://madbomber.github.io/aia

  MSG

end
