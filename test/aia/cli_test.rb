# test/aia/cli_test.rb

require 'test_helper'
require 'tempfile'

class AIA::CliTest < Minitest::Test
  def setup
    @args = ["arg1", "arg2"]  # Changed from string to array
    @cli = AIA::Cli.new(@args)
  end

  def test_dump_config_file
    temp_file = Tempfile.new(['test_config', '.yml'])
    begin
      AIA.config = AIA::Config.new
      AIA.config.dump_file = temp_file.path
      AIA.config[:test_key] = 'test_value'
      
      output = capture_io do
        assert_raises(SystemExit) { @cli.dump_config_file }
      end
      
      assert File.exist?(temp_file.path)
      config_content = YAML.load_file(temp_file.path)
      assert_kind_of Hash, config_content
      assert_equal 'test_value', config_content['test_key']
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def test_initialize_with_string_args
    assert_instance_of AIA::Cli, @cli
    refute_nil AIA.config
    assert_equal @args, AIA.config.arguments
  end

  def test_load_env_options
    ENV['AIA_CONFIG_FILE'] = 'test_config.yml'
    @cli.load_env_options
    assert_equal 'test_config.yml', AIA.config.config_file
  ensure
    ENV.delete('AIA_CONFIG_FILE')
  end

  def test_error_on_invalid_option_combinations_chat
    AIA.config.chat = true
    
    # Test chat with next
    AIA.config.next = ['next_prompt']
    assert_raises(SystemExit) do
      capture_io { @cli.error_on_invalid_option_combinations }
    end

    # Test chat with out_file
    AIA.config.next = nil
    AIA.config.out_file = 'output.txt'
    assert_raises(SystemExit) do
      capture_io { @cli.error_on_invalid_option_combinations }
    end

    # Test chat with pipeline
    AIA.config.out_file = nil
    AIA.config.pipeline = ['pipeline1']
    assert_raises(SystemExit) do
      capture_io { @cli.error_on_invalid_option_combinations }
    end
  end

  def test_string_to_pathname
    result = @cli.string_to_pathname("~/test/path")
    assert_instance_of Pathname, result
    assert_equal (HOME + 'test/path').to_s, result.to_s
  end

  def test_load_config_file
    temp_file = Tempfile.new(['test_config', '.yml'])
    begin
      File.write(temp_file.path, "key: value\n")
      AIA.config.config_file = temp_file.path
      @cli.load_config_file
      assert_equal 'value', AIA.config[:key]
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def test_show_usage
    output = capture_io { assert_raises(SystemExit) { @cli.show_usage } }
    assert_match /aia.*command-line interface/m, output.join
  end

  def test_show_version
    output = capture_io { assert_raises(SystemExit) { @cli.show_version } }
    assert_match /#{AIA::VERSION}/, output.join
  end

  def test_invoke_fzf_to_choose_role
    roles_dir = Pathname.new('test_roles')
    roles_dir.mkdir unless roles_dir.exist?
    role_file = roles_dir + 'role1.txt'
    File.write(role_file, "Role 1 content")

    AIA.config.roles_dir = roles_dir.to_s  # Convert to string

    fzf = Minitest::Mock.new
    fzf.expect(:run, 'role1')
    AIA::Fzf.stub(:new, fzf) do
      @cli.invoke_fzf_to_choose_role
      assert_equal 'role1', AIA.config.role
    end
  ensure
    role_file.unlink if role_file&.exist?
    roles_dir.rmdir if roles_dir&.exist?
  end
end
