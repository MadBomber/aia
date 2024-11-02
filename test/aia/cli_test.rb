# test/aia/cli_test.rb

require_relative '../test_helper'

require_relative '../test_helper'

class AIA::CliTest < Minitest::Test
  def setup
    # Initialize `@cli` before each test
    @args = "arg1 arg2"  # You can modify this based on your requirements
    @cli = AIA::Cli.new(@args)
  end

  def test_initialize_with_string_args
    assert_instance_of AIA::Cli, @cli
  end

  def test_load_env_options
    ENV['AIA_CONFIG_FILE'] = 'test_config.yml'
    assert_equal 'test_config.yml', AIA.config.config_file
  end

  def test_error_on_invalid_option_combinations_chat
    AIA.config.chat = true
    AIA.config.next = ['next_prompt']
    assert_raises(SystemExit) { @cli.error_on_invalid_option_combinations }

    AIA.config.next.clear
    AIA.config.out_file = 'output.txt'
    assert_raises(SystemExit) { @cli.error_on_invalid_option_combinations }

    AIA.config.pipeline = ['pipeline1']
    assert_raises(SystemExit) { @cli.error_on_invalid_option_combinations }
  end

  def test_string_to_pathname
    result = @cli.string_to_pathname("~/test/path")
    assert_instance_of Pathname, result
    assert_equal (HOME + 'test/path').to_s, result.to_s
  end

  def test_load_config_file
    AIA.config.config_file = 'test_config.yml'
    File.write('test_config.yml', "key: value\n")
    @cli.load_config_file
    assert_equal 'value', AIA.config[:key]
  ensure
    File.delete('test_config.yml') if File.exist?('test_config.yml')
  end

  def test_dump_config_file
    AIA.config.dump_file = 'test_dump.yml'
    AIA.config[:key] = 'value'
    @cli.dump_config_file
    assert File.exist?('test_dump.yml')
    assert_match /key: value/, File.read('test_dump.yml')
  ensure
    File.delete('test_dump.yml') if File.exist?('test_dump.yml')
  end

  def test_show_usage
    assert_output(/Usage: aia/) { @cli.show_usage }
  end

  def test_show_version
    assert_output(/#{AIA::VERSION}/) { @cli.show_version }
  end

  def test_invoke_fzf_to_choose_role
    AIA.config.roles_dir = 'test_roles'
    Dir.mkdir(AIA.config.roles_dir) unless Dir.exist?(AIA.config.roles_dir)
    File.write("#{AIA.config.roles_dir}/role1.txt", "Role 1 content")

    fzf = Minitest::Mock.new
    fzf.expect(:run, 'role1')
    AIA::Fzf.stub(:new, fzf) do
      @cli.invoke_fzf_to_choose_role
      assert_equal 'role1', AIA.config.role
    end
  ensure
    File.delete("#{AIA.config.roles_dir}/role1.txt")
    Dir.rmdir(AIA.config.roles_dir) if Dir.exist?(AIA.config.roles_dir)
  end

  def teardown
    ENV.delete('AIA_CONFIG_FILE')
  end
end
