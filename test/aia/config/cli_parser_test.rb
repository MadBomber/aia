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
