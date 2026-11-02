# frozen_string_literal: true

require_relative '../test_helper'

class ToolApproverTest < Minitest::Test
  ToolCall = Struct.new(:name, :arguments)

  # A spinner double that records pause/resume.
  class FakeSpinner
    attr_reader :events

    def initialize(spinning: true)
      @spinning = spinning
      @events   = []
    end

    def spinning? = @spinning
    def pause     = (@events << :pause)
    def resume    = (@events << :resume)
  end

  def teardown
    AIA::ToolApprover.spinner = nil
  end

  def approver(answers = '', mode: 'ask', interactive: true)
    @output = StringIO.new
    AIA::ToolApprover.new(mode: mode, input: StringIO.new(answers), output: @output, interactive: interactive)
  end

  def form_request(properties, required: [])
    RubyLLM::MCP::InputRequest.new('k1', { 'message' => 'Need details',
                                           'requestedSchema' => { 'properties' => properties, 'required' => required } })
  end

  def url_request
    RubyLLM::MCP::InputRequest.new('k2', { 'message' => 'Connect account', 'mode' => 'url',
                                           'url' => 'https://example.com/connect' })
  end

  def config_with(approval)
    Struct.new(:tools).new(Struct.new(:approval).new(approval))
  end

  # ── mode and options ─────────────────────────────────────────────────────

  def test_mode_for_defaults_to_ask
    assert_equal 'ask', AIA::ToolApprover.mode_for(config_with(nil))
    assert_equal 'ask', AIA::ToolApprover.mode_for(nil)
  end

  def test_mode_for_config_without_tools_section_defaults_to_ask
    assert_equal 'ask', AIA::ToolApprover.mode_for(Object.new)
  end

  def test_mode_for_normalizes_case
    assert_equal 'approve', AIA::ToolApprover.mode_for(config_with(' Approve '))
  end

  def test_mode_for_unknown_value_falls_back_to_ask
    assert_equal 'ask', AIA::ToolApprover.mode_for(config_with('sometimes'))
  end

  def test_ask_options_install_both_callbacks_and_deny_fallback
    opts = approver.options
    assert_equal :deny, opts[:tool_approval]
    assert_respond_to opts[:on_tool_approval], :call
    assert_respond_to opts[:on_input_request], :call
  end

  def test_approve_options_allow_all_and_still_answer_input
    opts = approver(mode: 'approve').options
    assert_equal :approve, opts[:tool_approval]
    refute opts.key?(:on_tool_approval)
    assert_respond_to opts[:on_input_request], :call
  end

  def test_deny_options_refuse_everything
    assert_equal({ tool_approval: :deny }, approver(mode: 'deny').options)
  end

  def test_options_are_accepted_by_robot_lab_run_config
    config = RobotLab::RunConfig.new(**approver.options)
    assert_equal :deny, config.tool_approval
    refute_nil config.on_tool_approval
  end

  # ── tool approval ────────────────────────────────────────────────────────

  def test_approve_on_yes
    assert approver("y\n").approve?(ToolCall.new('delete_thing', { 'id' => '42' }))
    assert_includes @output.string, "Tool 'delete_thing' requires approval."
    assert_includes @output.string, 'id="42"'
  end

  def test_deny_on_anything_but_yes
    refute approver("\n").approve?(ToolCall.new('delete_thing', {}))
    refute approver("nope\n").approve?(ToolCall.new('delete_thing', {}))
  end

  def test_deny_without_a_terminal
    refute approver("y\n", interactive: false).approve?(ToolCall.new('delete_thing', {}))
    assert_includes @output.string, 'no terminal'
  end

  def test_spinner_is_paused_and_resumed_around_the_prompt
    spinner = FakeSpinner.new
    AIA::ToolApprover.spinner = spinner
    approver("y\n").approve?(ToolCall.new('x', {}))
    assert_equal %i[pause resume], spinner.events
  end

  def test_stopped_spinner_is_left_alone
    spinner = FakeSpinner.new(spinning: false)
    AIA::ToolApprover.spinner = spinner
    approver("y\n").approve?(ToolCall.new('x', {}))
    assert_empty spinner.events
  end

  def test_long_arguments_are_truncated
    approver("n\n").approve?(ToolCall.new('x', { 'blob' => 'a' * 500 }))
    assert_includes @output.string, '...'
  end

  # ── input requests ───────────────────────────────────────────────────────

  def test_url_request_accepted_on_yes
    assert_equal true, approver("y\n").answer_input(url_request)
    assert_includes @output.string, 'https://example.com/connect'
  end

  def test_url_request_declined_otherwise
    assert_nil approver("\n").answer_input(url_request)
  end

  def test_form_values_are_typed
    request = form_request({ 'env' => { 'type' => 'string' }, 'count' => { 'type' => 'integer' },
                             'ratio' => { 'type' => 'number' }, 'force' => { 'type' => 'boolean' } })
    answer = approver("staging\n3\n0.5\nyes\n").answer_input(request)
    assert_equal({ env: 'staging', count: 3, ratio: 0.5, force: true }, answer)
  end

  def test_invalid_value_is_asked_again
    request = form_request({ 'count' => { 'type' => 'integer' } })
    assert_equal({ count: 7 }, approver("seven\n7\n").answer_input(request))
    assert_includes @output.string, "'seven' is not a valid integer"
  end

  def test_choices_must_match
    request = form_request({ 'env' => { 'type' => 'string', 'enum' => %w[dev prod] } })
    assert_equal({ env: 'prod' }, approver("qa\nprod\n").answer_input(request))
  end

  def test_blank_optional_field_keeps_the_default
    request = form_request({ 'env' => { 'type' => 'string', 'default' => 'dev' } }, required: ['env'])
    assert_equal({}, approver("\n").answer_input(request))
  end

  def test_blank_required_field_without_default_declines
    request = form_request({ 'env' => { 'type' => 'string' } }, required: ['env'])
    assert_nil approver("\n").answer_input(request)
  end

  def test_input_request_declined_without_a_terminal
    assert_nil approver('', interactive: false).answer_input(url_request)
  end

  # ── wiring ───────────────────────────────────────────────────────────────

  def test_cli_flag_maps_to_tools_approval
    assert_equal %i[tools approval], AIA::Config::CLI_TO_NESTED_MAP[:tool_approval]
  end
end
