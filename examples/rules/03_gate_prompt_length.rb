# examples/rules/03_gate_prompt_length.rb
#
# Quality gate rule: warn when context files are very large.
# This supplements the built-in 100KB warning with a custom threshold.
#
# Install: cp examples/rules/03_gate_prompt_length.rb ~/.config/aia/rules/

AIA.rules_for(:gate) do
  rule "very_large_context_warning" do
    on :context_stats, large: true
    perform do |facts|
      size = facts[0][:total_size]
      if size && size > 500_000
        AIA.decisions.add(:gate, action: "warn",
          message: "Context exceeds 500KB (#{size / 1024}KB). This may be slow and expensive.")
      end
    end
  end
end
