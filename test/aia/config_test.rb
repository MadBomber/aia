require_relative '../test_helper'

class ConfigTest < Minitest::Test
  def setup
    @default_config = AIA::Config::DEFAULT_CONFIG
  end


  def test_default_config
    config = AIA::Config.parse([])
    @default_config.each do |key, value|
      assert_equal value, config[key], "Expected default value for #{key} to be #{value}"
    end
  end

  def test_parse_command_line_arguments
    args = ['--model', 'custom-model', '--chat']
    config = AIA::Config.parse(args)
    assert_equal 'custom-model', config[:model], "Expected model to be 'custom-model'"
    assert_equal true, config[:chat], "Expected chat to be true"
    assert config.prompt_id.nil? || config.prompt_id.empty?, "Expected prompt_id to be nil or empty"
  end

  def test_parse_environment_variables
    ENV['AIA_MODEL'] = 'env-model'
    config = AIA::Config.parse([])
    assert_equal 'env-model', config.model
  ensure
    ENV.delete('AIA_MODEL')
  end
end
