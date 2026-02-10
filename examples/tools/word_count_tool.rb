# frozen_string_literal: true

require 'ruby_llm/tool'

# A simple tool that counts words, characters, and lines in text.
class WordCountTool < RubyLLM::Tool
  def self.name = 'word_count'

  description <<~'DESC'
    Count words, characters, lines, and sentences in a given text.
    Useful for text analysis and content length checks.
  DESC

  params do
    string :text, description: 'The text to analyze', required: true
  end

  def execute(text:)
    words      = text.split(/\s+/).reject(&:empty?)
    sentences  = text.split(/[.!?]+/).reject { |s| s.strip.empty? }

    {
      success:    true,
      words:      words.size,
      characters: text.length,
      lines:      text.lines.size,
      sentences:  sentences.size
    }
  end
end
