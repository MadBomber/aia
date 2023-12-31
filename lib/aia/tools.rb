# lib/aia/tools.rb

require 'hashie'

class AIA::Tools
  @@catalog = []

  def meta = self.class::meta

  class << self
    def inherited(subclass)
      subclass_meta = Hashie::Mash.new(klass: subclass)
      subclass.instance_variable_set(:@_metadata, subclass_meta)

      @@catalog << subclass_meta
    end


    def meta(metadata = nil)
      return @_metadata if metadata.nil?

      @_metadata  = Hashie::Mash.new(metadata)
      entry       = @@catalog.detect { |item| item[:klass] == self }
      
      entry.merge!(metadata) if entry
    end


    def get_meta
      @_metadata
    end


    def search_for(criteria = {})
      @@catalog.select do |meta|
        criteria.all? { |k, v| meta[k] == v }
      end
    end


    def catalog
      @@catalog
    end


    def load_tools
      Dir.glob(File.join(File.dirname(__FILE__), 'tools', '*.rb')).each do |file|
        require file
      end
    end
  end
end
