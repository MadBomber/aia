require_relative '../test_helper'
require 'ostruct'
require 'tempfile'
require_relative '../../lib/aia'

class PromptHandlerTest < Minitest::Test
  def setup
    @temp_prompts_dir = Dir.mktmpdir('aia_prompts')
    @temp_roles_dir = File.join(@temp_prompts_dir, 'roles')
    Dir.mkdir(@temp_roles_dir)
    
    # Mock AIA.config
    AIA.stubs(:config).returns(OpenStruct.new(
      prompts_dir: @temp_prompts_dir,
      roles_dir: @temp_roles_dir,
      roles_prefix: 'roles',
      role_prefix: 'roles',
      erb: true,
      shell: true,
      fuzzy: false
    ))
    
    # Mock PromptManager::Storage::FileSystemAdapter
    mock_storage_adapter = mock('storage_adapter')
    mock_config = mock('config')
    mock_config.stubs(:prompts_dir=)
    mock_config.stubs(:prompt_extension=)
    mock_config.stubs(:params_extension=)
    mock_storage_adapter.stubs(:config).yields(mock_config)
    mock_storage_adapter.stubs(:new).returns(mock('adapter_instance'))
    PromptManager::Storage::FileSystemAdapter.stubs(:config).returns(mock_storage_adapter)
    
    # Mock DirectiveProcessor
    AIA::DirectiveProcessor.stubs(:new).returns(mock('directive_processor'))
    
    @handler = AIA::PromptHandler.new
  end

  def teardown
    FileUtils.rm_rf(@temp_prompts_dir) if @temp_prompts_dir && Dir.exist?(@temp_prompts_dir)
  end

  def test_initialization
    assert_instance_of AIA::PromptHandler, @handler
  end

  def test_get_prompt_without_role
    # Create a test prompt file
    prompt_file = File.join(@temp_prompts_dir, 'test_prompt.txt')
    File.write(prompt_file, 'Test prompt content')
    
    # Mock PromptManager::Prompt.new
    mock_prompt = mock('prompt')
    mock_prompt.stubs(:text).returns('Test prompt content')
    PromptManager::Prompt.expects(:new).with(
      id: 'test_prompt',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_prompt)
    
    result = @handler.get_prompt('test_prompt')
    assert_equal mock_prompt, result
  end

  def test_get_prompt_with_role
    # Create test files
    prompt_file = File.join(@temp_prompts_dir, 'test_prompt.txt')
    File.write(prompt_file, 'Test prompt content')
    
    role_file = File.join(@temp_prompts_dir, 'roles', 'developer.txt')
    File.write(role_file, 'You are a developer.')
    
    # Mock PromptManager::Prompt.new for both prompt and role
    mock_prompt = mock('prompt')
    mock_prompt_text = mock('prompt_text')
    mock_prompt_text.expects(:prepend).with('You are a developer.')
    mock_prompt.stubs(:text).returns(mock_prompt_text)
    
    mock_role = mock('role')
    mock_role.stubs(:text).returns('You are a developer.')
    
    PromptManager::Prompt.expects(:new).with(
      id: 'test_prompt',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_prompt)
    
    PromptManager::Prompt.expects(:new).with(
      id: 'roles/developer',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_role)
    
    result = @handler.get_prompt('test_prompt', 'developer')
    assert_equal mock_prompt, result
  end

  def test_fetch_prompt_with_existing_file
    # Create a test prompt file
    prompt_file = File.join(@temp_prompts_dir, 'existing_prompt.txt')
    File.write(prompt_file, 'Existing prompt content')
    
    # Mock PromptManager::Prompt.new
    mock_prompt = mock('prompt')
    PromptManager::Prompt.expects(:new).returns(mock_prompt)
    
    result = @handler.fetch_prompt('existing_prompt')
    assert_equal mock_prompt, result
  end

  def test_fetch_prompt_with_fuzzy_search_special_case
    # Mock fuzzy search
    @handler.expects(:fuzzy_search_prompt).with('').returns(mock('prompt'))
    
    result = @handler.fetch_prompt('__FUZZY_SEARCH__')
    assert_instance_of Mocha::Mock, result
  end

  def test_fetch_prompt_with_missing_file_and_fuzzy_disabled
    AIA.config.fuzzy = false
    
    @handler.expects(:puts).with('Warning: Invalid prompt ID or file not found: nonexistent')
    
    assert_raises(RuntimeError, /Could not find prompt with ID: nonexistent/) do
      @handler.fetch_prompt('nonexistent')
    end
  end

  def test_fetch_prompt_with_missing_file_and_fuzzy_enabled
    AIA.config.fuzzy = true
    
    @handler.expects(:puts).with('Warning: Invalid prompt ID or file not found: nonexistent')
    @handler.expects(:fuzzy_search_prompt).with('nonexistent').returns(mock('prompt'))
    
    result = @handler.fetch_prompt('nonexistent')
    assert_instance_of Mocha::Mock, result
  end

  def test_fetch_role_with_existing_file
    # Create a test role file
    role_file = File.join(@temp_prompts_dir, 'roles', 'developer.txt')
    File.write(role_file, 'You are a developer.')
    
    # Mock PromptManager::Prompt.new
    mock_role = mock('role')
    PromptManager::Prompt.expects(:new).with(
      id: 'roles/developer',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_role)
    
    result = @handler.fetch_role('developer')
    assert_equal mock_role, result
  end

  def test_fetch_role_with_roles_prefix_already_present
    # Create a test role file
    role_file = File.join(@temp_prompts_dir, 'roles', 'developer.txt')
    File.write(role_file, 'You are a developer.')
    
    # Mock PromptManager::Prompt.new
    mock_role = mock('role')
    PromptManager::Prompt.expects(:new).with(
      id: 'roles/developer',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_role)
    
    result = @handler.fetch_role('roles/developer')
    assert_equal mock_role, result
  end

  def test_fetch_role_with_missing_file_and_fuzzy_disabled
    AIA.config.fuzzy = false
    
    @handler.expects(:puts).with('Warning: Invalid role ID or file not found: roles/nonexistent')
    
    assert_raises(RuntimeError, /Could not find role with ID: roles\/nonexistent/) do
      @handler.fetch_role('nonexistent')
    end
  end

  def test_fuzzy_search_prompt_success
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Create test prompt files
    File.write(File.join(@temp_prompts_dir, 'prompt1.txt'), 'Prompt 1')
    File.write(File.join(@temp_prompts_dir, 'prompt2.txt'), 'Prompt 2')
    
    # Mock Fzf
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns('prompt1')
    AIA::Fzf.expects(:new).with(
      list: ['prompt1', 'prompt2'],
      directory: @temp_prompts_dir,
      query: 'test',
      subject: 'Prompt IDs',
      prompt: 'Select a prompt ID:'
    ).returns(mock_fzf)
    
    # Mock PromptManager::Prompt.new
    mock_prompt = mock('prompt')
    PromptManager::Prompt.expects(:new).with(
      id: 'prompt1',
      directives_processor: anything,
      external_binding: anything,
      erb_flag: true,
      envar_flag: true
    ).returns(mock_prompt)
    
    result = @handler.fuzzy_search_prompt('test')
    assert_equal mock_prompt, result
  end

  def test_fuzzy_search_prompt_no_selection
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Mock Fzf to return nil
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns(nil)
    AIA::Fzf.expects(:new).returns(mock_fzf)
    
    assert_raises(RuntimeError, /Could not find prompt with ID: test even with fuzzy search/) do
      @handler.fuzzy_search_prompt('test')
    end
  end

  def test_search_prompt_id_with_fzf_success
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Create test prompt files
    File.write(File.join(@temp_prompts_dir, 'prompt1.txt'), 'Prompt 1')
    File.write(File.join(@temp_prompts_dir, 'prompt2.txt'), 'Prompt 2')
    
    # Mock Fzf
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns('prompt2')
    AIA::Fzf.expects(:new).with(
      list: ['prompt1', 'prompt2'],
      directory: @temp_prompts_dir,
      query: 'test',
      subject: 'Prompt IDs',
      prompt: 'Select a prompt ID:'
    ).returns(mock_fzf)
    
    result = @handler.search_prompt_id_with_fzf('test')
    assert_equal 'prompt2', result
  end

  def test_search_prompt_id_with_fzf_no_selection
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Mock Fzf to return nil
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns(nil)
    AIA::Fzf.expects(:new).returns(mock_fzf)
    
    assert_raises(RuntimeError, /No prompt ID selected/) do
      @handler.search_prompt_id_with_fzf('test')
    end
  end

  def test_search_role_id_with_fzf_success
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Create test role files
    File.write(File.join(@temp_roles_dir, 'developer.txt'), 'Developer role')
    File.write(File.join(@temp_roles_dir, 'tester.txt'), 'Tester role')
    
    # Mock Fzf
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns('developer')
    AIA::Fzf.expects(:new).with(
      list: ['developer', 'tester'],
      directory: @temp_prompts_dir,
      query: 'dev',
      subject: 'Role IDs',
      prompt: 'Select a role ID:'
    ).returns(mock_fzf)
    
    result = @handler.search_role_id_with_fzf('dev')
    assert_equal 'roles/developer', result
  end

  def test_search_role_id_with_fzf_with_prefix_already_present
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Create test role files
    File.write(File.join(@temp_roles_dir, 'developer.txt'), 'Developer role')
    
    # Mock Fzf
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns('roles/developer')
    AIA::Fzf.expects(:new).returns(mock_fzf)
    
    result = @handler.search_role_id_with_fzf('dev')
    assert_equal 'roles/developer', result
  end

  def test_search_role_id_with_fzf_no_selection
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Mock Fzf to return nil
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns(nil)
    AIA::Fzf.expects(:new).returns(mock_fzf)
    
    assert_raises(RuntimeError, /No role ID selected/) do
      @handler.search_role_id_with_fzf('test')
    end
  end

  def test_search_role_id_with_fzf_empty_selection
    skip "fzf not available" unless system('which fzf >/dev/null 2>&1')
    require_relative '../../lib/aia/fzf'
    
    # Mock Fzf to return empty string
    mock_fzf = mock('fzf')
    mock_fzf.expects(:run).returns('')
    AIA::Fzf.expects(:new).returns(mock_fzf)
    
    assert_raises(RuntimeError, /No role ID selected/) do
      @handler.search_role_id_with_fzf('test')
    end
  end

  def test_handle_missing_prompt_with_fuzzy_enabled
    AIA.config.fuzzy = true
    
    @handler.expects(:fuzzy_search_prompt).with('missing').returns(mock('prompt'))
    
    result = @handler.handle_missing_prompt('missing')
    assert_instance_of Mocha::Mock, result
  end

  def test_handle_missing_prompt_with_fuzzy_disabled
    AIA.config.fuzzy = false
    
    assert_raises(RuntimeError, /Could not find prompt with ID: missing/) do
      @handler.handle_missing_prompt('missing')
    end
  end

  def test_handle_missing_role_with_fuzzy_enabled
    AIA.config.fuzzy = true
    
    @handler.expects(:fuzzy_search_role).with('missing').returns(mock('role'))
    
    result = @handler.handle_missing_role('missing')
    assert_instance_of Mocha::Mock, result
  end

  def test_handle_missing_role_with_fuzzy_disabled
    AIA.config.fuzzy = false
    
    assert_raises(RuntimeError, /Could not find role with ID: missing/) do
      @handler.handle_missing_role('missing')
    end
  end
end