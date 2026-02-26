# examples/rules/02_prefer_claude_for_code.rb
#
# Model selection rule: prefer Claude for code tasks.
# When the classify KB tags a prompt as "code" domain,
# suggest Claude as the preferred model.
#
# Install: cp examples/rules/02_prefer_claude_for_code.rb ~/.config/aia/rules/

AIA.rules_for(:model_select) do
  rule "prefer_claude_for_code" do
    on :classification_decision, domain: "code"
    on :model, name: satisfies { |n| n.to_s.include?("claude") }
    perform do |facts|
      AIA.decisions.add(:model_decision,
        model: facts[1][:name],
        reason: "user rule: prefer Claude for code tasks")
    end
  end
end
