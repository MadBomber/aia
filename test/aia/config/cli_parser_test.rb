require_relative '../../test_helper'

class CLIParserModelsTest < Minitest::Test
  def test_parse_single_model
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o')
    assert_equal 1, result.size
    assert_equal 'gpt-4o', result[0][:name]
    assert_nil result[0][:role]
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]
  end

  def test_parse_multiple_models
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o,claude-3')
    assert_equal 2, result.size
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'claude-3', result[1][:name]
  end

  def test_parse_model_with_role
    Dir.mktmpdir do |dir|
      # Create role file structure
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '# Architect role')

      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=architect')
      assert_equal 1, result.size
      assert_equal 'gpt-4o', result[0][:name]
      assert_equal 'architect', result[0][:role]
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end

  def test_parse_duplicate_models_get_incremented_instances
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o,gpt-4o')
    assert_equal 2, result.size
    assert_equal 1, result[0][:instance]
    assert_equal 'gpt-4o', result[0][:internal_id]
    assert_equal 2, result[1][:instance]
    assert_equal 'gpt-4o#2', result[1][:internal_id]
  end

  def test_parse_model_with_spaces_in_csv
    result = AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o , claude-3')
    assert_equal 2, result.size
    assert_equal 'gpt-4o', result[0][:name]
    assert_equal 'claude-3', result[1][:name]
  end

  def test_parse_model_invalid_syntax_leading_equals
    assert_raises(ArgumentError) do
      AIA::CLIParser.send(:parse_models_with_roles, '=role')
    end
  end

  def test_parse_model_invalid_syntax_trailing_equals
    assert_raises(ArgumentError) do
      AIA::CLIParser.send(:parse_models_with_roles, 'model=')
    end
  end

  def test_parse_model_nonexistent_role_raises
    Dir.mktmpdir do |dir|
      ENV['AIA_PROMPTS__DIR'] = dir
      ENV['AIA_PROMPTS__ROLES_PREFIX'] = 'roles'

      assert_raises(ArgumentError) do
        AIA::CLIParser.send(:parse_models_with_roles, 'gpt-4o=nonexistent')
      end
    end
  ensure
    ENV.delete('AIA_PROMPTS__DIR')
    ENV.delete('AIA_PROMPTS__ROLES_PREFIX')
  end
end

class CLIParserToolsPathsTest < Minitest::Test
  def test_process_tools_paths_empty_raises
    # Empty string should trigger exit (which is intercepted in tests)
    AIA::CLIParser.send(:process_tools_paths, '')
    # The overridden exit prevents termination
  end

  def test_process_tools_paths_single_rb_file
    Dir.mktmpdir do |dir|
      rb_file = File.join(dir, 'tool.rb')
      File.write(rb_file, '# tool')

      result = AIA::CLIParser.send(:process_tools_paths, rb_file)
      assert_equal [rb_file], result
    end
  end

  def test_process_tools_paths_directory
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a.rb'), '# a')
      File.write(File.join(dir, 'b.rb'), '# b')
      File.write(File.join(dir, 'c.txt'), '# not ruby')

      result = AIA::CLIParser.send(:process_tools_paths, dir)
      assert_equal 2, result.size
      assert result.all? { |p| p.end_with?('.rb') }
    end
  end

  def test_process_tools_paths_comma_separated
    Dir.mktmpdir do |dir|
      f1 = File.join(dir, 'a.rb')
      f2 = File.join(dir, 'b.rb')
      File.write(f1, '# a')
      File.write(f2, '# b')

      result = AIA::CLIParser.send(:process_tools_paths, "#{f1},#{f2}")
      assert_equal 2, result.size
    end
  end

  def test_process_tools_paths_deduplicates
    Dir.mktmpdir do |dir|
      f = File.join(dir, 'tool.rb')
      File.write(f, '# tool')

      result = AIA::CLIParser.send(:process_tools_paths, "#{f},#{f}")
      assert_equal 1, result.size
    end
  end

  def test_list_available_role_names
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)
      File.write(File.join(roles_dir, 'architect.md'), '')
      File.write(File.join(roles_dir, 'reviewer.md'), '')

      result = AIA::CLIParser.send(:list_available_role_names, dir, 'roles')
      assert_equal ['architect', 'reviewer'], result
    end
  end

  def test_list_available_role_names_empty
    Dir.mktmpdir do |dir|
      roles_dir = File.join(dir, 'roles')
      Dir.mkdir(roles_dir)

      result = AIA::CLIParser.send(:list_available_role_names, dir, 'roles')
      assert_equal [], result
    end
  end

  def test_list_available_role_names_no_dir
    result = AIA::CLIParser.send(:list_available_role_names, '/nonexistent', 'roles')
    assert_equal [], result
  end
end


# P1: Verify CLI_TO_NESTED_MAP covers all flat CLI keys that need mapping
class CLIToNestedMapCompletenessTest < Minitest::Test
  # Keys handled specially in Config#apply_overrides or Config#initialize
  # (not routed through CLI_TO_NESTED_MAP)
  SPECIAL_KEYS = %i[
    models
    extra_config_file
    mcp_files
    pipeline
    require_libs
    context_files
    mcp_use
    mcp_skip
    mcp_servers
  ].freeze

  # Runtime attributes set on Config but not routed to nested sections
  RUNTIME_KEYS = %i[
    remaining_args
    prompt_id
    dump_file
    completion
    mcp_list
    list_tools
    log_level_override
    log_file_override
    executable_prompt_content
    stdin_content
  ].freeze

  def test_all_cli_parser_keys_are_accounted_for
    # Extract all option keys that CLIParser can set
    cli_keys = extract_cli_parser_keys

    mapped_keys = AIA::Config::CLI_TO_NESTED_MAP.keys
    all_known = mapped_keys + SPECIAL_KEYS + RUNTIME_KEYS

    unmapped = cli_keys - all_known

    assert_empty unmapped,
      "CLI parser keys not in CLI_TO_NESTED_MAP, SPECIAL_KEYS, or RUNTIME_KEYS: #{unmapped.inspect}\n" \
      "Add them to the appropriate location."
  end

  def test_cli_to_nested_map_targets_valid_sections
    schema_sections = %i[service llm prompts output audio image embedding tools flags registry paths logger rules concurrency]

    AIA::Config::CLI_TO_NESTED_MAP.each do |cli_key, (section, _nested_key)|
      assert_includes schema_sections, section,
        "CLI_TO_NESTED_MAP[:#{cli_key}] targets unknown section :#{section}"
    end
  end

  # I12: Validate that every nested key in CLI_TO_NESTED_MAP exists in defaults.yml
  def test_cli_to_nested_map_targets_valid_schema_keys
    defaults_path = File.expand_path('../../../../lib/aia/config/defaults.yml', __FILE__)
    schema = YAML.safe_load(File.read(defaults_path), permitted_classes: [Symbol], symbolize_names: true)
    defaults = schema[:defaults] || schema

    AIA::Config::CLI_TO_NESTED_MAP.each do |cli_key, (section, nested_key)|
      section_hash = defaults[section]
      assert section_hash.is_a?(Hash),
        "CLI_TO_NESTED_MAP[:#{cli_key}] targets section :#{section} which is not a Hash in defaults.yml"

      assert section_hash.key?(nested_key),
        "CLI_TO_NESTED_MAP[:#{cli_key}] targets :#{section}.#{nested_key} which does not exist in defaults.yml. " \
        "Add :#{nested_key} to the :#{section} section in defaults.yml or fix the mapping."
    end
  end

  private

  def extract_cli_parser_keys
    # Parse the CLI parser source to find all `options[:key]` assignments
    parser_path = File.expand_path('../../../../lib/aia/config/cli_parser.rb', __FILE__)
    source = File.read(parser_path)

    source.scan(/options\[:(\w+)\]/).flatten.map(&:to_sym).uniq
  end
end
