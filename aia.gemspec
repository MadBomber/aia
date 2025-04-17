# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "AI Assistant (aia) a command-line (CLI) utility"
  spec.description  = <<~EOS.split("\n").map(&:strip).join(' ')
    A command-line AI Assistante (aia) that provides pre-compositional
    template prompt management to various backend gen-AI processes such
    as llm, mods and sgpt support processing of prompts both via remote
    API calls as well as keeping everything local through the use of locally
    managed models and the LocalAI API.
    Complete shell integration allows a prompt to access system
    environment variables and execut shell commands as part of the
    prompt content.  In addition full embedded Ruby support is provided
    given even more dynamic prompt conditional content.  It is a
    generalized power house that rivals specialized gen-AI tools.  aia
    currently supports "mods" and "sgpt" CLI tools.  aia uses "ripgrep"
    and "fzf" CLI utilities to search for and select prompt files to
    send to the backend gen-AI tool along with supported context
    files.
  EOS

  spec.homepage     = "https://github.com/MadBomber/aia"
  spec.license      = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]     = spec.homepage
  spec.metadata["source_code_uri"]  = spec.homepage
  spec.metadata["changelog_uri"]    = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git Gemfile])
    end + ['.version']
  end

  spec.bindir         = "bin"
  spec.executables    = %w[ aia ]
  spec.require_paths  = %w[ lib ]

  spec.add_dependency "ai_client"
  spec.add_dependency "amazing_print"
  spec.add_dependency "os"
  spec.add_dependency "prompt_manager", '>= 0.4.1' # needs the directives functionality
  spec.add_dependency "reline"
  spec.add_dependency "shellwords"
  spec.add_dependency "toml-rb"
  spec.add_dependency "tty-screen"
  spec.add_dependency "tty-spinner"
  spec.add_dependency "versionaire"

  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'tocer'

end
