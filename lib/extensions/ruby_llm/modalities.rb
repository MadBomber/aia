# lib/extensions/ruby_llm/modalities.rb
# A models "modes" are often expressed in terms like:
#   text-to-text
#   text_to_audio
#   audio to image
#   image2image
# This new supports? method tests the models modalities against
# these common expressions

class RubyLLM::Model::Modalities
  def supports?(query_mode)
    parts = query_mode
              .to_s
              .downcase
              .split(/2|-to-| to |_to_/)
              .map(&:strip)

    if 2 == parts.size
      input.include?(parts[0]) && output.include?(parts[1])
    elsif 1 == parts.size
      input.include?(parts[0]) || output.include?(parts[0])
    else
      false
    end
  end
end
