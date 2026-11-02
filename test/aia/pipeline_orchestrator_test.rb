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
      prompts: OpenStruct.new(role: nil, dir: '/tmp', extname: '.md', skills: []),
      skills: OpenStruct.new(dir: Dir.mktmpdir('aia_test_skills')),
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

    @robot.expects(:run).once.returns(OpenStruct.new(reply: "AI response"))

    orchestrator = build_orchestrator
    orchestrator.process(@config)

    assert_empty @config.pipeline, "pipeline should be fully consumed after processing"
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

  def test_process_speaks_each_response_when_speak_is_on
    stub_prompt
    AIA.stubs(:paint?).returns(false)
    AIA.stubs(:speak?).returns(true)
    AIA::Speech.expects(:speak_text).with("AI response").once
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).returns([OpenStruct.new(reply: "AI response"), "AI response"])

    orchestrator.process(@config)
  end

  def test_process_stays_quiet_when_speak_is_off
    stub_prompt
    AIA.stubs(:paint?).returns(false)
    AIA.stubs(:speak?).returns(false)
    AIA::Speech.expects(:speak_text).never

    build_orchestrator.process(@config)
  end

  def test_process_paint_neither_writes_the_output_file_nor_speaks
    stub_prompt
    AIA.stubs(:paint?).returns(true)
    AIA.stubs(:speak?).returns(true)
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).returns([OpenStruct.new(reply: "x"), "Image saved to out.png"])
    orchestrator.expects(:output_to_file).never
    AIA::Speech.expects(:speak_text).never

    orchestrator.process(@config)
  end

  def test_process_leaves_trakflow_alone_without_track_pipeline
    stub_prompt
    AIA::TrakFlowBridge.expects(:new).never

    build_orchestrator.process(@config)
  end

  def test_tracked_step_is_started_then_completed
    stub_prompt
    AIA.stubs(:paint?).returns(false)
    AIA.stubs(:speak?).returns(false)
    bridge = mock('bridge')
    steps = sequence('steps')
    bridge.expects(:update_step_status).with('prompt1', :started).in_sequence(steps)
    bridge.expects(:update_step_status).with('prompt1', :completed).in_sequence(steps)
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).returns([OpenStruct.new(reply: 'ok'), 'ok'])

    orchestrator.send(:run_step, 'prompt1', @config, bridge)
  end

  def test_tracked_step_is_blocked_when_it_fails
    stub_prompt
    bridge = mock('bridge')
    bridge.expects(:update_step_status).with('prompt1', :started)
    bridge.expects(:update_step_status).with('prompt1', :failed, reason: 'boom')
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).raises(StandardError, 'boom')

    assert_raises(StandardError) { orchestrator.send(:run_step, 'prompt1', @config, bridge) }
  end

  def test_process_creates_the_plan_with_track_pipeline
    stub_prompt
    @config.flags.track_pipeline = true
    bridge = mock('bridge')
    bridge.expects(:create_plan_from_pipeline).with(['prompt1'])
    bridge.stubs(:update_step_status)
    AIA::TrakFlowBridge.stubs(:new).returns(bridge)
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).returns([OpenStruct.new(reply: 'ok'), 'ok'])
    AIA.stubs(:paint?).returns(false)
    AIA.stubs(:speak?).returns(false)

    orchestrator.process(@config)
  end

  def test_build_prompt_text_appends_skills_in_pipeline_mode
    Dir.mktmpdir do |skills_base|
      skill_dir = File.join(skills_base, 'expert')
      FileUtils.mkdir_p(skill_dir)
      File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Expert\n---\nBe an expert.")

      @config.flags.chat = false
      @config.prompts.skills = ['expert']
      @config.skills = OpenStruct.new(dir: skills_base)

      parsed = mock('parsed')
      parsed.stubs(:parameters).returns(nil)
      parsed.stubs(:to_s).returns('Base prompt.')
      @prompt_handler.stubs(:fetch_prompt).with('prompt1').returns(parsed)

      result = build_orchestrator.send(:build_prompt_text, 'prompt1', @config)
      assert_match(/Base prompt\./, result)
      assert_match(/Be an expert\./, result)
    end
  end

  def test_build_prompt_text_skips_skills_in_chat_mode
    Dir.mktmpdir do |skills_base|
      skill_dir = File.join(skills_base, 'expert')
      FileUtils.mkdir_p(skill_dir)
      File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: Expert\n---\nBe an expert.")

      @config.flags.chat = true
      @config.prompts.skills = ['expert']
      @config.skills = OpenStruct.new(dir: skills_base)

      orchestrator = build_orchestrator

      # Access build_prompt_text via send to inspect return value
      parsed = mock('parsed')
      parsed.stubs(:parameters).returns(nil)
      parsed.stubs(:to_s).returns('Base prompt.')
      @prompt_handler.stubs(:fetch_prompt).with('prompt1').returns(parsed)

      result = orchestrator.send(:build_prompt_text, 'prompt1', @config)
      refute_match(/Be an expert/, result)
      assert_match(/Base prompt/, result)
    end
  end

  def test_build_prompt_text_no_skills_configured
    @config.prompts.skills = []
    @config.skills = OpenStruct.new(dir: Dir.mktmpdir)

    orchestrator = build_orchestrator

    parsed = mock('parsed')
    parsed.stubs(:parameters).returns(nil)
    parsed.stubs(:to_s).returns('Just the prompt.')
    @prompt_handler.stubs(:fetch_prompt).with('prompt1').returns(parsed)

    result = orchestrator.send(:build_prompt_text, 'prompt1', @config)
    assert_equal 'Just the prompt.', result
  end

  private

  def stub_prompt
    parsed = mock('parsed')
    parsed.stubs(:parameters).returns(nil)
    parsed.stubs(:to_s).returns("prompt text")
    @prompt_handler.stubs(:fetch_prompt).returns(parsed)
  end

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
