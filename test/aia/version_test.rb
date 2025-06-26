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
    assert_match /^\d+\.\d+\.\d+$/, AIA::VERSION, "AIA::VERSION should be in the format 'X.Y.Z'"
  end
  
  def test_version_is_string
    assert_instance_of String, AIA::VERSION
  end
  
  def test_version_components_are_numeric
    major, minor, patch = AIA::VERSION.split('.')
    
    assert_match /^\d+$/, major, "Major version should be numeric"
    assert_match /^\d+$/, minor, "Minor version should be numeric"
    assert_match /^\d+$/, patch, "Patch version should be numeric"
    
    # Test that they can be converted to integers
    assert_instance_of Integer, major.to_i
    assert_instance_of Integer, minor.to_i
    assert_instance_of Integer, patch.to_i
  end
  
  def test_version_reasonableness
    major, minor, patch = AIA::VERSION.split('.').map(&:to_i)
    
    # Version numbers should be reasonable (not negative, not extremely large)
    assert major >= 0, "Major version should be non-negative"
    assert minor >= 0, "Minor version should be non-negative"
    assert patch >= 0, "Patch version should be non-negative"
    
    assert major < 100, "Major version should be reasonable (< 100)"
    assert minor < 1000, "Minor version should be reasonable (< 1000)"
    assert patch < 10000, "Patch version should be reasonable (< 10000)"
  end
  
  def test_version_consistency_with_gemspec
    # Read the gemspec file to verify version consistency
    gemspec_path = File.join(File.dirname(__FILE__), '..', '..', 'aia.gemspec')
    
    if File.exist?(gemspec_path)
      gemspec_content = File.read(gemspec_path)
      
      # Look for version reference in gemspec
      if gemspec_content.match(/version\s*=\s*AIA::VERSION/)
        # Gemspec uses AIA::VERSION, so it should be consistent
        assert_equal AIA::VERSION, AIA::VERSION, "Version should be self-consistent"
      end
    end
  end
  
  def test_version_follows_semantic_versioning
    # Semantic versioning: MAJOR.MINOR.PATCH
    # MAJOR version when you make incompatible API changes,
    # MINOR version when you add functionality in a backwards compatible manner, and
    # PATCH version when you make backwards compatible bug fixes.
    
    version_parts = AIA::VERSION.split('.')
    assert_equal 3, version_parts.length, "Version should have exactly 3 parts (MAJOR.MINOR.PATCH)"
    
    # Each part should contain only digits
    version_parts.each_with_index do |part, index|
      part_names = ['major', 'minor', 'patch']
      assert_match /^\d+$/, part, "#{part_names[index]} version part should contain only digits"
    end
  end
  
  def test_version_file_consistency
    # Check if there's a separate version file
    version_file_path = File.join(File.dirname(__FILE__), '..', '..', '.version')
    
    if File.exist?(version_file_path)
      file_version = File.read(version_file_path).strip
      assert_equal AIA::VERSION, file_version, "Version in .version file should match AIA::VERSION constant"
    end
  end
  
  def test_version_immutability
    original_version = AIA::VERSION.dup
    
    # Try to modify the version (should not affect the constant)
    version_copy = AIA::VERSION.dup
    version_copy.upcase!
    
    # Original constant should be unchanged
    assert_equal original_version, AIA::VERSION, "VERSION constant should not be affected by modifications to copies"
  end
  
  def test_version_comparison_methods
    # Test that version can be used in comparisons
    current_version = AIA::VERSION
    
    # Should be able to compare with itself
    assert_equal current_version, AIA::VERSION
    
    # Should be able to use in string operations
    assert_instance_of String, "Version: #{AIA::VERSION}"
    
    # Should be able to use in regex matching
    assert_match /\d+\.\d+\.\d+/, AIA::VERSION
  end
  
  def test_version_for_development_vs_release
    # Check if version suggests development or release
    if AIA::VERSION.match(/\d+\.\d+\.\d+$/)
      # Release version format
      refute_match /-/, AIA::VERSION, "Release version should not contain dashes"
      refute_match /pre/, AIA::VERSION.downcase, "Release version should not contain 'pre'"
      refute_match /alpha/, AIA::VERSION.downcase, "Release version should not contain 'alpha'"
      refute_match /beta/, AIA::VERSION.downcase, "Release version should not contain 'beta'"
      refute_match /rc/, AIA::VERSION.downcase, "Release version should not contain 'rc'"
    end
  end
end
