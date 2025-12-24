# frozen_string_literal: true

# lib/aia/config/model_spec.rb
#
# ModelSpec represents a single model configuration with optional role.
# This provides typed access to model configuration instead of raw hashes.
#
# Example:
#   spec = ModelSpec.new(name: 'gpt-4o', role: 'architect')
#   spec.name        # => 'gpt-4o'
#   spec.role        # => 'architect'
#   spec.internal_id # => 'gpt-4o'

module AIA
  class ModelSpec
    attr_accessor :name, :role, :instance, :internal_id

    def initialize(hash = {})
      hash = hash.transform_keys(&:to_sym) if hash.respond_to?(:transform_keys)

      @name = hash[:name]
      @role = hash[:role]
      @instance = hash[:instance] || 1
      @internal_id = hash[:internal_id] || @name
    end

    def to_h
      {
        name: @name,
        role: @role,
        instance: @instance,
        internal_id: @internal_id
      }
    end

    def to_s
      if @role
        "#{@name}=#{@role}"
      else
        @name.to_s
      end
    end

    def ==(other)
      return false unless other.is_a?(ModelSpec)
      name == other.name && role == other.role && instance == other.instance
    end

    def eql?(other)
      self == other
    end

    def hash
      [name, role, instance].hash
    end

    # Check if this model has a role assigned
    def role?
      !@role.nil? && !@role.empty?
    end

    # Check if this is a duplicate instance of the same model
    def duplicate?
      @instance > 1
    end
  end
end
