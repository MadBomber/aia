# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "AI Assistant (aia) a command-ling utility"
  spec.description  = <<~EOS
    A command-line AI Assistante (aia) that provides
    parameterized prompt management (via the prompt_manager gem) to
    various backend gen-AI processes.  Currently supports the `mods`
    CLI tool.  `aia`uses `ripgrep` and `fzf` command-line utilities 
    to search for and select prompt files to send to the backend gen-AI
    tool along with supported context files.
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
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir         = "bin"
  spec.executables    = %w[ aia aia_completion.sh ]
  spec.require_paths  = %w[ lib ]

  spec.add_dependency "prompt_manager"
  spec.add_dependency "word_wrap"

  spec.add_development_dependency 'amazing_print'
  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency "minitest"
  spec.add_development_dependency 'tocer'
end
