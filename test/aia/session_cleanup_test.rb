# frozen_string_literal: true
# test/aia/session_cleanup_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'

class SessionCleanupTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags:    OpenStruct.new(chat: false, debug: false, no_mcp: true),
      models:   [OpenStruct.new(name: 'gpt-4o-mini')],
      output:   OpenStruct.new(file: nil, append: false, history_file: nil),
      context_files: [],
      pipeline: []
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_info)
    @ui.stubs(:display_separator)
    @ui.stubs(:display_chat_end)
    AIA::UIPresenter.stubs(:new).returns(@ui)
  end

  def test_cleanup_calls_close_all_on_mcp_manager
    session = AIA::Session.allocate
    mcp_manager = mock('mcp_manager')
    mcp_manager.expects(:close_all).once

    session.instance_variable_set(:@mcp_manager, mcp_manager)
    session.instance_variable_set(:@filters, {})

    session.cleanup
  end

  def test_cleanup_calls_cleanup_on_each_filter
    session = AIA::Session.allocate
    filter_a = mock('filter_a')
    filter_a.expects(:cleanup).once
    filter_b = mock('filter_b')
    filter_b.expects(:cleanup).once

    session.instance_variable_set(:@mcp_manager, nil)
    session.instance_variable_set(:@filters, { tfidf: filter_a, lsi: filter_b })

    session.cleanup
  end

  def test_cleanup_handles_nil_mcp_manager
    session = AIA::Session.allocate
    session.instance_variable_set(:@mcp_manager, nil)
    session.instance_variable_set(:@filters, {})

    begin
      session.cleanup
      passed = true
    rescue => e
      passed = false
    end
    assert passed, "cleanup should not raise when @mcp_manager is nil"
  end
end
