# lib/extensions/openstruct_merge.rb
#

require 'ostruct'

class OpenStruct
  def self.merge(*args)
    result = OpenStruct.new

    args.each do |arg|
      unless [Hash, OpenStruct].include?(arg.class)
        raise ArgumentError, "Only OpenStruct or Hash objects are allowed. bad: #{arg.class}"
      end

      arg.each_pair do |key, value|
        set_value(result, key, value)
      end
    end

    result
  end

  # Sets value in result OpenStruct, handling nested OpenStruct and Hash objects
  # Skip nil values to avoid overwriting existing values with nil
  def self.set_value(result, key, value)
    # Skip nil values - don't overwrite existing values with nil
    return if value.nil?

    if value.is_a?(OpenStruct) || value.is_a?(Hash)
      current_value = result[key]
      current_value = {} if current_value.nil?
      merged_value  = merge(current_value, value.to_h)
      result[key]   = merged_value
    else
      result[key] = value
    end
  end
end

__END__

# Usage example
os1 = OpenStruct.new(a: 1, b: 2, e: OpenStruct.new(x: 9))
os2 = OpenStruct.new(b: 3, c: 4)
os3 = {d: 5, e: {y: 10}}

merged_os = OpenStruct.merge(os1, os2, os3)
puts merged_os.inspect
