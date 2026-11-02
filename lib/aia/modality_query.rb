# frozen_string_literal: true

# lib/aia/modality_query.rb
#
# Matches a model's input/output modalities against an "INPUT_to_OUTPUT"
# search term such as "text_to_image" (as used by --available-models and
# /available_models). RubyLLM 2.x exposes modalities as plain input/output
# lists, so the term is split and each side is looked up in its list.

module AIA
  module ModalityQuery
    SEPARATOR = '_to_'

    module_function

    # @param term [String]
    # @return [Boolean] true when +term+ has the INPUT_to_OUTPUT form
    def modality_term?(term)
      term.to_s.include?(SEPARATOR)
    end

    # @param modalities [#input, #output] a model's modalities
    # @param term [String] e.g. "text_to_image" or ":image_to_text"
    # @return [Boolean]
    def matches?(modalities, term)
      input, output = term.to_s.delete_prefix(':').downcase.split(SEPARATOR, 2)
      return false if input.to_s.empty? || output.to_s.empty?

      names(modalities.input).include?(input) && names(modalities.output).include?(output)
    end

    def names(list)
      Array(list).map { it.to_s.downcase }
    end
  end
end
