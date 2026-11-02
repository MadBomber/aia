# frozen_string_literal: true

# lib/aia/config/value_caster.rb
#
# Environment variables (AIA_*) and `/config KEY VALUE` arrive as strings.
# ValueCaster converts such a string to the type of the key's default in
# defaults.yml: booleans, integers, floats and comma-separated lists. Keys
# whose default is nil carry no type, so UNTYPED_DEFAULTS supplies one.
# Values that are not strings, or that don't parse, are returned unchanged.

module AIA
  module ValueCaster
    TRUE_WORDS  = %w[true yes on 1].freeze
    FALSE_WORDS = %w[false no off 0].freeze

    # Type samples for keys whose default is nil (dotted path => sample value)
    UNTYPED_DEFAULTS = {
      'llm.top_p'      => 0.0,
      'tools.allowed'  => [],
      'tools.rejected' => []
    }.freeze

    module_function

    # @param value [Object] the incoming value
    # @param default [Object] the key's default (its type is the target type)
    # @return [Object] the converted value, or +value+ when it can't be converted
    def cast(value, default)
      return value unless value.is_a?(String)

      case default
      when true, false then to_boolean(value)
      when Integer     then Integer(value.strip, 10, exception: false) || value
      when Float       then Float(value.strip, exception: false) || value
      when Array       then value.split(',').map(&:strip).reject(&:empty?)
      else value
      end
    end

    # @return [Boolean, String] true/false for a recognized word, else +value+
    def to_boolean(value)
      word = value.strip.downcase
      return true  if TRUE_WORDS.include?(word)
      return false if FALSE_WORDS.include?(word)

      value
    end

    # The default used to type +path+ ("section.key"): the schema value, or the
    # UNTYPED_DEFAULTS sample when the schema default is nil.
    def default_for(path, schema_default)
      schema_default.nil? ? UNTYPED_DEFAULTS[path] : schema_default
    end

    # Convert every string value in +section+ (a ConfigSection) in place,
    # recursing into nested sections.
    #
    # @param section [#[], #[]=] the section to convert
    # @param defaults [Hash] the section's defaults (symbol keys)
    # @param prefix [String] dotted path of the section, e.g. "llm"
    # @return [void]
    def cast_section!(section, defaults, prefix)
      return unless section && defaults.is_a?(Hash)

      defaults.each do |key, schema_default|
        path  = "#{prefix}.#{key}"
        value = section[key]
        if schema_default.is_a?(Hash) && !schema_default.empty?
          cast_section!(value, schema_default, path)
        else
          section[key] = cast(value, default_for(path, schema_default))
        end
      end
    end
  end
end
