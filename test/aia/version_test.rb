require_relative '../test_helper'
require_relative '../../lib/aia'

class VersionTest < Minitest::Test
  def test_version_is_defined
    assert AIA::VERSION, "AIA::VERSION should be defined"
    refute_nil AIA::VERSION
    refute_empty AIA::VERSION
  end

  def test_version_format
    assert_match(/^\d+\.\d+\.\d+/, AIA::VERSION, "AIA::VERSION should start with 'X.Y.Z'")
  end

  def test_version_is_string
    assert_instance_of String, AIA::VERSION
  end

  def test_version_components_are_numeric
    parts = AIA::VERSION.split('.')
    major = parts[0]
    minor = parts[1]
    # Patch may have pre-release suffix like "0-alpha"
    patch = parts[2].split('-').first

    assert_match(/^\d+$/, major, "Major version should be numeric")
    assert_match(/^\d+$/, minor, "Minor version should be numeric")
    assert_match(/^\d+$/, patch, "Patch version should be numeric")

    assert_instance_of Integer, major.to_i
    assert_instance_of Integer, minor.to_i
    assert_instance_of Integer, patch.to_i
  end

  def test_version_reasonableness
    major, minor, patch = AIA::VERSION.split('.').map(&:to_i)

    assert major >= 0, "Major version should be non-negative"
    assert minor >= 0, "Minor version should be non-negative"
    assert patch >= 0, "Patch version should be non-negative"

    assert major < 100, "Major version should be reasonable (< 100)"
    assert minor < 1000, "Minor version should be reasonable (< 1000)"
    assert patch < 10_000, "Patch version should be reasonable (< 10000)"
  end

  def test_version_consistency_with_gemspec
    spec = Gem::Specification.load(File.expand_path('../../aia.gemspec', __dir__))
    assert_equal AIA::VERSION, spec.version.to_s, "gemspec version should match AIA::VERSION"
  end

  # robot_lab 0.5 is the first with ruby_llm 2.1's RubyLLM::MCP servers (mcp:);
  # 0.5.1 accepts a String OAuth grant from YAML. 0.6.0 is the floor: it
  # instantiates RubyLLM::Tool classes in local_tools: (so --require'd tool
  # classes such as shared_tools' pass name allowlists), accepts MCP server
  # classes by constant name, and scores class-level server descriptions.
  def test_gemspec_requires_robot_lab_0_6_0
    gemspec_path = File.expand_path('../../aia.gemspec', __dir__)
    spec = Gem::Specification.load(gemspec_path)
    dependency = spec.runtime_dependencies.find { |dep| dep.name == 'robot_lab' }

    refute_nil dependency, "robot_lab should be a runtime dependency"
    requirement = dependency.requirement
    assert requirement.satisfied_by?(Gem::Version.new('0.6.0')), "robot_lab dependency should allow v0.6.0"
    assert requirement.satisfied_by?(Gem::Version.new('0.9.0')), "robot_lab dependency should allow later 0.x"
    refute requirement.satisfied_by?(Gem::Version.new('0.5.1')), "robot_lab dependency should exclude v0.5.1"
    refute requirement.satisfied_by?(Gem::Version.new('1.0.0')), "robot_lab dependency should exclude v1.0"
  end

  def test_version_follows_semantic_versioning
    assert_match(/^\d+\.\d+\.\d+/, AIA::VERSION, "Version should start with MAJOR.MINOR.PATCH")

    parts = AIA::VERSION.split('.')
    assert parts.length >= 3, "Version should have at least 3 dot-separated parts"

    assert_match(/^\d+$/, parts[0], "major version part should contain only digits")
    assert_match(/^\d+$/, parts[1], "minor version part should contain only digits")
    assert_match(/^\d+/, parts[2], "patch version part should start with digits")
  end

  # Release tooling (asgard's gem_version) reads the VERSION string literal
  # straight from version.rb without loading it, so it must stay a literal.
  def test_version_is_a_string_literal_in_version_rb
    source  = File.read(File.expand_path('../../lib/aia/version.rb', __dir__))
    literal = source[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1]

    assert_equal AIA::VERSION, literal, "lib/aia/version.rb should define VERSION as a string literal"
  end

  def test_version_immutability
    original_version = AIA::VERSION.dup

    version_copy = AIA::VERSION.dup
    version_copy.upcase!

    assert_equal original_version, AIA::VERSION, "VERSION constant should not be affected by modifications to copies"
  end

  def test_version_comparison_methods
    current_version = AIA::VERSION

    assert_equal current_version, AIA::VERSION

    assert_instance_of String, "Version: #{AIA::VERSION}"

    assert_match(/\d+\.\d+\.\d+/, AIA::VERSION)
  end

  def test_version_for_development_vs_release
    return unless AIA::VERSION.match(/\d+\.\d+\.\d+$/)
    refute_match(/-/, AIA::VERSION, "Release version should not contain dashes")
    refute_match(/pre/, AIA::VERSION.downcase, "Release version should not contain 'pre'")
    refute_match(/alpha/, AIA::VERSION.downcase, "Release version should not contain 'alpha'")
    refute_match(/beta/, AIA::VERSION.downcase, "Release version should not contain 'beta'")
    refute_match(/rc/, AIA::VERSION.downcase, "Release version should not contain 'rc'")
  end
end
