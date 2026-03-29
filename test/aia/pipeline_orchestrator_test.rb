# frozen_string_literal: true
# test/aia/pipeline_orchestrator_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia'
require_relative '../../lib/aia/pipeline_orchestrator'

class PipelineOrchestratorTest < Minitest::Test
  def setup
    @config = OpenStruct.new(
      flags: OpenStruct.new(
        chat: false, debug: false, verbose: false, tokens: false,
        track_pipeline: false
      ),
      models: [OpenStruct.new(name: 'gpt-4o-mini')],
      pipeline: ['prompt1'],
      context_files: [],
      stdin_content: nil,
      prompts: OpenStruct.new(role: nil, dir: '/tmp', extname: '.md'),
      mcp_servers: [],
      output: OpenStruct.new(file: nil, append: false),
      concurrency: nil
    )
    AIA.stubs(:config).returns(@config)
    AIA.stubs(:turn_state).returns(AIA::TurnState.new)

    @ui = mock('ui_presenter')
    @ui.stubs(:display_ai_response)
    @ui.stubs(:display_separator)
    @ui.stubs(:display_info)
    @ui.stubs(:display_token_metrics)
    @ui.stubs(:with_spinner).yields

    @tracker = mock('session_tracker')
    @tracker.stubs(:record_turn)

    @prompt_handler  = mock('prompt_handler')
    @input_collector = mock('input_collector')

    @robot = mock('robot')
    @robot.stubs(:is_a?).with(RobotLab::Network).returns(false)
    @robot.stubs(:run).returns(OpenStruct.new(reply: "AI response"))
  end

  def test_process_skips_nil_pipeline_entries
    @config.pipeline = [nil, '', 'valid_prompt']

    parsed = mock('parsed')
    parsed.stubs(:parameters).returns(nil)
    parsed.stubs(:to_s).returns("prompt text")

    @prompt_handler.stubs(:fetch_prompt).with('valid_prompt').returns(parsed)
    @prompt_handler.stubs(:fetch_prompt).with(nil).returns(nil)
    @prompt_handler.stubs(:fetch_prompt).with('').returns(nil)

    @robot.expects(:run).at_least_once.returns(OpenStruct.new(reply: "AI response"))

    orchestrator = build_orchestrator
    orchestrator.process(@config)

    assert_equal 1, @config.pipeline.count { |e| e == 'valid_prompt' },
                 "pipeline should contain exactly one valid (non-nil, non-empty) entry"
  end

  def test_process_records_turn
    parsed = mock('parsed')
    parsed.stubs(:parameters).returns(nil)
    parsed.stubs(:to_s).returns("prompt text")
    @prompt_handler.stubs(:fetch_prompt).returns(parsed)

    @tracker.expects(:record_turn).at_least_once

    orchestrator = build_orchestrator
    orchestrator.process(@config)
  end

  def test_process_empty_pipeline_does_nothing
    @config.pipeline = []
    @prompt_handler.expects(:fetch_prompt).never
    @tracker.expects(:record_turn).never

    orchestrator = build_orchestrator
    orchestrator.process(@config)
  end

  private

  def build_orchestrator
    AIA::PipelineOrchestrator.new(
      robot:           @robot,
      prompt_handler:  @prompt_handler,
      input_collector: @input_collector,
      ui_presenter:    @ui,
      session_tracker: @tracker
    )
  end
end
