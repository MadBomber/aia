# frozen_string_literal: true

# test/aia/lazy_loaded_requires_test.rb

require_relative '../test_helper'
require 'open3'

# aia loads these files on first use, and other test files load the classes
# they need, so only a fresh process shows whether a file requires its own
# dependencies.
class LazyLoadedRequiresTest < Minitest::Test
  def test_delegate_handler_loads_its_task_classes
    assert_loads 'aia/delegate_handler', %w[AIA::TaskDecomposer AIA::TaskExecutor]
  end

  def test_delegate_to_foreman_tool_loads_the_task_board_tool
    assert_loads 'aia/tools/delegate_to_foreman_tool', %w[AIA::TaskBoardTool]
  end

  private

  def assert_loads(feature, constants)
    script = "require 'aia'; require '#{feature}'; #{constants.join('; ')}"
    output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)

    assert status.success?, "requiring #{feature} did not define #{constants.join(', ')}:\n#{output}"
  end
end
