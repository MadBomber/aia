# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "AI Assistant: dynamic prompts, shell & Ruby integration, and seamless chat workflows."
  spec.description  = <<~DESC
    Unleash the full power of AI from your terminal! AIA is a cutting-edge CLI
    assistant for generative AI workflows, offering dynamic prompt management,
    seamless shell and Ruby integration, interactive chat, and advanced automation.
    Effortlessly craft, manage, and execute prompts with embedded directives,
    history, and flexible configuration. Experience next-level productivity for
    developers, power users, and AI enthusiasts—all from your command line.
  DESC

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

  spec.add_dependency "activesupport"
  spec.add_dependency "amazing_print"
  spec.add_dependency "faraday"
  spec.add_dependency "prompt_manager", '>= 0.5.6'
  spec.add_dependency "ruby_llm", '>= 1.3.1'
  spec.add_dependency "ruby_llm-mcp"
  spec.add_dependency "reline"
  spec.add_dependency "shellwords"
  spec.add_dependency "toml-rb"
  spec.add_dependency "tty-screen"
  spec.add_dependency "tty-spinner"
  spec.add_dependency "versionaire"
  spec.add_dependency "word_wrapper"

  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'tocer'

end
