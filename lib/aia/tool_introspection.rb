# lib/aia/tool_introspection.rb

module AIA
  # Shared name/description extraction for tool objects, which may be
  # RubyLLM tools, RobotLab tools, or bare tool classes.
  module ToolIntrospection
    module_function

    def tool_name(tool)
      tool.respond_to?(:name) ? tool.name : tool.class.name
    end

    def tool_description(tool)
      tool.respond_to?(:description) ? tool.description.to_s : ''
    end
  end
end
