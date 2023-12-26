# test/aia/cli_test.rb
# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/aia/cli'

class CliTest < Minitest::Test
  def setup
    # Arguments could be passed here to initialize the CLI for test scenarios
    @cli = AIA::Cli.new([])
  end


  # Test for `initialize` method
  def test_initialize
    assert_instance_of AIA::Cli, @cli
  end


  # Test `convert_pathname_objects!` method
  def test_convert_pathname_objects!
    # The home path should be mocked to ensure consistency in test environment
    expected = Pathname.new "#{ENV['HOME']}/test.log"
    
    AIA.config.log_file = '~/test.log'
    @cli.convert_pathname_objects!
    
    assert_equal expected, AIA.config.log_file
  end


  # Test `string_to_pathname` method
  def test_string_to_pathname
    expected = Pathname.new "#{ENV['HOME']}/test_path"
    result = @cli.string_to_pathname('~/test_path')

    assert_equal expected, result
  end


  # Test `pathname_to_string` method
  def test_pathname_to_string
    path = Pathname.new('/home/testuser/test_path')
    result = @cli.pathname_to_string(path)

    assert_equal '/home/testuser/test_path', result
  end


  # Test `convert_to_pathname_objects` method
  def test_convert_to_pathname_objects
    expected = Pathname.new "#{ENV['HOME']}/test.log"
    AIA.config.log_file = '~/test.log'
    @cli.convert_to_pathname_objects
    
    assert_equal expected, AIA.config.log_file
  end


  # Test `convert_from_pathname_objects` method
  def test_convert_from_pathname_objects
    expected = "#{ENV['HOME']}/test.log"
    AIA.config.log_file = Pathname.new(expected)
    
    assert AIA.config.log_file.is_a? Pathname

    @cli.convert_from_pathname_objects

    assert AIA.config.log_file.is_a? String
    assert_equal expected, AIA.config.log_file
  end


  # Test `load_env_options` method
  def test_load_env_options
    cli = AIA::Cli.new("")

    ENV['AIA_LOG_FILE'] = '/env/specific.log'
    cli.load_env_options

    assert_equal '/env/specific.log', AIA.config.log_file
  
    # boolean case ...
    assert_equal false, AIA.config.fuzzy?

    ENV['AIA_FUZZY'] = 'yes'
    cli.load_env_options

    assert_equal true, AIA.config.fuzzy?
  end


  # Test `load_config_file` method
  # This test should mock the filesystem operations
  def test_load_config_file
    cli = AIA::Cli.new ""
    assert_equal nil, AIA.config.xyzzy
    AIA.config.config_file = Pathname.new(__dir__) + "config_files/sample_config.yml"
    cli.load_config_file
    assert_equal "magic", AIA.config.xyzzy
  end


  # Test `setup_options_with_defaults` method
  def test_setup_options_with_defaults
    args = ['--model', 'gpt-3']
    AIA::Cli.new(args)
    assert_equal 'gpt-3', AIA.config.model
  end


  # Test `execute_immediate_commands` behavior
  def test_execute_immediate_commands
    @cli = AIA::Cli.new("")
    
    AIA.config[:help?] = true

    assert_raises(SystemExit) do
      @cli.execute_immediate_commands 
    end
  end


  # Test `dump_config_file` method
  def test_dump_config_file
    @cli = AIA::Cli.new("")
    
    AIA.config.dump   = "yml"
    AIA.config.model  = "magic"

    output = capture_io do
      assert_raises(SystemExit) do
        @cli.dump_config_file 
      end
    end
    
    assert_includes output.first, 'model: magic'
  end


  # Test `prepare_config_as_hash` method
  def test_prepare_config_as_hash
    cli = AIA::Cli.new("")
    result = cli.prepare_config_as_hash
    assert result.is_a?(Hash)
  end


  # Test `process_command_line_arguments` method
  def test_process_command_line_arguments
    args = ['--unknown-option']
    assert_raises(SystemExit) do
      AIA::Cli.new(args)
    end
  end


  # Test `check_for` method
  def test_check_for
    cli = AIA::Cli.new("")
    AIA.config.arguments = %w[--verbose --backend sgpt]
    assert_equal false, AIA.config.verbose?
    assert_equal "mods", AIA.config.backend

    cli.check_for :backend
    assert_equal "sgpt", AIA.config.backend
    assert_equal ["--verbose"], AIA.config.arguments

    cli.check_for :verbose?
    assert_equal true, AIA.config.verbose?
    assert AIA.config.arguments.empty?
  end


  # Test `show_usage` and aliases behavior
  def test_show_usage
    @cli = AIA::Cli.new("")

    output = capture_io do
      assert_raises(SystemExit) do
        @cli.show_usage 
      end
    end
    
    first_line = output.first.split("\n").first

    assert_includes first_line, 'User Manuals'
  end


  # Test `show_completion` behavior
  def test_show_completion  
    @cli = AIA::Cli.new("")
    AIA.config.completion = "bash"

    output = capture_io do
      assert_raises(SystemExit) do
        @cli.show_completion
      end
    end

    assert_includes output.first, 'aia_completion.bash'
  end


  # Test `show_version` behavior
  def test_show_version
    @cli = AIA::Cli.new("")
    AIA.config.completion = "bash"

    output = capture_io do
      assert_raises(SystemExit) do
        @cli.show_version
      end
    end
    
    first_line = output.first.split("\n").first

    assert_includes first_line, AIA::VERSION
  end


  # Test `setup_prompt_manager` method
  def test_setup_prompt_manager
    AIA::Cli.new("")
    assert PromptManager::Prompt.storage_adapter.is_a?(PromptManager::Storage::FileSystemAdapter)
  end


  # Test `extract_extra_options` method
  def test_extract_extra_options
    AIA::Cli.new('arg1 -- extra-flag')
    
    assert_equal 'arg1', AIA.config.arguments[-1]
    assert_equal 1, AIA.config.arguments.size

    assert_equal 'extra-flag', AIA.config.extra
  end


  # Test `parse_config_file` method
  def test_parse_config_file
    # setup
    config_dir = Pathname.new(__dir__) + 'config_files'

    @yml_config_file  = config_dir + 'sample_config.yml'
    @yaml_config_file = config_dir + 'sample_config.yaml'
    @toml_config_file = config_dir + 'sample_config.toml'
    @json_config_file = config_dir + 'sample_config.json'

    @cli = AIA::Cli.new('')

    assert_raises(SystemExit) do
      AIA.config.config_file = @json_config_file
      @cli.parse_config_file
    end

    # test_parse_yml_config
    [
      @yml_config_file,
      @yaml_config_file
    ].each do |config_file|
      AIA.config.config_file = config_file
      assert_equal YAML.safe_load(config_file.read), @cli.parse_config_file
    end

    
    # test_parse_toml_config
    AIA.config.config_file = @toml_config_file
    assert_equal TomlRB.parse(@toml_config_file.read), @cli.parse_config_file
  
  
    # test_parse_json_config
    AIA.config.config_file = @json_config_file
    
    # output = capture_io { @cli.parse_config_file }
    # assert_includes output.first, 'Unsupported config file type: .json'
  end
end
