# frozen_string_literal: true

# test/aia/task_board_speech_test.rb
#
# Group G fixes: TrakFlow starts on first use, the speak path plays through
# a configurable audio player, and the completion scripts find prompts
# without AIA_PROMPTS__DIR.

require_relative '../test_helper'

class TaskBoardTest < Minitest::Test
  def setup
    @saved = AIA.instance_variable_get(:@task_coordinator)
    AIA.instance_variable_set(:@task_coordinator, nil)
  end

  def teardown
    AIA.instance_variable_set(:@task_coordinator, @saved)
  end

  def test_ensure_project_is_false_without_the_gem
    AIA::TaskBoard.stubs(:gem_available?).returns(false)
    FileUtils.expects(:mkdir_p).never

    refute AIA::TaskBoard.ensure_project!
  end

  def test_ensure_project_leaves_an_existing_project_alone
    TrakFlow.stubs(:initialized?).returns(true)
    FileUtils.expects(:mkdir_p).never

    assert AIA::TaskBoard.ensure_project!
  end

  def test_ensure_project_creates_the_project_on_first_use
    TrakFlow.stubs(:initialized?).returns(false).then.returns(true)
    TrakFlow.stubs(:trak_flow_dir).returns("/work/.trak_flow")
    FileUtils.expects(:mkdir_p).with("/work/.trak_flow")
    db = mock('database')
    db.expects(:connect)
    TrakFlow::Storage::Database.stubs(:new).returns(db)
    TrakFlow.expects(:reset_root!)

    assert AIA::TaskBoard.ensure_project!
  end

  def test_ensure_project_reports_failures_and_returns_false
    TrakFlow.stubs(:initialized?).returns(false)
    TrakFlow.stubs(:trak_flow_dir).raises(StandardError, "read-only")
    AIA.expects(:debug_warn).with(regexp_matches(/TrakFlow/), has_key(:exc))

    refute AIA::TaskBoard.ensure_project!
  end

  def test_coordinator_is_nil_when_the_project_cannot_start
    AIA::TaskBoard.stubs(:ensure_project!).returns(false)
    AIA::TaskCoordinator.expects(:new).never

    assert_nil AIA::TaskBoard.coordinator
  end

  def test_coordinator_does_not_clear_prior_work
    AIA::TaskBoard.stubs(:ensure_project!).returns(true)
    tc = mock('task_coordinator')
    tc.expects(:clear!).never
    AIA::TaskCoordinator.stubs(:new).returns(tc)

    assert_same tc, AIA::TaskBoard.coordinator
  end

  def test_coordinator_failure_logs_debug_warn
    AIA::TaskBoard.stubs(:ensure_project!).returns(true)
    AIA::TaskCoordinator.stubs(:new).raises(StandardError, "db error")
    AIA.expects(:debug_warn).with(regexp_matches(/TaskCoordinator/), has_key(:exc))

    assert_nil AIA::TaskBoard.coordinator
  end

  def test_aia_task_coordinator_is_built_once_on_first_use
    tc = Object.new
    AIA::TaskBoard.expects(:coordinator).once.returns(tc)

    assert_same tc, AIA.task_coordinator
    assert_same tc, AIA.task_coordinator
  end
end

class SpeechPlayerTest < Minitest::Test
  def setup
    @audio = OpenStruct.new(player: nil, speak_command: 'tts-script', speech_model: nil, voice: nil)
    AIA.stubs(:config).returns(OpenStruct.new(audio: @audio))
  end

  def test_player_command_splits_a_configured_player
    assert_equal ['mpv', '--no-video', 'a b'], AIA::Speech.player_command("mpv --no-video 'a b'")
  end

  def test_player_command_falls_back_to_the_first_player_on_the_path
    AIA::Speech.stubs(:on_path?).returns(false)
    AIA::Speech.stubs(:on_path?).with('mpv').returns(true)

    assert_equal %w[mpv --no-video --really-quiet], AIA::Speech.player_command(nil)
  end

  def test_player_command_is_nil_when_no_player_is_found
    AIA::Speech.stubs(:on_path?).returns(false)

    assert_nil AIA::Speech.player_command('  ')
  end

  def test_play_uses_the_configured_player
    @audio.player = 'mpg123 -q'
    AIA::Speech.stubs(:run_with_spinner).yields
    AIA::Speech.expects(:system).with('mpg123', '-q', '/tmp/x.mp3')

    AIA::Speech.play('/tmp/x.mp3')
  end

  def test_play_warns_when_no_player_is_found
    AIA::Speech.stubs(:on_path?).returns(false)
    AIA::Speech.expects(:system).never

    _, err = capture_io { AIA::Speech.play('/tmp/x.mp3') }

    assert_includes err, 'audio.player'
  end

  # ENV is Ractor-shareable, so mocha cannot stub it on Ruby 4.1+: swap
  # PATH for real and put it back.
  def test_on_path_finds_an_executable
    Dir.mktmpdir do |dir|
      exe = File.join(dir, 'fakeplayer')
      File.write(exe, "#!/bin/sh\n")
      File.chmod(0o755, exe)

      with_path(dir) do
        assert AIA::Speech.on_path?('fakeplayer')
        refute AIA::Speech.on_path?('nosuchplayer')
      end
    end
  end

  private

  def with_path(path)
    saved = ENV.fetch('PATH', nil)
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = saved
  end
end

class CompletionScriptFallbackTest < Minitest::Test
  SCRIPTS = Dir[File.expand_path('../../lib/aia/aia_completion.*', __dir__)]

  def test_every_completion_script_falls_back_to_dot_prompts
    refute_empty SCRIPTS

    SCRIPTS.each do |path|
      assert_includes File.read(path), '.prompts', "#{File.basename(path)} has no ~/.prompts fallback"
    end
  end
end
