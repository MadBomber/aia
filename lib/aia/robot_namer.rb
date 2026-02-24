# frozen_string_literal: true

# lib/aia/robot_namer.rb
#
# Generates memorable one-word names for robots based on their model.
# Used instead of technical names like "aia-claude-sonnet-4".

module AIA
  class RobotNamer
    # Curated names for known model patterns (matched in order, first wins)
    MODEL_NAMES = [
      # Claude family
      [/claude.*opus.*4/i,      'Virtuoso'],
      [/claude.*opus/i,         'Maestro'],
      [/claude.*sonnet.*4/i,    'Lyric'],
      [/claude.*sonnet.*3\.5/i, 'Muse'],
      [/claude.*sonnet/i,       'Poet'],
      [/claude.*haiku/i,        'Zen'],

      # GPT family
      [/gpt-4\.1/i,             'Vanguard'],
      [/gpt-4o-mini/i,          'Spark'],
      [/gpt-4o/i,               'Flash'],
      [/gpt-4-turbo/i,          'Bolt'],
      [/gpt-4/i,                'Titan'],
      [/gpt-3.*turbo/i,         'Dash'],
      [/gpt-5-nano/i,           'Mote'],
      [/gpt-5-mini/i,           'Flare'],
      [/gpt-5/i,                'Apex'],
      [/o1-mini/i,              'Ponder'],
      [/o1-pro/i,               'Scholar'],
      [/o1\b/i,                 'Thinker'],
      [/o3-mini/i,              'Deduce'],
      [/o3\b/i,                 'Reason'],
      [/o4-mini/i,              'Nimble'],

      # Google
      [/gemini.*flash/i,        'Prism'],
      [/gemini.*pro/i,          'Atlas'],
      [/gemini/i,               'Twin'],

      # Open source / local
      [/llama/i,                'Sherpa'],
      [/mistral.*large/i,       'Cyclone'],
      [/mistral/i,              'Gale'],
      [/mixtral/i,              'Tempest'],
      [/phi/i,                  'Quark'],
      [/qwen/i,                 'Jade'],
      [/deepseek.*coder/i,      'Cipher'],
      [/deepseek/i,             'Diver'],
      [/codestral/i,            'Rune'],
      [/command.*r\+/i,         'Admiral'],
      [/command/i,              'Captain'],
      [/falcon/i,               'Talon'],
      [/vicuna/i,               'Voyager'],
      [/yi\b/i,                 'Sage'],
      [/starcoder/i,            'Nova'],
      [/granite/i,              'Monolith'],
      [/solar/i,                'Corona'],
      [/orca/i,                 'Tide'],
      [/wizard/i,               'Merlin'],
      [/dolphin/i,              'Reef'],
      [/nous/i,                 'Oracle'],
      [/stable/i,               'Anchor'],
      [/gemma/i,                'Jewel'],
    ].freeze

    # Fallback pool for unrecognized models — deterministically
    # selected by hashing the model name
    FALLBACK_NAMES = %w[
      Beacon  Drift   Echo    Fable   Glimmer Halo    Iris
      Kindle  Lumen   Mirth   Nexus   Orbit   Pixel   Quill
      Ripple  Sentry  Trace   Unity   Vault   Wisp    Zephyr
      Ember   Frost   Crest   Flint   Haze    Slate   Plume
      Comet   Aura    Blaze   Dusk    Flux    Helix   Onyx
    ].freeze

    def initialize
      @used_names = {}
    end

    def name_for(model_name)
      model_name = model_name.to_s
      base = find_base_name(model_name)
      unique_name(base)
    end

    private

    def find_base_name(model_name)
      MODEL_NAMES.each do |pattern, name|
        return name if model_name.match?(pattern)
      end

      # Deterministic fallback based on model name
      index = model_name.bytes.sum % FALLBACK_NAMES.size
      FALLBACK_NAMES[index]
    end

    def unique_name(base)
      @used_names[base] ||= 0
      @used_names[base] += 1

      if @used_names[base] == 1
        base
      else
        "#{base}#{@used_names[base]}"
      end
    end
  end
end
