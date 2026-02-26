# examples/rules/01_classify_ruby.rb
#
# Custom classification rule: detect Ruby-specific requests.
#
# Install: cp examples/rules/01_classify_ruby.rb ~/.config/aia/rules/

AIA.rules_for(:classify) do
  rule "ruby_request" do
    on :turn_input do
      text matches(/\b(ruby|rails|gem|bundler|rake|rspec|minitest|rubocop|sorbet)\b/i)
    end
    perform do |facts|
      AIA.decisions.add(:classification, domain: "code", subdomain: "ruby", source: "user_ruby_request")
    end
  end
end
