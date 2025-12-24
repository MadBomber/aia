# frozen_string_literal: true

# lib/aia/config/config_section.rb
#
# ConfigSection provides method access to nested configuration hashes.
# This allows dot-notation access like: config.llm.temperature
# instead of: config[:llm][:temperature]

module AIA
  class ConfigSection
    def initialize(hash = {})
      @data = {}
      (hash || {}).each do |key, value|
        @data[key.to_sym] = value.is_a?(Hash) ? ConfigSection.new(value) : value
      end
    end

    def method_missing(method, *args, &block)
      key = method.to_s
      if key.end_with?('=')
        @data[key.chomp('=').to_sym] = args.first
      elsif @data.key?(method)
        @data[method]
      else
        nil
      end
    end

    def respond_to_missing?(method, include_private = false)
      key = method.to_s.chomp('=').to_sym
      @data.key?(key) || super
    end

    def to_h
      @data.transform_values do |v|
        v.is_a?(ConfigSection) ? v.to_h : v
      end
    end

    def [](key)
      @data[key.to_sym]
    end

    def []=(key, value)
      @data[key.to_sym] = value
    end

    def merge(other)
      other_hash = other.is_a?(ConfigSection) ? other.to_h : other
      ConfigSection.new(deep_merge(to_h, other_hash || {}))
    end

    def keys
      @data.keys
    end

    def values
      @data.values
    end

    def each(&block)
      @data.each(&block)
    end

    def empty?
      @data.empty?
    end

    def key?(key)
      @data.key?(key.to_sym)
    end

    alias has_key? key?

    private

    def deep_merge(base, overlay)
      base.merge(overlay) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end
