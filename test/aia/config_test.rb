require_relative '../test_helper'
require 'ostruct'
require 'tempfile'
require 'yaml'
require 'toml-rb'
require_relative '../../lib/aia'

class ConfigTest < Minitest::Test
  def setup
    @default_config = AIA::Config::DEFAULT_CONFIG
    # Store original ARGV to restore later
    @original_argv = ARGV.dup
    ARGV.clear
    
    # Mock AIA module methods to prevent undefined method errors
    AIA.stubs(:bad_file?).returns(true)
    AIA.stubs(:good_file?).returns(false)
    
    # Create a temporary prompts directory for testing
    @temp_prompts_dir = Dir.mktmpdir('aia_test_prompts')
  end

  def teardown
    # Restore original ARGV
    ARGV.clear
    ARGV.concat(@original_argv)
    
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_prompts_dir) if @temp_prompts_dir && Dir.exist?(@temp_prompts_dir)
  end

  # Test DEFAULT_CONFIG structure
  def test_default_config_has_required_keys
    required_keys = [:adapter, :prompts_dir, :model, :temperature, :tools, :chat, :debug]
    
    required_keys.each do |key|
      assert @default_config.respond_to?(key), "DEFAULT_CONFIG missing required key: #{key}"
    end
  end

  def test_default_config_tools_is_string
    assert_equal '', @default_config.tools
    assert_instance_of String, @default_config.tools
  end

  # Test main setup method
  def test_setup_creates_valid_config
    # Mock ARGV to avoid requiring actual prompt files
    ARGV.replace(['--chat'])
    
    config = AIA::Config.setup
    
    assert_instance_of OpenStruct, config
    assert config.respond_to?(:chat)
    assert config.respond_to?(:model)
    assert config.respond_to?(:tools)
  end

  # Test cli_options and extracted helper methods
  def test_cli_options_returns_openstruct
    ARGV.replace(['--chat'])
    
    config = AIA::Config.cli_options
    
    assert_instance_of OpenStruct, config
  end

  def test_create_option_parser_creates_parser
    config = OpenStruct.new
    parser = AIA::Config.create_option_parser(config)
    
    assert_instance_of OptionParser, parser
    assert_match(/Usage:/, parser.banner)
  end

  def test_setup_mode_options_configures_chat
    config = OpenStruct.new
    opts = OptionParser.new
    
    AIA::Config.setup_mode_options(opts, config)
    
    # Test that the option was added by parsing arguments
    opts.parse(['--chat'])
    assert_equal true, config.chat
  end

  def test_setup_mode_options_configures_fuzzy
    config = OpenStruct.new
    opts = OptionParser.new
    
    # Mock system call to check for fzf
    AIA::Config.expects(:system).with("which fzf > /dev/null 2>&1").returns(true)
    
    AIA::Config.setup_mode_options(opts, config)
    
    opts.parse(['--fuzzy'])
    assert_equal true, config.fuzzy
  end

  def test_setup_model_options_sets_model
    config = OpenStruct.new
    opts = OptionParser.new
    
    AIA::Config.setup_model_options(opts, config)
    
    opts.parse(['--model', 'gpt-4'])
    assert_equal 'gpt-4', config.model
  end

  def test_setup_ai_parameters_sets_temperature
    config = OpenStruct.new
    opts = OptionParser.new
    
    AIA::Config.setup_ai_parameters(opts, config)
    
    opts.parse(['--temperature', '0.5'])
    assert_equal 0.5, config.temperature
  end

  def test_process_tools_option_validates_paths
    config = OpenStruct.new
    config.tool_paths = []
    
    # Create a temporary ruby file
    temp_file = Tempfile.new(['test_tool', '.rb'])
    temp_file.close
    
    AIA::Config.process_tools_option(temp_file.path, config)
    
    assert_includes config.tool_paths, temp_file.path
  ensure
    temp_file.unlink if temp_file
  end

  def test_process_tools_option_rejects_non_ruby_files
    config = OpenStruct.new
    config.tool_paths = []
    
    # Create a temporary non-ruby file
    temp_file = Tempfile.new(['test_tool', '.txt'])
    temp_file.close
    
    # Mock exit to prevent actual termination and verify it's called
    AIA::Config.expects(:exit).with(1)
    
    capture_io do
      AIA::Config.process_tools_option(temp_file.path, config)
    end
  ensure
    temp_file.unlink if temp_file
  end

  def test_process_allowed_tools_option_sets_allowed_tools
    config = OpenStruct.new
    config.allowed_tools = []
    
    AIA::Config.process_allowed_tools_option('tool1,tool2', config)
    
    assert_equal ['tool1', 'tool2'], config.allowed_tools
  end

  def test_process_rejected_tools_option_sets_rejected_tools
    config = OpenStruct.new
    config.rejected_tools = []
    
    AIA::Config.process_rejected_tools_option('badtool1,badtool2', config)
    
    assert_equal ['badtool1', 'badtool2'], config.rejected_tools
  end

  # Test tailor_the_config and extracted helper methods
  def test_process_stdin_content_when_tty
    # Mock STDIN to simulate TTY
    STDIN.stubs(:tty?).returns(true)
    
    result = AIA::Config.process_stdin_content
    
    assert_equal '', result
  end

  def test_process_prompt_id_from_args_with_valid_prompt
    config = OpenStruct.new(prompts_dir: @temp_prompts_dir, prompt_extname: '.txt')
    
    # Create a test prompt file
    prompt_file = File.join(@temp_prompts_dir, 'test_prompt.txt')
    File.write(prompt_file, 'test prompt content')
    
    # Mock AIA file check methods for this specific case
    AIA.stubs(:bad_file?).with('test_prompt').returns(true)
    AIA.stubs(:good_file?).with(prompt_file).returns(true)
    
    remaining_args = ['test_prompt', 'other_arg']
    
    AIA::Config.process_prompt_id_from_args(config, remaining_args)
    
    assert_equal 'test_prompt', config.prompt_id
    assert_equal ['other_arg'], remaining_args
  end

  def test_validate_and_set_context_files_with_valid_files
    config = OpenStruct.new(context_files: [])
    
    # Create temporary files
    temp_file1 = Tempfile.new('context1')
    temp_file2 = Tempfile.new('context2')
    temp_file1.close
    temp_file2.close
    
    # Mock AIA.good_file? to return true for our temp files
    AIA.stubs(:good_file?).with(temp_file1.path).returns(true)
    AIA.stubs(:good_file?).with(temp_file2.path).returns(true)
    
    remaining_args = [temp_file1.path, temp_file2.path]
    
    AIA::Config.validate_and_set_context_files(config, remaining_args)
    
    assert_equal [temp_file1.path, temp_file2.path], config.context_files
  ensure
    temp_file1.unlink if temp_file1
    temp_file2.unlink if temp_file2
  end

  def test_validate_and_set_context_files_with_invalid_files
    config = OpenStruct.new(context_files: [])
    
    # Mock AIA.good_file? to return false
    AIA.stubs(:good_file?).returns(false)
    
    remaining_args = ['nonexistent_file.txt']
    
    # Mock exit to prevent actual termination and verify it's called
    AIA::Config.expects(:exit).with(1)
    
    capture_io do
      AIA::Config.validate_and_set_context_files(config, remaining_args)
    end
  end

  def test_handle_executable_prompt_pops_last_file
    config = OpenStruct.new(
      executable_prompt: true,
      context_files: ['file1.txt', 'file2.txt', 'executable.rb']
    )
    
    AIA::Config.handle_executable_prompt(config)
    
    assert_equal 'executable.rb', config.executable_prompt_file
    assert_equal ['file1.txt', 'file2.txt'], config.context_files
  end

  def test_process_role_configuration_adds_prefix
    config = OpenStruct.new(
      role: 'developer',
      roles_prefix: 'roles',
      prompts_dir: @temp_prompts_dir,
      prompt_id: nil,
      pipeline: []
    )
    
    AIA::Config.process_role_configuration(config)
    
    # The method should set roles_dir based on prompts_dir and roles_prefix
    assert_equal File.join(@temp_prompts_dir, 'roles'), config.roles_dir
    
    # When prompt_id is nil/empty and role is set, it should become the prompt_id
    assert_equal 'roles/developer', config.prompt_id
    assert_equal ['roles/developer'], config.pipeline
    assert_equal '', config.role # Role should be cleared after transfer
  end

  def test_handle_fuzzy_search_prompt_id_sets_special_value
    config = OpenStruct.new(fuzzy: true, prompt_id: '')
    
    AIA::Config.handle_fuzzy_search_prompt_id(config)
    
    assert_equal '__FUZZY_SEARCH__', config.prompt_id
  end

  def test_normalize_boolean_flags_converts_values
    config = OpenStruct.new(chat: 'true', fuzzy: nil)
    
    AIA::Config.normalize_boolean_flags(config)
    
    assert_equal true, config.chat
    assert_equal false, config.fuzzy
  end

  def test_normalize_boolean_flag_individual
    config = OpenStruct.new(test_flag: 'yes')
    
    AIA::Config.normalize_boolean_flag(config, :test_flag)
    
    assert_equal true, config.test_flag
  end

  def test_configure_prompt_manager_sets_regex
    config = OpenStruct.new(parameter_regex: '\\{\\{\\w+\\}\\}')
    
    # Mock PromptManager::Prompt to avoid dependency issues
    PromptManager::Prompt.expects(:parameter_regex=).with(instance_of(Regexp))
    
    AIA::Config.configure_prompt_manager(config)
  end

  def test_prepare_pipeline_prepends_prompt_id
    config = OpenStruct.new(prompt_id: 'main_prompt', pipeline: ['other_prompt'])
    
    AIA::Config.prepare_pipeline(config)
    
    assert_equal ['main_prompt', 'other_prompt'], config.pipeline
  end

  def test_prepare_pipeline_skips_when_already_first
    config = OpenStruct.new(prompt_id: 'main_prompt', pipeline: ['main_prompt', 'other_prompt'])
    
    AIA::Config.prepare_pipeline(config)
    
    assert_equal ['main_prompt', 'other_prompt'], config.pipeline
  end

  # Test load_tools and extracted helper methods
  def test_load_tools_returns_early_when_empty
    config = OpenStruct.new(tool_paths: [])
    
    result = AIA::Config.load_tools(config)
    
    # When tool_paths is empty, the method returns early with nil
    assert_nil result
    assert_empty config.tool_paths
  end

  # Tool filtering tests moved to RubyLLMAdapter since filtering
  # now happens in the adapter, not during config setup
  def test_config_stores_allowed_tools_correctly
    config = OpenStruct.new(
      tool_paths: ['/path/to/good_tool.rb', '/path/to/bad_tool.rb'],
      allowed_tools: ['good_tool']
    )
    
    # Config should store the allowed_tools but not filter tool_paths anymore
    assert_equal ['good_tool'], config.allowed_tools
    assert_equal ['/path/to/good_tool.rb', '/path/to/bad_tool.rb'], config.tool_paths
  end

  def test_config_stores_rejected_tools_correctly
    config = OpenStruct.new(
      tool_paths: ['/path/to/good_tool.rb', '/path/to/bad_tool.rb'],
      rejected_tools: ['bad_tool']
    )
    
    # Config should store the rejected_tools but not filter tool_paths anymore
    assert_equal ['bad_tool'], config.rejected_tools
    assert_equal ['/path/to/good_tool.rb', '/path/to/bad_tool.rb'], config.tool_paths
  end

  # Test cf_options and extracted helper methods
  def test_cf_options_with_nonexistent_file
    # Test that method returns OpenStruct even for nonexistent file
    config = AIA::Config.cf_options('nonexistent.yml')
    assert_instance_of OpenStruct, config
  end

  def test_cf_options_with_yaml_file
    temp_file = Tempfile.new(['config', '.yml'])
    config_data = { 'model' => 'test-model', 'temperature' => 0.8 }
    temp_file.write(YAML.dump(config_data))
    temp_file.close
    
    config = AIA::Config.cf_options(temp_file.path)
    
    assert_equal 'test-model', config.model
    assert_equal 0.8, config.temperature
  ensure
    temp_file.unlink if temp_file
  end

  def test_cf_options_with_toml_file
    temp_file = Tempfile.new(['config', '.toml'])
    config_data = { 'model' => 'test-model', 'temperature' => 0.8 }
    temp_file.write(TomlRB.dump(config_data))
    temp_file.close
    
    config = AIA::Config.cf_options(temp_file.path)
    
    assert_equal 'test-model', config.model
    assert_equal 0.8, config.temperature
  ensure
    temp_file.unlink if temp_file
  end

  def test_read_and_process_config_file_handles_erb
    temp_file = Tempfile.new(['config', '.yml.erb'])
    erb_content = "model: <%= 'gpt-' + '4' %>"
    temp_file.write(erb_content)
    temp_file.close
    
    processed_content = AIA::Config.read_and_process_config_file(temp_file.path)
    
    assert_equal "model: gpt-4", processed_content
    
    # Should also create the processed file
    processed_file = temp_file.path.chomp('.erb')
    assert File.exist?(processed_file)
    assert_equal "model: gpt-4", File.read(processed_file)
  ensure
    temp_file.unlink if temp_file
    File.unlink(processed_file) if processed_file && File.exist?(processed_file)
  end

  def test_parse_config_content_yaml
    yaml_content = "model: gpt-4\ntemperature: 0.7"
    
    result = AIA::Config.parse_config_content(yaml_content, '.yml')
    
    assert_equal 'gpt-4', result[:model]
    assert_equal 0.7, result[:temperature]
  end

  def test_parse_config_content_toml
    toml_content = "model = 'gpt-4'\ntemperature = 0.7"
    
    result = AIA::Config.parse_config_content(toml_content, '.toml')
    
    assert_equal 'gpt-4', result['model']
    assert_equal 0.7, result['temperature']
  end

  def test_parse_config_content_unsupported_format
    content = "some content"
    
    assert_raises(RuntimeError) do
      AIA::Config.parse_config_content(content, '.xyz')
    end
  end

  def test_apply_file_config_to_struct
    config = OpenStruct.new
    file_config = { 'model' => 'test-model', 'temperature' => 0.9 }
    
    AIA::Config.apply_file_config_to_struct(config, file_config)
    
    assert_equal 'test-model', config.model
    assert_equal 0.9, config.temperature
  end

  def test_normalize_last_refresh_date_converts_string
    config = OpenStruct.new(last_refresh: '2023-12-25')
    
    AIA::Config.normalize_last_refresh_date(config)
    
    assert_instance_of Date, config.last_refresh
    assert_equal Date.new(2023, 12, 25), config.last_refresh
  end

  def test_normalize_last_refresh_date_ignores_non_string
    original_date = Date.today
    config = OpenStruct.new(last_refresh: original_date)
    
    AIA::Config.normalize_last_refresh_date(config)
    
    assert_equal original_date, config.last_refresh
  end

  # Test envar_options method
  def test_envar_options_processes_environment_variables
    ENV['AIA_MODEL'] = 'env-model'
    ENV['AIA_CHAT'] = 'true'
    ENV['AIA_TEMPERATURE'] = '0.9'
    
    default_config = OpenStruct.new(model: 'default', chat: false, temperature: 0.7)
    cli_config = OpenStruct.new
    
    result = AIA::Config.envar_options(default_config, cli_config)
    
    assert_equal 'env-model', result.model
    assert_equal true, result.chat
    assert_equal 0.9, result.temperature
  ensure
    ENV.delete('AIA_MODEL')
    ENV.delete('AIA_CHAT')
    ENV.delete('AIA_TEMPERATURE')
  end

  def test_envar_options_handles_array_values
    ENV['AIA_CONTEXT_FILES'] = 'file1.txt,file2.txt'
    
    default_config = OpenStruct.new(context_files: [])
    cli_config = OpenStruct.new
    
    result = AIA::Config.envar_options(default_config, cli_config)
    
    assert_equal ['file1.txt', 'file2.txt'], result.context_files
  ensure
    ENV.delete('AIA_CONTEXT_FILES')
  end

  # Test comprehensive config file loading with real files
  def test_comprehensive_yaml_config_loading
    temp_file = Tempfile.new(['test_config', '.yml'])
    config_data = {
      'model' => 'claude-3-sonnet',
      'temperature' => 0.5,
      'max_tokens' => 4000,
      'prompts_dir' => '/custom/prompts',
      'chat' => true,
      'verbose' => false,
      'require_libs' => ['json', 'base64'],
      'context_files' => ['file1.txt', 'file2.txt']
    }
    temp_file.write(YAML.dump(config_data))
    temp_file.close
    
    config = AIA::Config.cf_options(temp_file.path)
    
    assert_equal 'claude-3-sonnet', config.model
    assert_equal 0.5, config.temperature
    assert_equal 4000, config.max_tokens
    assert_equal '/custom/prompts', config.prompts_dir
    assert_equal true, config.chat
    assert_equal false, config.verbose
    assert_equal ['json', 'base64'], config.require_libs
    assert_equal ['file1.txt', 'file2.txt'], config.context_files
  ensure
    temp_file.unlink if temp_file
  end
  
  def test_comprehensive_toml_config_loading
    temp_file = Tempfile.new(['test_config', '.toml'])
    toml_content = <<~TOML
      model = "gpt-4o"
      temperature = 0.8
      max_tokens = 2048
      chat = false
      debug = true
      
      [advanced]
      top_p = 0.9
      frequency_penalty = 0.1
    TOML
    temp_file.write(toml_content)
    temp_file.close
    
    config = AIA::Config.cf_options(temp_file.path)
    
    assert_equal 'gpt-4o', config.model
    assert_equal 0.8, config.temperature
    assert_equal 2048, config.max_tokens
    assert_equal false, config.chat
    assert_equal true, config.debug
    # TOML nested sections become hashes
    assert_instance_of Hash, config.advanced
    assert_equal 0.9, config.advanced['top_p']
    assert_equal 0.1, config.advanced['frequency_penalty']
  ensure
    temp_file.unlink if temp_file
  end
  
  def test_config_hierarchy_precedence_integration
    # Create a config file
    config_file = Tempfile.new(['base_config', '.yml'])
    config_file.write(YAML.dump({
      'model' => 'file-model',
      'temperature' => 0.3,
      'chat' => false
    }))
    config_file.close
    
    # Set environment variables
    ENV['AIA_MODEL'] = 'env-model'
    ENV['AIA_TEMPERATURE'] = '0.6'
    
    # Set command line arguments
    ARGV.replace(['--chat', '--model', 'cli-model'])
    
    # Mock the config file path in setup
    original_method = AIA::Config.method(:setup)
    AIA::Config.define_singleton_method(:setup) do
      default_config  = AIA::Config::DEFAULT_CONFIG.dup
      cli_config      = cli_options
      envar_config    = envar_options(default_config, cli_config)
      cf_config       = cf_options(config_file.path)
      
      config = OpenStruct.merge(
        default_config,
        cf_config    || {},
        envar_config || {},
        cli_config   || {}
      )
      
      # Skip the full tailor_the_config to avoid dependencies
      config.remaining_args = cli_config.remaining_args
      config
    end
    
    config = AIA::Config.setup
    
    # CLI should override env, env should override file, file should override defaults
    assert_equal 'cli-model', config.model  # CLI wins
    assert_equal 0.6, config.temperature    # ENV wins over file
    assert_equal true, config.chat          # CLI wins over file
    
  ensure
    config_file.unlink if config_file
    ENV.delete('AIA_MODEL')
    ENV.delete('AIA_TEMPERATURE')
    # Restore original method
    AIA::Config.define_singleton_method(:setup, original_method) if original_method
  end
  
  def test_validation_methods_integration
    # Test prompt ID validation with real files
    prompt_file = File.join(@temp_prompts_dir, 'valid_prompt.txt')
    File.write(prompt_file, 'This is a valid prompt')
    
    config = OpenStruct.new(
      prompts_dir: @temp_prompts_dir,
      prompt_extname: '.txt',
      prompt_id: nil
    )
    
    # Use real file checking instead of mocks
    AIA.unstub(:bad_file?)
    AIA.unstub(:good_file?)
    
    remaining_args = ['valid_prompt', 'context.txt']
    
    AIA::Config.process_prompt_id_from_args(config, remaining_args)
    
    assert_equal 'valid_prompt', config.prompt_id
    assert_equal ['context.txt'], remaining_args
  end
  
  def test_role_configuration_comprehensive
    config = OpenStruct.new(
      role: 'developer',
      roles_prefix: 'roles',
      prompts_dir: @temp_prompts_dir,
      prompt_id: nil,
      pipeline: [],
      roles_dir: nil
    )
    
    AIA::Config.process_role_configuration(config)
    
    # Should set roles_dir
    assert_equal File.join(@temp_prompts_dir, 'roles'), config.roles_dir
    
    # Should prepend roles prefix to role
    assert_equal 'roles/developer', config.prompt_id
    
    # Should add to pipeline
    assert_equal ['roles/developer'], config.pipeline
    
    # Should clear role after processing
    assert_equal '', config.role
  end
  
  def test_tool_processing_with_directory_structure
    # Create a temporary tools directory with Ruby files
    tools_dir = Dir.mktmpdir('test_tools')
    
    # Create some tool files
    tool1 = File.join(tools_dir, 'tool1.rb')
    tool2 = File.join(tools_dir, 'tool2.rb')
    non_ruby = File.join(tools_dir, 'not_a_tool.txt')
    
    File.write(tool1, 'class Tool1; end')
    File.write(tool2, 'class Tool2; end')
    File.write(non_ruby, 'not ruby code')
    
    config = OpenStruct.new(tool_paths: [])
    
    # Process the directory
    AIA::Config.process_tools_option(tools_dir, config)
    
    # Should include only Ruby files
    assert_equal 2, config.tool_paths.size
    assert_includes config.tool_paths, tool1
    assert_includes config.tool_paths, tool2
    refute_includes config.tool_paths, non_ruby
    
  ensure
    FileUtils.rm_rf(tools_dir) if tools_dir
  end
  
  def test_tool_configuration_stores_filter_settings
    # Tool filtering moved to RubyLLMAdapter, but config should store the settings
    config = OpenStruct.new(
      tool_paths: [
        '/path/to/good_tool.rb',
        '/path/to/bad_tool.rb',
        '/path/to/another_good.rb',
        '/path/to/rejected_tool.rb'
      ],
      allowed_tools: ['good_tool', 'another_good'],
      rejected_tools: ['rejected_tool']
    )
    
    # Config should store filter settings without modifying tool_paths
    assert_equal ['good_tool', 'another_good'], config.allowed_tools
    assert_equal ['rejected_tool'], config.rejected_tools
    assert_equal 4, config.tool_paths.size
    assert_includes config.tool_paths, '/path/to/good_tool.rb'
    assert_includes config.tool_paths, '/path/to/bad_tool.rb'
    assert_includes config.tool_paths, '/path/to/another_good.rb'
    assert_includes config.tool_paths, '/path/to/rejected_tool.rb'
  end
  
  # Note: ERB processing test removed for simplicity - covered in integration tests
  
  def test_config_validation_edge_cases
    # Test empty pipeline validation
    config = OpenStruct.new(pipeline: [])
    
    # Should not raise error for empty pipeline
    AIA::Config.validate_pipeline_prompts(config)
    
    # Test pipeline with nil/empty entries
    config.pipeline = ['valid_prompt', nil, '', 'another_prompt']
    
    # Create the valid prompt files
    File.write(File.join(@temp_prompts_dir, 'valid_prompt.txt'), 'content')
    File.write(File.join(@temp_prompts_dir, 'another_prompt.txt'), 'content')
    
    config.prompts_dir = @temp_prompts_dir
    
    # Should skip nil/empty entries and not raise error
    AIA::Config.validate_pipeline_prompts(config)
  end
  
  def test_boolean_flag_normalization_comprehensive
    config = OpenStruct.new(
      chat: 'true',
      fuzzy: 'false', 
      verbose: 'yes',
      debug: 'no',
      terse: '1',
      append: '0',
      markdown: nil,
      clear: ''
    )
    
    # Test individual flag normalization
    AIA::Config.normalize_boolean_flag(config, :chat)
    AIA::Config.normalize_boolean_flag(config, :fuzzy)
    AIA::Config.normalize_boolean_flag(config, :verbose)
    AIA::Config.normalize_boolean_flag(config, :debug)
    AIA::Config.normalize_boolean_flag(config, :terse)
    AIA::Config.normalize_boolean_flag(config, :append)
    AIA::Config.normalize_boolean_flag(config, :markdown)
    AIA::Config.normalize_boolean_flag(config, :clear)
    
    # String 'true' should become boolean true
    assert_equal true, config.chat
    # String 'false' should become boolean true (any non-empty string is truthy)
    assert_equal true, config.fuzzy
    # String 'yes' should become boolean true
    assert_equal true, config.verbose
    # String 'no' should become boolean true (any non-empty string is truthy)
    assert_equal true, config.debug
    # String '1' should become boolean true
    assert_equal true, config.terse
    # String '0' should become boolean true (any non-empty string is truthy)
    assert_equal true, config.append
    # nil should become false
    assert_equal false, config.markdown
    # empty string should become false
    assert_equal false, config.clear
  end
  
  private

  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end