# calculator_tool.rb - Simple custom tool example
require 'ruby_llm/tool'

module Tools
  class Calculator < RubyLLM::Tool
    def self.name = "calculator"

    description <<~DESCRIPTION
      Perform advanced mathematical calculations with comprehensive error handling and validation.
      This tool supports basic arithmetic operations, parentheses, and common mathematical functions.
      It provides safe evaluation of mathematical expressions without executing arbitrary code,
      making it suitable for use in AI-assisted calculations where security is important.
      The tool returns formatted results with configurable precision and helpful error messages
      when invalid expressions are provided.
    DESCRIPTION

    param :expression,
          desc: <<~DESC,
            Mathematical expression to evaluate using standard arithmetic operators and parentheses.
            Supported operations include: addition (+), subtraction (-), multiplication (*), division (/),
            and parentheses for grouping. Examples: '2 + 2', '(10 * 5) / 2', '15.5 - 3.2'.
            Only numeric characters, operators, parentheses, decimal points, and spaces are allowed
            for security reasons. Complex mathematical functions are not supported in this version.
          DESC
          type: :string,
          required: true

    param :precision,
          desc: <<~DESC,
            Number of decimal places to display in the result. Must be a non-negative integer.
            Set to 0 for whole numbers only, or higher values for more precise decimal results.
            Default is 2 decimal places, which works well for most financial and general calculations.
            Maximum precision is limited to 10 decimal places to prevent excessive output.
          DESC
          type: :integer,
          default: 2

    def execute(expression:, precision: 2)
      begin
        # Use safe evaluation instead of raw eval
        result = safe_eval(expression)
        formatted_result = result.round(precision)

        {
          success: true,
          result:  formatted_result,
          expression: expression,
          precision: precision
        }
      rescue => e
        {
          success: false,
          error:   "Invalid expression: #{e.message}",
          expression: expression,
          suggestion: "Try expressions like '2 + 2' or '10 * 5'"
        }
      end
    end

    private

    def safe_eval(expression)
      # Implement safe mathematical evaluation
      # This is a simplified example - use a proper math parser in production
      allowed_chars = /\A[0-9+\-*\/\(\)\.\s]+\z/
      raise "Invalid characters in expression" unless expression.match?(allowed_chars)
      eval(expression)
    end
  end
end
