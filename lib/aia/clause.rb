# aia/lib/aia/clause.rb

module AIA
  #
  # The Clause module consists of text constants used to augment prompt text.
  #
  # This module provides predefined phrases that can be utilized in various
  # prompts or responses within the AIA system.
  #
  module Clause
    Terse     = 'Be terse in your response.'
    Verbose   = 'Be verbose in your response.'
    #
    Markdown  = 'Format your response using markdown.'
    #
    Software  = 'Your response should consist of only programming language source code.  Do not wrap it in a formatting block.'
  end
end
