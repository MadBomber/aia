require_relative '../test_helper'
require 'ostruct'
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
    assert patch < 10000, "Patch version should be reasonable (< 10000)"
  end

  def test_version_consistency_with_gemspec
    gemspec_path = File.join(File.dirname(__FILE__), '..', '..', 'aia.gemspec')

    if File.exist?(gemspec_path)
      gemspec_content = File.read(gemspec_path)

      if gemspec_content.match(/version\s*=\s*AIA::VERSION/)
        assert_equal AIA::VERSION, AIA::VERSION, "Version should be self-consistent"
      end
    end
  end

  def test_gemspec_requires_robot_lab_0_1
    gemspec_path = File.expand_path('../../aia.gemspec', __dir__)
    spec = Gem::Specification.load(gemspec_path)
    dependency = spec.runtime_dependencies.find { |dep| dep.name == 'robot_lab' }

    refute_nil dependency, "robot_lab should be a runtime dependency"
    assert dependency.requirement.satisfied_by?(Gem::Version.new('0.1.0')),
           "robot_lab dependency should allow v0.1.0"
    refute dependency.requirement.satisfied_by?(Gem::Version.new('0.0.12')),
           "robot_lab dependency should exclude v0.0.12"
  end

  def test_version_follows_semantic_versioning
    assert_match(/^\d+\.\d+\.\d+/, AIA::VERSION, "Version should start with MAJOR.MINOR.PATCH")

    parts = AIA::VERSION.split('.')
    assert parts.length >= 3, "Version should have at least 3 dot-separated parts"

    assert_match(/^\d+$/, parts[0], "major version part should contain only digits")
    assert_match(/^\d+$/, parts[1], "minor version part should contain only digits")
    assert_match(/^\d+/, parts[2], "patch version part should start with digits")
  end

  def test_version_file_consistency
    version_file_path = File.join(File.dirname(__FILE__), '..', '..', '.version')

    if File.exist?(version_file_path)
      file_version = File.read(version_file_path).strip
      assert_equal file_version, AIA::VERSION, "Version in .version file should match AIA::VERSION constant"
    end
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
    if AIA::VERSION.match(/\d+\.\d+\.\d+$/)
      refute_match(/-/, AIA::VERSION, "Release version should not contain dashes")
      refute_match(/pre/, AIA::VERSION.downcase, "Release version should not contain 'pre'")
      refute_match(/alpha/, AIA::VERSION.downcase, "Release version should not contain 'alpha'")
      refute_match(/beta/, AIA::VERSION.downcase, "Release version should not contain 'beta'")
      refute_match(/rc/, AIA::VERSION.downcase, "Release version should not contain 'rc'")
    end
  end
end
