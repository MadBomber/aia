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
    # @param tool [Object] a tool instance or RubyLLM::Tool class
    # @return [String] the name the model calls it by (see ToolIntrospection.tool_name)
    def tool_name(tool)
      String(ToolIntrospection.tool_name(tool)).strip
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
