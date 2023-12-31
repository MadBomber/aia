# aia/test/aia/tools/mods_test.rb

require_relative  '../../test_helper'
require_relative  '../../../lib/aia/tools'
require_relative  '../../../lib/aia/tools/mods'

class TestAIMods < Minitest::Test
  def setup
    AIA::Cli.new("")
    AIA.config.directives = []
    @mods_instance = AIA::Mods.new(text: 'Sample prompt', files: [])
  end


  def test_initialize
    assert_equal 'Sample prompt', @mods_instance.text
    assert_empty @mods_instance.files
  end
  

  def test_sanitize
    unsafe_string = "An 'unsafe' string with \"special\" characters & symbols?"
    sanitized_string = @mods_instance.sanitize(unsafe_string)
    assert_equal "An\\ \\'unsafe\\'\\ string\\ with\\ \\\"special\\\"\\ characters\\ \\&\\ symbols\\?", sanitized_string
  end


  def test_build_command
    expected_start = "mods #{AIA::Mods::DEFAULT_PARAMETERS}"
    assert_match /^#{Regexp.escape(expected_start)}/, @mods_instance.build_command
  end


  def test_set_parameter_from_directives
    AIA.config.directives = [
      ['api', 'https://localhost'],
      ['no-limit', '']
    ]

    assert_includes AIA::Mods::DEFAULT_PARAMETERS, '--no-limit'

    # Test includes default parameters
    how_many = @mods_instance.parameters.scan('--no-limit').length
    assert_equal 1, how_many    

    @mods_instance.set_parameter_from_directives

    assert_includes @mods_instance.parameters, '--api https://localhost'
    
    # test do not add duplicates
    how_many = @mods_instance.parameters.scan('--no-limit').length
    assert_equal 1, how_many
  end


  def test_run_without_files
    @mods_instance.stub :`, 'Mocked command output' do
      result = @mods_instance.run
      assert_equal 'Mocked command output', result
    end
  end


  def test_run_with_one_file
    @mods_instance.files << __FILE__ # use current file as an example
    File.stub :read, 'File content' do
      @mods_instance.stub :`, 'Mocked command output from file' do
        result = @mods_instance.run
        assert_equal 'Mocked command output from file', result
      end
    end
  end
  

  def test_run_with_multiple_files
    skip
    @mods_instance.files = [__FILE__, __FILE__]
    
    @mods_instance.stub :create_temp_file_with_contexts, true do
      @mods_instance.stub :run_mods_with_temp_file, 'Mocked command output from multiple files' do
        result = @mods_instance.run
        assert_equal 'Mocked command output from multiple files', result
      end
    end
  end
  

end

