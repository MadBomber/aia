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

    AIA::LLMErrorCollector.reset!
    AIA::LLMErrorCollector.stubs(:install!)
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

  # --- special modes a prompt directive requests (/debate, /verify, ...) ---

  def test_run_step_hands_a_requested_mode_to_the_special_mode_handler
    stub_prompt
    AIA.turn_state.request(:debate)
    handler = mock('special_mode_handler')
    handler.expects(:robot=).with { it.equal?(@robot) }
    handler.expects(:handle).with('prompt text').returns(true)
    AIA::SpecialModeHandler.stubs(:new).returns(handler)
    @robot.expects(:run).never
    @tracker.expects(:record_turn).never # the handler records the turn itself
    bridge = mock('bridge')
    steps = sequence('steps')
    bridge.expects(:update_step_status).with('prompt1', :started).in_sequence(steps)
    bridge.expects(:update_step_status).with('prompt1', :completed).in_sequence(steps)

    build_orchestrator.send(:run_step, 'prompt1', @config, bridge)
  end

  def test_run_step_runs_normally_when_the_handler_declines
    stub_prompt
    AIA.turn_state.request(:debate)
    handler = mock('special_mode_handler')
    handler.stubs(:robot=)
    handler.expects(:handle).with('prompt text').returns(false)
    AIA::SpecialModeHandler.stubs(:new).returns(handler)
    @robot.expects(:run).once.returns(OpenStruct.new(reply: 'AI response'))
    @tracker.expects(:record_turn).once

    build_orchestrator.send(:run_step, 'prompt1', @config, nil)
  end

  def test_run_step_leaves_concurrent_mcp_to_execute_prompt
    stub_prompt
    AIA.turn_state.request(:concurrent_mcp)
    AIA::SpecialModeHandler.expects(:new).never
    @robot.expects(:run).once.returns(OpenStruct.new(reply: 'AI response'))

    build_orchestrator.send(:run_step, 'prompt1', @config, nil)
  end

  def test_run_step_ignores_special_modes_when_painting
    stub_prompt
    AIA.turn_state.request(:debate)
    AIA.stubs(:paint?).returns(true)
    AIA::SpecialModeHandler.expects(:new).never
    orchestrator = build_orchestrator
    orchestrator.stubs(:compute_result).returns([OpenStruct.new(reply: 'x'), 'Image saved to out.png'])

    orchestrator.send(:run_step, 'prompt1', @config, nil)
  end

  # --- LLM errors robot_lab shielded into reply text ---

  def test_process_installs_the_llm_error_collector
    @config.pipeline = []
    AIA::LLMErrorCollector.unstub(:install!)
    AIA::LLMErrorCollector.expects(:install!).once

    build_orchestrator.process(@config)
  end

  def test_run_step_raises_llm_error_outside_chat_when_a_robot_failed
    stub_prompt
    AIA.stubs(:chat?).returns(false)
    robot_run_records_llm_error
    @tracker.expects(:record_turn).never
    @ui.expects(:display_ai_response).never
    bridge = mock('bridge')
    steps = sequence('steps')
    bridge.expects(:update_step_status).with('prompt1', :started).in_sequence(steps)
    bridge.expects(:update_step_status).with('prompt1', :failed, reason: regexp_matches(/invalid x-api-key/)).in_sequence(steps)

    error = assert_raises(AIA::LLMError) { build_orchestrator.send(:run_step, 'prompt1', @config, bridge) }

    assert_equal "LLM error in prompt 'prompt1': Tobor: RuntimeError: invalid x-api-key", error.message
  end

  def test_run_step_shows_the_error_and_carries_on_in_chat
    stub_prompt
    AIA.stubs(:chat?).returns(true)
    robot_run_records_llm_error
    @tracker.expects(:record_turn).never
    @ui.expects(:display_ai_response).never
    @ui.expects(:display_info).with("LLM error in prompt 'prompt1': Tobor: RuntimeError: invalid x-api-key")
    bridge = mock('bridge')
    bridge.expects(:update_step_status).with('prompt1', :started)
    bridge.expects(:update_step_status).with('prompt1', :failed, reason: regexp_matches(/invalid x-api-key/))

    build_orchestrator.send(:run_step, 'prompt1', @config, bridge)
  end

  def test_run_step_forgets_the_previous_steps_errors
    stub_prompt
    AIA.stubs(:chat?).returns(false)
    AIA::LLMErrorCollector.on_error(Struct.new(:robot, :error).new(nil, RuntimeError.new('stale')))

    build_orchestrator.send(:run_step, 'prompt1', @config, nil)

    refute AIA::LLMErrorCollector.errors?
  end

  def test_run_step_raises_llm_error_when_a_special_mode_robot_failed_outside_chat
    stub_prompt
    AIA.stubs(:chat?).returns(false)
    AIA.turn_state.request(:debate)
    handler = mock('special_mode_handler')
    handler.stubs(:robot=)
    handler.expects(:handle).with('prompt text').returns(true)
    AIA::SpecialModeHandler.stubs(:new).returns(handler)
    @robot.expects(:run).never
    AIA::LLMErrorCollector.stubs(:reset!) # keep the error below as if the debate had raised it
    record_llm_error

    assert_raises(AIA::LLMError) { build_orchestrator.send(:run_step, 'prompt1', @config, nil) }
  end

  # --- generate_image -------------------------------------------------------
  # ruby_llm 2.1 takes extra image options as provider_options:, not params:.

  def test_generate_image_passes_quality_and_style_as_provider_options
    @config.image = OpenStruct.new(model: nil, size: nil, quality: 'hd', style: 'vivid')
    image = stub(url: 'https://img/1.png')
    @ui.stubs(:with_spinner).yields.returns(image)
    RubyLLM.expects(:paint)
           .with('a cat', model: 'gpt-image-1', size: '1024x1024', provider_options: { quality: 'hd', style: 'vivid' })
           .returns(image)

    assert_equal 'https://img/1.png', build_orchestrator.send(:generate_image, 'a cat', @config)
  end

  def test_generate_image_omits_blank_quality_and_style
    @config.image = OpenStruct.new(model: 'dall-e-3', size: '512x512', quality: nil, style: '  ')
    image = stub(url: nil)
    @ui.stubs(:with_spinner).yields.returns(image)
    RubyLLM.expects(:paint)
           .with('a cat', model: 'dall-e-3', size: '512x512', provider_options: {})
           .returns(image)

    assert_equal '(image returned no URL)', build_orchestrator.send(:generate_image, 'a cat', @config)
  end

  def test_generate_image_saves_to_the_output_file_as_png
    @config.image = OpenStruct.new(model: nil, size: nil, quality: nil, style: nil)
    @config.output.file = '/tmp/out.md'
    image = mock('image')
    @ui.stubs(:with_spinner).yields.returns(image)
    image.expects(:save).with('/tmp/out.png')
    RubyLLM.stubs(:paint).returns(image)

    assert_equal 'Image saved to: /tmp/out.png', build_orchestrator.send(:generate_image, 'a cat', @config)
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
  # A robot whose run fails the way robot_lab reports it: the on_error hook
  # fires, then the exception is shielded into an "Error:" reply.
  FailingRobot = Struct.new(:on_error) do
    def run(*, **)
      on_error.call
      OpenStruct.new(reply: 'Error: RuntimeError: invalid x-api-key')
    end
  end

  def robot_run_records_llm_error
    @robot = FailingRobot.new(method(:record_llm_error))
  end

  def record_llm_error
    ctx = Struct.new(:robot, :error).new(Struct.new(:name).new('Tobor'), RuntimeError.new('invalid x-api-key'))
    AIA::LLMErrorCollector.on_error(ctx)
  end
end
