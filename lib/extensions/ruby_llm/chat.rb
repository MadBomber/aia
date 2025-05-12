# lib/extensions/ruby_llm/chat.rb

module RubyLLM
  class Chat
    class << self
      # Sets up Model Control Protocol (MCP) tools
      #
      # @param client [instance object] MCP client instance to use
      # @param call_tool_method [Symbol] Method name to use for tool execution
      # @param tools [Array<Hash>] Array of MCP tool definitions
      #
      # @return [self] Returns self for method chaining
      #
      def with_mcp(client:, call_tool_method:, tools:)
        # Validate all required parameters are present
        if client.nil?
          RubyLLM.logger.error "MCP setup failed: client must be provided"
          return clear_mcp_state
        end

        if call_tool_method.nil?
          RubyLLM.logger.error "MCP setup failed: call_tool_method must be provided"
          return clear_mcp_state
        end

        if tools.nil?
          RubyLLM.logger.error "MCP setup failed: tools must be provided"
          return clear_mcp_state
        end

        # Validate call_tool_method type
        unless call_tool_method.is_a?(Symbol) || call_tool_method.is_a?(String)
          RubyLLM.logger.error "MCP setup failed: call_tool_method must be a Symbol or String, got #{call_tool_method.class}"
          return clear_mcp_state
        end

        # Validate client responds to the method
        unless client.respond_to?(call_tool_method)
          RubyLLM.logger.error "MCP setup failed: client instance does not respond to call_tool_method #{call_tool_method}"
          return clear_mcp_state
        end

        # Set MCP configuration
        @mcp_client    = client
        @mcp_call_tool = call_tool_method.to_sym
        @mcp_tools     = tools

        self
      end

      # Get the MCP client instance if configured
      # @return [MCPClient::Client, nil] The MCP client instance or nil if not configured
      def mcp_client
        @mcp_client
      end

      # Get the method name to use for tool execution if configured
      # @return [Symbol, nil] The method name or nil if not configured
      def mcp_call_tool
        @mcp_call_tool
      end

      # Get the MCP tool definitions if configured
      # @return [Array<Hash>] The MCP tool definitions or empty array if not configured
      def mcp_tools
        @mcp_tools || []
      end

      private

      # Clear all MCP state and return self
      # @return [self]
      def clear_mcp_state
        @mcp_client    = nil
        @mcp_call_tool = nil
        @mcp_tools     = []
        self
      end
    end

    # Prepend a module to add MCP tool support
    module MCPSupport
      def initialize(...)
        super
        add_mcp_tools
      end

      private

      def add_mcp_tools
        self.class.mcp_tools.each do |tool_def|
          debug_me{[ :tool_def ]}
          tool_name = tool_def.dig(:function, :name).to_sym
          next if @tools.key?(tool_name) # Skip if local or MCP tool exists with same name

          @tools[tool_name] = MCPToolWrapper.new(tool_def)
        end
      end
    end

    # Add MCP support to the Chat class
    prepend MCPSupport
  end

  # Wraps an MCP tool definition to match the RubyLLM::Tool interface
  class MCPToolWrapper
    def initialize(mcp_tool)
      @mcp_tool = mcp_tool
    end

    def name
      @mcp_tool.dig(:function, :name)
    end

    def description
      @mcp_tool.dig(:function, :description)
    end

    # Simple parameter class that implements the interface expected by RubyLLM::Providers::OpenAI::Tools#param_schema
    class Parameter
      attr_reader :type, :description, :required
      
      def initialize(type, description, required)
        @type = type || 'string'
        @description = description
        @required = required
      end
    end
    
    def parameters
      @parameters ||= begin
        props = @mcp_tool.dig(:function, :parameters, "properties") || {}
        required_params = @mcp_tool.dig(:function, :parameters, "required") || []
        
        # Create Parameter objects with the expected interface
        # The parameter name is the key in the properties hash
        result = {}
        props.each do |param_name, param_def|
          result[param_name.to_sym] = Parameter.new(
            param_def["type"],
            param_def["description"],
            required_params.include?(param_name)
          )
        end
        result
      end
    end

    def call(args)
      # Log the tool call with arguments
      RubyLLM.logger.debug "Tool #{name} called with: #{args.inspect}"

      # Verify MCP client is configured properly
      unless Chat.mcp_client && Chat.mcp_call_tool
        error = { error: "MCP client not properly configured" }
        RubyLLM.logger.error error[:error]
        return error
      end

      # Handle tool calls that require non-string parameters
      normalized_args = {}
      args.each do |key, value|
        # Convert string numbers to actual numbers when needed
        if value.is_a?(String) && value.match?(/\A-?\d+(\.\d+)?\z/)
          param_type = @mcp_tool.dig(:function, :parameters, "properties", key.to_s, "type")
          if param_type == "number" || param_type == "integer"
            normalized_args[key] = value.include?('.') ? value.to_f : value.to_i
            next
          end
        end
        normalized_args[key] = value
      end
      
      # Execute the tool via the MCP client with a timeout
      timeout = 10 # seconds
      result = nil
      
      begin
        Timeout.timeout(timeout) do
          result = Chat.mcp_client.send(Chat.mcp_call_tool, name, normalized_args)
        end
      rescue Timeout::Error
        error = { error: "MCP tool execution timed out after #{timeout} seconds" }
        RubyLLM.logger.error error[:error]
        return error
      rescue StandardError => e
        error = { error: "MCP tool execution failed: #{e.message}" }
        RubyLLM.logger.error error[:error]
        return error
      end

      # Log the result
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end
  end
end
