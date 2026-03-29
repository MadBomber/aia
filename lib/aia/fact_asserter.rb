# frozen_string_literal: true

# lib/aia/fact_asserter.rb
#
# Thin adapter that extracts tool_name and tool_description from a tool object.
# Replaces the KBS FactAsserter with a plain Ruby implementation that reads
# the standard .name and .description interface common to all AIA tool objects.

module AIA
  class FactAsserter
    # Extract the tool's name as a non-nil String.
    #
    # @param tool [Object] any object that responds to .name
    # @return [String]
    def tool_name(tool)
      String(tool.respond_to?(:name) ? tool.name : "").strip
    end

    # Extract the tool's description as a non-nil String.
    #
    # @param tool [Object] any object that responds to .description
    # @return [String]
    def tool_description(tool)
      String(tool.respond_to?(:description) ? tool.description : "").strip
    end
  end
end
