require_relative '../test_helper'
require_relative '../../lib/aia'

class AIATest < Minitest::Test
  def teardown
    AIA.reset!
  end

  def test_run_method_exists
    assert_respond_to AIA, :run, "AIA should respond to the 'run' method"
  end

  def test_config_method_exists
    assert_respond_to AIA, :config, "AIA should respond to the 'config' method"
  end

  def test_client_method_exists
    assert_respond_to AIA, :client, "AIA should respond to the 'client' method"
  end

  def test_good_file_method_exists
    assert_respond_to AIA, :good_file?, "AIA should respond to the 'good_file?' method"
  end

  def test_bad_file_method_exists
    assert_respond_to AIA, :bad_file?, "AIA should respond to the 'bad_file?' method"
  end

  def test_reset_method_exists
    assert_respond_to AIA, :reset!, "AIA should respond to the 'reset!' method"
  end

  def test_reset_nils_all_singletons
    ivars = %i[@config @client @session_tracker @turn_state
               @task_coordinator]

    # Prime each ivar to a non-nil sentinel value
    ivars.each { |iv| AIA.instance_variable_set(iv, :sentinel) }

    AIA.reset!

    ivars.each do |iv|
      assert_nil AIA.instance_variable_get(iv), "#{iv} should be nil after reset!"
    end
  end

  def test_reset_is_idempotent
    AIA.reset!
    AIA.reset!  # second call should not raise
    assert_nil AIA.instance_variable_get(:@config)
  end
end
