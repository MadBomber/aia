# frozen_string_literal: true

# lib/aia/tool_filter_registry.rb
#
# Builds and preps all active ToolFilter instances from the current config.
# Extracted from Session#start to remove 5 identical if/prep/assign blocks.

module AIA
  class ToolFilterRegistry
    # Build and prep all active tool filters according to config flags.
    #
    # @param config  [AIA::Config]   the current AIA configuration
    # @param tools   [Array]         all available tool objects
    # @return [Hash{Symbol => ToolFilter}] keyed by filter identifier
    def self.build_from_config(config, tools)
      filters       = {}
      fact_asserter = nil

      db_dir  = config.paths&.aia_dir
      load_db = config.flags.tool_filter_load
      save_db = config.flags.tool_filter_save

      if config.flags.tool_filter_a
        require_relative 'tool_filter/tfidf'
        fact_asserter ||= AIA::FactAsserter.new
        tfidf_filter = ToolFilter::TFIDF.new(tools: tools, fact_asserter: fact_asserter)
        tfidf_filter.prep
        filters[:tfidf] = tfidf_filter
      end

      filters
    end
  end
end
