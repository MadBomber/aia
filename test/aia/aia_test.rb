require_relative '../test_helper'
require_relative '../../lib/aia'

class AIATest < Minitest::Test
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

  def test_build_flags_method_exists
    assert_respond_to AIA, :build_flags, "AIA should respond to the 'build_flags' method"
  end
end
