# frozen_string_literal: true

require_relative "lib/aia/version"

Gem::Specification.new do |spec|
  spec.name     = "aia"
  spec.version  = AIA::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "AI Assistant: dynamic prompts, shell & Ruby integration, and seamless chat workflows."
  spec.description  = <<~DESC
    Unlock the Power of AI Right from Your Terminal!  AIA is a
    revolutionary CLI console application designed for generative AI
    workflows. With AIA, you can effortlessly manage prompts,
    integrate seamlessly with shell and embedded Ruby (ERB), and
    engage in interactive chats, all while harnessing advanced
    automation features.  Experience a new level of productivity with
    dynamic prompt management, tailored directives, and comprehensive
    history tracking. AIA supports callback functions (Tools) and
    model context protocol (MCP) servers, making it the ultimate tool
    for developers, power users, and AI enthusiasts alike.  Transform
    your command line into a powerhouse of creativity and efficiency.
    Elevate your workflow with AIA and unleash the full potential of
    AI at your fingertips!
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
  spec.add_dependency "prompt_manager", '>= 0.5.7'
  spec.add_dependency "ruby_llm",       '>= 1.5.1'
  spec.add_dependency "ruby_llm-mcp",   '>= 0.6.1'
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
