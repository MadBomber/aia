# lib/aia_refinements/string.rb


module Refinements
  refine String do
    def include_all?(substrings)
      Array(substrings).all? { |substring| self.include?(substring) }
    end
    alias :all? :include_all?

    def include_any?(substrings)
      Array(substrings).any? { |substring| self.include?(substring) }
    end
    alias :any?  :include_any?
  end
end
