# examples/rules/04_tool_selection.rb
#
# Custom tool selection rules (optional).
#
# AIA automatically builds tool routing rules at startup by analyzing
# each loaded tool's name and description against domain keyword patterns.
# This file shows how to ADD custom rules on top of the automatic ones.
#
# Use cases for custom rules:
#   - Override automatic classification for a specific tool
#   - Add domain routing for a custom tool with unusual naming
#   - Activate tools based on input text patterns instead of domain
#
# Install: cp examples/rules/04_tool_selection.rb ~/.config/aia/rules/
#
# Facts available in the :route KB:
#   :tool — name: String, description: String, active: true
#   :classification_decision — domain: String, ...
#   :turn_input — text: String, length: Integer

AIA.rules_for(:route) do
  # Example: activate a custom tool for a specific keyword
  # rule "activate_my_custom_tool" do
  #   on :turn_input do
  #     text matches(/\b(my_keyword)\b/i)
  #   end
  #   on :tool, name: "my_custom_tool"
  #   perform do |facts|
  #     AIA.decisions.add(:tool_activate, tool: facts[1][:name], reason: "custom keyword match")
  #   end
  # end

  # Example: force a tool into a domain it wasn't auto-classified into
  # rule "activate_special_tool_for_data" do
  #   on :classification_decision, domain: "data"
  #   on :tool, name: "my_special_tool"
  #   perform do |facts|
  #     AIA.decisions.add(:tool_activate, tool: facts[1][:name], reason: "custom data domain override")
  #   end
  # end
end
