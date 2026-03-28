# frozen_string_literal: true

# lib/aia/tool_filter_registry.rb
#
# Builds and preps all active ToolFilter instances from the current config.
# Extracted from Session#start to remove 5 identical if/prep/assign blocks.

module AIA
  class ToolFilterRegistry
    # Build and prep all active tool filters according to config flags.
    # The rule_router is needed for KBS filter construction and, when KBS is
    # not active, to register tools so evaluate_turn has access to them.
    #
    # @param config  [AIA::Config]   the current AIA configuration
    # @param tools   [Array]         all available tool objects
    # @param rule_router [AIA::RuleRouter] the active rule router
    # @return [Hash{Symbol => ToolFilter}] keyed by filter identifier
    def self.build_from_config(config, tools, rule_router:)
      filters       = {}
      fact_asserter = nil

      db_dir  = config.paths&.aia_dir
      load_db = config.flags.tool_filter_load
      save_db = config.flags.tool_filter_save

      if config.flags.tool_filter_a
        kbs_filter = ToolFilter::KBS.new(
          rule_router: rule_router, tools: tools,
          db_dir: db_dir, load_db: load_db, save_db: save_db
        )
        kbs_filter.prep
        filters[:kbs] = kbs_filter
      else
        # Still need register_tools for evaluate_turn even when KBS filter is off
        rule_router.register_tools(tools, db_dir: db_dir, load_db: load_db, save_db: save_db)
      end

      if config.flags.tool_filter_b
        fact_asserter ||= FactAsserter.new
        tfidf_filter = ToolFilter::TFIDF.new(tools: tools, fact_asserter: fact_asserter)
        tfidf_filter.prep
        filters[:tfidf] = tfidf_filter
      end

      if config.flags.tool_filter_c
        fact_asserter ||= FactAsserter.new
        zvec_filter = ToolFilter::Zvec.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir: db_dir, load_db: load_db, save_db: save_db
        )
        zvec_filter.prep
        filters[:zvec] = zvec_filter
      end

      if config.flags.tool_filter_d
        fact_asserter ||= FactAsserter.new
        sqvec_filter = ToolFilter::SqliteVec.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir: db_dir, load_db: load_db, save_db: save_db
        )
        sqvec_filter.prep
        filters[:sqlite_vec] = sqvec_filter
      end

      if config.flags.tool_filter_e
        fact_asserter ||= FactAsserter.new
        lsi_filter = ToolFilter::LSI.new(
          tools: tools, fact_asserter: fact_asserter,
          db_dir: db_dir, load_db: load_db, save_db: save_db
        )
        lsi_filter.prep
        filters[:lsi] = lsi_filter
      end

      filters
    end
  end
end
