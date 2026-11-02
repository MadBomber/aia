# lib/aia/tool_introspection.rb

module AIA
  # Shared name/description extraction for tool objects, which may be
  # RubyLLM tools, RobotLab tools, or bare tool classes.
  module ToolIntrospection
    module_function

    # The name the model calls the tool by. A RubyLLM::Tool class answers
    # with its +tool_name+ ("dns"), not its Ruby constant name
    # ("SharedTools::Tools::DnsTool"): robot_lab instantiates tool classes,
    # so allowlists and per-turn tool filters must use that name to match.
    def tool_name(tool)
      if tool.is_a?(Class)
        tool.respond_to?(:tool_name) ? tool.tool_name : tool.name
      else
        tool.respond_to?(:name) ? tool.name : tool.class.name
      end
    end

    def tool_description(tool)
      tool.respond_to?(:description) ? tool.description.to_s : ''
    end
  end
end
