# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "AI Assistant (aia) a command-line (CLI) utility"
  spec.description  = <<~EOS
    A command-line AI Assistante (aia) that provides
    parameterized prompt management (via the prompt_manager gem) to
    various backend gen-AI processes.  aia currently supports the "mods"
    CLI tool.  aia uses "ripgrep" and "fzf" CLI utilities 
    to search for and select prompt files to send to the backend gen-AI
    tool along with supported context files.  Example usage: "aia refactor my_class.rb" 
    where "refactor" is the prompt ID for the file "refactor.txt" from your
    RPROMPTS_DIR
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
    end + ['man/', '.semver']
  end

  spec.bindir         = "bin"
  spec.executables    = %w[ aia ]
  spec.require_paths  = %w[ lib ]

  spec.add_dependency "hashie"
  spec.add_dependency "prompt_manager", '>= 0.4.1' # needs the directives functionality
  spec.add_dependency "reline"
  spec.add_dependency "semver2"
  spec.add_dependency "shellwords"
  spec.add_dependency "toml-rb"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency 'amazing_print'
  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'kramdown-man'
  spec.add_development_dependency 'tocer'
end
