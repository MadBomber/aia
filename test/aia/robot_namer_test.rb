# frozen_string_literal: true

require_relative '../test_helper'

class RobotNamerTest < Minitest::Test
  # First robot naming: first_name takes precedence
  def test_first_name_used_for_first_robot
    namer = AIA::RobotNamer.new(first_name: 'Tobor')
    assert_equal 'Tobor', namer.name_for('any-model')
  end

  # After first_name is exhausted, model patterns are used
  def test_second_robot_uses_model_based_name
    namer = AIA::RobotNamer.new(first_name: 'Tobor')
    namer.name_for('claude-sonnet-4')  # consumes Tobor
    second = namer.name_for('claude-sonnet-4')
    assert_equal 'Lyric', second
  end

  # Without first_name, model patterns are used immediately
  def test_no_first_name_uses_model_immediately
    namer = AIA::RobotNamer.new
    assert_equal 'Flash', namer.name_for('gpt-4o')
  end

  # Claude Opus 3 models
  def test_claude_opus_maps_to_maestro
    namer = AIA::RobotNamer.new
    assert_equal 'Maestro', namer.name_for('claude-opus-3')
  end

  def test_claude_opus_3_5_maps_to_maestro
    namer = AIA::RobotNamer.new
    assert_equal 'Maestro', namer.name_for('claude-opus-3-5')
  end

  # Claude Opus 4 models (highest tier)
  def test_claude_opus_4_maps_to_virtuoso
    namer = AIA::RobotNamer.new
    assert_equal 'Virtuoso', namer.name_for('claude-opus-4-5')
  end

  def test_claude_opus_4_0_maps_to_virtuoso
    namer = AIA::RobotNamer.new
    assert_equal 'Virtuoso', namer.name_for('claude-opus-4-0')
  end

  # Claude Sonnet models
  def test_claude_sonnet_4_maps_to_lyric
    namer = AIA::RobotNamer.new
    assert_equal 'Lyric', namer.name_for('claude-sonnet-4')
  end

  def test_claude_sonnet_3_5_maps_to_muse
    namer = AIA::RobotNamer.new
    assert_equal 'Muse', namer.name_for('claude-sonnet-3.5')
  end

  def test_claude_sonnet_3_maps_to_poet
    namer = AIA::RobotNamer.new
    assert_equal 'Poet', namer.name_for('claude-sonnet-3')
  end

  # Claude Haiku
  def test_claude_haiku_maps_to_zen
    namer = AIA::RobotNamer.new
    assert_equal 'Zen', namer.name_for('claude-haiku')
  end

  # GPT-4 family
  def test_gpt4_turbo_maps_to_bolt
    namer = AIA::RobotNamer.new
    assert_equal 'Bolt', namer.name_for('gpt-4-turbo')
  end

  def test_gpt4_1_maps_to_vanguard
    namer = AIA::RobotNamer.new
    assert_equal 'Vanguard', namer.name_for('gpt-4.1')
  end

  def test_gpt4_maps_to_titan
    namer = AIA::RobotNamer.new
    assert_equal 'Titan', namer.name_for('gpt-4')
  end

  # GPT-4o family
  def test_gpt4o_maps_to_flash
    namer = AIA::RobotNamer.new
    assert_equal 'Flash', namer.name_for('gpt-4o')
  end

  def test_gpt4o_mini_maps_to_spark
    namer = AIA::RobotNamer.new
    assert_equal 'Spark', namer.name_for('gpt-4o-mini')
  end

  # GPT-3 family
  def test_gpt3_turbo_maps_to_dash
    namer = AIA::RobotNamer.new
    assert_equal 'Dash', namer.name_for('gpt-3-turbo')
  end

  # GPT-5 family
  def test_gpt5_nano_maps_to_mote
    namer = AIA::RobotNamer.new
    assert_equal 'Mote', namer.name_for('gpt-5-nano')
  end

  def test_gpt5_mini_maps_to_flare
    namer = AIA::RobotNamer.new
    assert_equal 'Flare', namer.name_for('gpt-5-mini')
  end

  def test_gpt5_maps_to_apex
    namer = AIA::RobotNamer.new
    assert_equal 'Apex', namer.name_for('gpt-5')
  end

  # o1 family
  def test_o1_mini_maps_to_ponder
    namer = AIA::RobotNamer.new
    assert_equal 'Ponder', namer.name_for('o1-mini')
  end

  def test_o1_pro_maps_to_scholar
    namer = AIA::RobotNamer.new
    assert_equal 'Scholar', namer.name_for('o1-pro')
  end

  def test_o1_maps_to_thinker
    namer = AIA::RobotNamer.new
    assert_equal 'Thinker', namer.name_for('o1')
  end

  # o3 family
  def test_o3_mini_maps_to_deduce
    namer = AIA::RobotNamer.new
    assert_equal 'Deduce', namer.name_for('o3-mini')
  end

  def test_o3_maps_to_reason
    namer = AIA::RobotNamer.new
    assert_equal 'Reason', namer.name_for('o3')
  end

  # o4 family
  def test_o4_mini_maps_to_nimble
    namer = AIA::RobotNamer.new
    assert_equal 'Nimble', namer.name_for('o4-mini')
  end

  # Google Gemini family
  def test_gemini_flash_maps_to_prism
    namer = AIA::RobotNamer.new
    assert_equal 'Prism', namer.name_for('gemini-2.0-flash')
  end

  def test_gemini_flash_1_5_maps_to_prism
    namer = AIA::RobotNamer.new
    assert_equal 'Prism', namer.name_for('gemini-1.5-flash')
  end

  def test_gemini_pro_maps_to_atlas
    namer = AIA::RobotNamer.new
    assert_equal 'Atlas', namer.name_for('gemini-pro')
  end

  def test_gemini_maps_to_twin
    namer = AIA::RobotNamer.new
    assert_equal 'Twin', namer.name_for('gemini')
  end

  # Open source: Llama
  def test_llama_maps_to_sherpa
    namer = AIA::RobotNamer.new
    assert_equal 'Sherpa', namer.name_for('llama-2')
  end

  def test_llama_70b_maps_to_sherpa
    namer = AIA::RobotNamer.new
    assert_equal 'Sherpa', namer.name_for('llama-70b')
  end

  # Open source: Mistral family
  def test_mistral_large_maps_to_cyclone
    namer = AIA::RobotNamer.new
    assert_equal 'Cyclone', namer.name_for('mistral-large')
  end

  def test_mistral_maps_to_gale
    namer = AIA::RobotNamer.new
    assert_equal 'Gale', namer.name_for('mistral')
  end

  # Open source: Mixtral
  def test_mixtral_maps_to_tempest
    namer = AIA::RobotNamer.new
    assert_equal 'Tempest', namer.name_for('mixtral')
  end

  # Open source: Phi
  def test_phi_maps_to_quark
    namer = AIA::RobotNamer.new
    assert_equal 'Quark', namer.name_for('phi')
  end

  # Open source: Qwen
  def test_qwen_maps_to_jade
    namer = AIA::RobotNamer.new
    assert_equal 'Jade', namer.name_for('qwen')
  end

  # Open source: Deepseek
  def test_deepseek_coder_maps_to_cipher
    namer = AIA::RobotNamer.new
    assert_equal 'Cipher', namer.name_for('deepseek-coder')
  end

  def test_deepseek_maps_to_diver
    namer = AIA::RobotNamer.new
    assert_equal 'Diver', namer.name_for('deepseek')
  end

  # Open source: Codestral
  def test_codestral_maps_to_rune
    namer = AIA::RobotNamer.new
    assert_equal 'Rune', namer.name_for('codestral')
  end

  # Open source: Command family
  def test_command_r_plus_maps_to_admiral
    namer = AIA::RobotNamer.new
    assert_equal 'Admiral', namer.name_for('command-r+')
  end

  def test_command_maps_to_captain
    namer = AIA::RobotNamer.new
    assert_equal 'Captain', namer.name_for('command')
  end

  # Open source: Falcon
  def test_falcon_maps_to_talon
    namer = AIA::RobotNamer.new
    assert_equal 'Talon', namer.name_for('falcon')
  end

  # Open source: Vicuna
  def test_vicuna_maps_to_voyager
    namer = AIA::RobotNamer.new
    assert_equal 'Voyager', namer.name_for('vicuna')
  end

  # Open source: Yi
  def test_yi_maps_to_sage
    namer = AIA::RobotNamer.new
    assert_equal 'Sage', namer.name_for('yi')
  end

  # Open source: StarCoder
  def test_starcoder_maps_to_nova
    namer = AIA::RobotNamer.new
    assert_equal 'Nova', namer.name_for('starcoder')
  end

  # Open source: Granite
  def test_granite_maps_to_monolith
    namer = AIA::RobotNamer.new
    assert_equal 'Monolith', namer.name_for('granite')
  end

  # Open source: Solar
  def test_solar_maps_to_corona
    namer = AIA::RobotNamer.new
    assert_equal 'Corona', namer.name_for('solar')
  end

  # Open source: Orca
  def test_orca_maps_to_tide
    namer = AIA::RobotNamer.new
    assert_equal 'Tide', namer.name_for('orca')
  end

  # Open source: Wizard
  def test_wizard_maps_to_merlin
    namer = AIA::RobotNamer.new
    assert_equal 'Merlin', namer.name_for('wizard')
  end

  # Open source: Dolphin
  # NOTE: Due to regex ordering, dolphin matches /phi/i pattern before /dolphin/i,
  # so it maps to Quark. This is a known pattern collision in MODEL_NAMES.
  def test_dolphin_matches_phi_pattern_first
    namer = AIA::RobotNamer.new
    assert_equal 'Quark', namer.name_for('dolphin')
  end

  # Open source: Nous
  def test_nous_maps_to_oracle
    namer = AIA::RobotNamer.new
    assert_equal 'Oracle', namer.name_for('nous')
  end

  # Open source: Stable
  def test_stable_maps_to_anchor
    namer = AIA::RobotNamer.new
    assert_equal 'Anchor', namer.name_for('stable')
  end

  # Open source: Gemma
  def test_gemma_maps_to_jewel
    namer = AIA::RobotNamer.new
    assert_equal 'Jewel', namer.name_for('gemma')
  end

  # Fallback names: unknown models
  def test_unknown_model_gets_deterministic_fallback
    namer1 = AIA::RobotNamer.new
    namer2 = AIA::RobotNamer.new
    name1 = namer1.name_for('totally-unknown-xyz-123')
    name2 = namer2.name_for('totally-unknown-xyz-123')
    assert_equal name1, name2, "Same model produces same fallback name"
    assert AIA::RobotNamer::FALLBACK_NAMES.include?(name1), "Fallback must come from FALLBACK_NAMES"
  end

  def test_different_unknown_models_may_differ
    namer = AIA::RobotNamer.new
    name1 = namer.name_for('totally-unknown-model-a')
    name2 = namer.name_for('totally-unknown-model-b')
    # Different models may produce different fallback names (though collision is possible)
    assert AIA::RobotNamer::FALLBACK_NAMES.include?(name1)
    assert AIA::RobotNamer::FALLBACK_NAMES.include?(name2)
  end

  # Duplicate handling: appends counter
  def test_duplicate_model_appends_counter
    namer = AIA::RobotNamer.new
    first  = namer.name_for('gpt-4o')
    second = namer.name_for('gpt-4o')
    assert_equal 'Flash',  first
    assert_equal 'Flash2', second
  end

  def test_third_duplicate_increments_counter
    namer = AIA::RobotNamer.new
    namer.name_for('gpt-4o')
    namer.name_for('gpt-4o')
    third = namer.name_for('gpt-4o')
    assert_equal 'Flash3', third
  end

  def test_many_duplicates_increment_correctly
    namer = AIA::RobotNamer.new
    names = 5.times.map { namer.name_for('gpt-4o') }
    assert_equal ['Flash', 'Flash2', 'Flash3', 'Flash4', 'Flash5'], names
  end

  # Mixed scenario: first_name then duplicates
  def test_first_name_exhausted_second_call_uses_model
    namer = AIA::RobotNamer.new(first_name: 'Tobor')
    namer.name_for('gpt-4o')      # uses Tobor
    second = namer.name_for('gpt-4o')  # now uses model-based name
    assert_equal 'Flash', second
  end

  def test_first_name_exhausted_different_model_also_uses_model
    namer = AIA::RobotNamer.new(first_name: 'Tobor')
    namer.name_for('claude-sonnet-4')  # uses Tobor
    second = namer.name_for('gpt-4o')  # uses Flash (not Tobor again)
    assert_equal 'Flash', second
  end

  # Case insensitivity: patterns are case-insensitive
  def test_model_patterns_are_case_insensitive
    namer = AIA::RobotNamer.new
    assert_equal 'Flash', namer.name_for('GPT-4O')
    assert_equal 'Lyric', namer.name_for('CLAUDE-SONNET-4')
    assert_equal 'Maestro', namer.name_for('Claude-Opus')
  end

  # Model name as string or symbol
  def test_model_name_as_symbol
    namer = AIA::RobotNamer.new
    result = namer.name_for(:'gpt-4o')
    assert_equal 'Flash', result
  end

  # Edge case: empty string or nil (though not typical)
  def test_empty_model_name_gets_fallback
    namer = AIA::RobotNamer.new
    name = namer.name_for('')
    assert AIA::RobotNamer::FALLBACK_NAMES.include?(name)
  end

  # Verify FALLBACK_NAMES and MODEL_NAMES are frozen
  def test_fallback_names_is_frozen
    assert AIA::RobotNamer::FALLBACK_NAMES.frozen?
  end

  def test_model_names_is_frozen
    assert AIA::RobotNamer::MODEL_NAMES.frozen?
  end

  # Verify FALLBACK_NAMES contains expected names
  def test_fallback_names_contains_expected_values
    expected = ['Beacon', 'Drift', 'Echo', 'Fable', 'Glimmer']
    expected.each do |name|
      assert AIA::RobotNamer::FALLBACK_NAMES.include?(name), "FALLBACK_NAMES should include #{name}"
    end
  end
end
