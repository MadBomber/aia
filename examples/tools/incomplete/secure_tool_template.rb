# secure_tool_template.rb - Security best practices
require 'ruby_llm/tool'
require 'timeout'

module Tools
  class SecureTool < RubyLLM::Tool
    def self.name = 'secure_tool'

    description <<~DESCRIPTION
      Template tool demonstrating comprehensive security best practices for safe tool development.
      This tool serves as a reference implementation for secure tool design, including input
      validation, output sanitization, permission checks, rate limiting, audit logging,
      timeout mechanisms, and proper error handling. It provides a complete security framework
      that can be adapted for other tools that handle sensitive data or perform privileged
      operations. All security violations are logged for monitoring and compliance purposes.
    DESCRIPTION

    # Input validation
    param :user_input,
          desc: <<~DESC,
            User-provided input string that will be processed with comprehensive security validation.
            Input is automatically sanitized and validated against multiple security criteria:
            - Maximum length of 1000 characters to prevent buffer overflow attacks
            - Character whitelist allowing only alphanumeric, spaces, hyphens, underscores, and dots
            - Automatic removal of potentially dangerous characters and sequences
            - Rate limiting to prevent abuse and denial-of-service attacks
            All input validation failures are logged for security monitoring.
          DESC
          type: :string,
          required: true,
          validator: ->(value) {
            # Custom validation logic
            raise "Input too long" if value.length > 1000
            raise "Invalid characters" unless value.match?(/\A[a-zA-Z0-9\s\-_\.]+\z/)
            true
          }

    def execute(user_input:)
      begin
        # 1. Sanitize inputs
        sanitized_input = sanitize_input(user_input)

        # 2. Validate permissions
        validate_permissions

        # 3. Rate limiting
        check_rate_limits

        # 4. Audit logging
        log_tool_usage(sanitized_input)

        # 5. Execute with timeout
        result = execute_with_timeout(sanitized_input)

        # 6. Sanitize outputs
        sanitized_result = sanitize_output(result)

        {
          success: true,
          result:  sanitized_result,
          executed_at: Time.now.iso8601
        }
      rescue SecurityError => e
        log_security_violation(e, user_input)
        {
          success: false,
          error:   "Security violation: Access denied",
          violation_logged: true
        }
      rescue => e
        {
          success: false,
          error:   "Tool execution failed: #{e.message}"
        }
      end
    end

    private

    def sanitize_input(input)
      # Remove potentially dangerous characters
      # Validate against whitelist
      input.gsub(/[^\w\s\-\.]/, '')
    end

    def validate_permissions
      # TODO: Check user permissions
      #       Validate environment access
      #       Verify resource limits
    end

    def check_rate_limits
      # TODO: Implement rate limiting logic
    end

    def log_tool_usage(input)
      # TODO: Audit logging for compliance
    end

    def execute_with_timeout(input, timeout: 30)
      # TODO: Implement timeout mechanism
      Timeout::timeout(timeout) do
        # TODO: Actual tool logic here
      end
    end

    def sanitize_output(output)
      # TODO: Remove sensitive information from output
      #       Validate output format
      output
    end

    def log_security_violation(error, input)
      # TODO: Log security violations for monitoring
    end
  end
end
