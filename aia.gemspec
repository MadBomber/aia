# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "Multi-model AI CLI with dynamic prompts, consensus responses, shell & Ruby integration, and seamless chat workflows."
  spec.description  = <<~DESC
    AIA is a revolutionary CLI console application that brings multi-model AI capabilities to your command line, supporting 20+ providers including OpenAI, Anthropic, and Google. Run multiple AI models simultaneously for comparison, get consensus responses from collaborative AI teams, or compare individual outputs side-by-side. With dynamic prompt management, embedded directives, shell and Ruby integration, interactive chats, and comprehensive history tracking, AIA transforms how you interact with AI. Perfect for developers and AI enthusiasts who want to harness the collective intelligence of multiple AI models from a single, powerful interface.
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

  # spec.add_dependency "activesupport"
  spec.add_dependency "anyway_config", '~> 2.6'
  spec.add_dependency "amazing_print"
  spec.add_dependency "async"
  spec.add_dependency "clipboard"
  spec.add_dependency "simple_flow"
  spec.add_dependency "lumberjack"
  spec.add_dependency "faraday"
  spec.add_dependency "prompt_manager"
  spec.add_dependency "ruby_llm"
  spec.add_dependency "ruby_llm-mcp"
  spec.add_dependency "reline"
  spec.add_dependency "shellwords"
  spec.add_dependency "tty-screen"
  spec.add_dependency "tty-spinner"
  spec.add_dependency "word_wrapper"

  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov_lcov_formatter'
  spec.add_development_dependency 'tocer'
  spec.add_development_dependency 'webmock'

end
