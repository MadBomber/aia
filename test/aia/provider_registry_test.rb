# frozen_string_literal: true

# test/aia/provider_registry_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class ProviderRegistryTest < Minitest::Test
  # Records which fake provider gem file was required during a sideload test.
  module Sideloaded
    class << self
      attr_accessor :slug
    end
  end

  def test_slugs_returns_registered_provider_slugs_as_strings
    slugs = AIA::ProviderRegistry.slugs

    assert_kind_of Array, slugs
    assert_includes slugs, 'openai'
    assert_includes slugs, 'anthropic'
    assert slugs.all?(String)
  end

  def test_missing_config_hint_names_the_env_vars_robot_lab_reads_for_vertexai
    error = RubyLLM::ConfigurationError.new(<<~MSG)
      VertexAI provider is not configured. Add this to your initialization:

      RubyLLM.configure do |config|
        config.vertexai_project_id = ENV['VERTEXAI_PROJECT_ID']
        config.vertexai_location = ENV['VERTEXAI_LOCATION']
      end
    MSG

    assert_equal 'VertexAI is not configured: set GOOGLE_CLOUD_PROJECT and GOOGLE_CLOUD_LOCATION',
                 AIA::ProviderRegistry.missing_config_hint(error)
  end

  def test_missing_config_hint_is_nil_for_other_configuration_errors
    error = RubyLLM::ConfigurationError.new('azure_deployments must be a Hash')

    assert_nil AIA::ProviderRegistry.missing_config_hint(error)
  end

  def test_registered_for_builtin_provider
    assert AIA::ProviderRegistry.registered?('openai')
    assert AIA::ProviderRegistry.registered?(:anthropic)
  end

  def test_registered_is_false_for_unknown_and_nil
    refute AIA::ProviderRegistry.registered?('notaprovider')
    refute AIA::ProviderRegistry.registered?(nil)
  end

  def test_available_is_true_for_registered_provider
    assert AIA::ProviderRegistry.available?('openai')
  end

  def test_available_is_false_for_unloadable_slug
    refute AIA::ProviderRegistry.available?('notaprovider')
  end

  def test_load_rejects_slugs_with_unsafe_characters
    refute AIA::ProviderRegistry.load('../etc/passwd')
    refute AIA::ProviderRegistry.load('Not-A-Slug')
    refute AIA::ProviderRegistry.load('')
  end

  def test_load_registers_conventional_provider_gem_on_demand
    skip 'ruby_llm-providers-lms gem not in this bundle' unless AIA::ProviderRegistry.load('lms')

    assert AIA::ProviderRegistry.registered?('lms')
  end

  # --- sideloading installed gems the bundle hides ---

  # A fake installed gem: a gemspec under specifications/ and a lib file that
  # records that it was required. It never registers with RubyLLM, so the
  # real registry is left untouched.
  def with_fake_installed_gem(slug, dependency: ['ruby_llm', '>= 2.1'])
    require 'tmpdir'
    Dir.mktmpdir('aia_gem_path') do |dir|
      name = "ruby_llm-providers-#{slug}"
      FileUtils.mkdir_p(File.join(dir, 'specifications'))
      lib = File.join(dir, 'gems', "#{name}-0.1.0", 'lib', 'ruby_llm', 'providers')
      FileUtils.mkdir_p(lib)
      File.write(File.join(lib, "#{slug}.rb"), "ProviderRegistryTest::Sideloaded.slug = #{slug.inspect}\n")
      File.write(File.join(dir, 'specifications', "#{name}-0.1.0.gemspec"), <<~SPEC)
        Gem::Specification.new do |s|
          s.name = #{name.inspect}
          s.version = '0.1.0'
          s.summary = 'fake provider gem for tests'
          s.authors = ['aia tests']
          s.add_runtime_dependency #{dependency[0].inspect}, #{dependency[1].inspect}
        end
      SPEC
      Gem.stubs(:path).returns([dir])
      Sideloaded.slug = nil
      yield
    end
  ensure
    Sideloaded.slug = nil
  end

  def test_installed_spec_reads_gemspecs_from_the_gem_path
    with_fake_installed_gem('fakeprov') do
      spec = AIA::ProviderRegistry.installed_spec('fakeprov')

      assert_equal 'ruby_llm-providers-fakeprov', spec.name
      assert_equal Gem::Version.new('0.1.0'), spec.version
    end
  end

  def test_installed_spec_is_nil_when_nothing_is_installed
    Gem.stubs(:path).returns([Dir.tmpdir])

    assert_nil AIA::ProviderRegistry.installed_spec('nothing_here_xyz')
  end

  def test_sideload_requires_an_installed_gem_the_bundle_hides
    with_fake_installed_gem('fakeprov') do
      AIA::ProviderRegistry.sideload('fakeprov')

      assert_equal 'fakeprov', Sideloaded.slug
    end
  end

  def test_sideload_skips_a_gem_whose_dependencies_the_bundle_cannot_satisfy
    with_fake_installed_gem('fakeprov', dependency: ['ruby_llm', '>= 99']) do
      AIA.expects(:debug_warn).with(regexp_matches(/ruby_llm-providers-fakeprov-0.1.0 is installed but needs ruby_llm/)).once

      refute AIA::ProviderRegistry.sideload('fakeprov')
      assert_nil Sideloaded.slug
    end
  end

  def test_sideload_is_false_when_nothing_is_installed
    Gem.stubs(:path).returns([Dir.tmpdir])

    refute AIA::ProviderRegistry.sideload('nothing_here_xyz')
  end

  def test_dependency_met_checks_active_gems
    met   = Gem::Dependency.new('ruby_llm', '>= 2.1')
    unmet = Gem::Dependency.new('ruby_llm', '>= 99')
    absent = Gem::Dependency.new('no_such_gem_xyz', '>= 0')

    assert AIA::ProviderRegistry.dependency_met?(met)
    refute AIA::ProviderRegistry.dependency_met?(unmet)
    refute AIA::ProviderRegistry.dependency_met?(absent)
  end

  def test_installed_gem_slugs_includes_gems_outside_the_bundle
    with_fake_installed_gem('fakeprov') do
      assert_includes AIA::ProviderRegistry.installed_gem_slugs, 'fakeprov'
    end
  end

  def test_instantiate_raises_for_unknown_provider
    assert_raises(RubyLLM::Error) { AIA::ProviderRegistry.instantiate('notaprovider') }
  end

  def test_apply_env_endpoints_sets_base_from_env_for_registered_provider
    original = RubyLLM.config.ollama_api_base
    original_env = ENV.fetch('OLLAMA_API_BASE', nil)
    ENV['OLLAMA_API_BASE'] = 'http://env.test:11434/v1'

    AIA::ProviderRegistry.apply_env_endpoints

    assert_equal 'http://env.test:11434/v1', RubyLLM.config.ollama_api_base
  ensure
    ENV['OLLAMA_API_BASE'] = original_env
    RubyLLM.config.ollama_api_base = original
  end

  def test_apply_env_endpoints_defaults_ollama_when_unset
    original = RubyLLM.config.ollama_api_base
    original_env = ENV.fetch('OLLAMA_API_BASE', nil)
    ENV.delete('OLLAMA_API_BASE')

    AIA::ProviderRegistry.apply_env_endpoints

    if original.nil?
      assert_equal "http://localhost:11434/v1", RubyLLM.config.ollama_api_base
    else
      assert_equal original, RubyLLM.config.ollama_api_base
    end
  ensure
    ENV['OLLAMA_API_BASE'] = original_env
    RubyLLM.config.ollama_api_base = original
  end
end
