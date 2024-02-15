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


    def validate_tools
      raise "NotImplemented"
    end


    def setup_backend
      AIA.config.tools.backend = find_and_initialize_backend
    end


    private

    def find_and_initialize_backend
      found = AIA::Tools.search_for(name: AIA.config.backend, role: :backend)
      abort_no_backend_error if found.empty?
      abort_too_many_backends_error(found) if found.size > 1

      backend_klass = found.first.klass
      abort "Backend not found: #{AIA.config.backend}" unless backend_klass

      backend_klass.new(
        text:   "",
        files:  []
      )
    end

    def abort_no_backend_error
      abort "There are no :backend tools named #{AIA.config.backend}"
    end

    def abort_too_many_backends_error(found)
      abort "There are #{found.size} :backend tools with the name #{AIA.config.backend}"
    end

  end
end
