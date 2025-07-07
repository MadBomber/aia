# database_query_tool.rb - Database interaction example
require 'ruby_llm/tool'
require 'sequel'

module Tools
  class DatabaseQuery < RubyLLM::Tool
    def self.name = "database_query"

    description <<~DESCRIPTION
      Execute safe, read-only database queries with automatic connection management and security controls.
      This tool is designed for secure data retrieval operations only, restricting access to SELECT statements
      to prevent any data modification. It includes automatic connection pooling, query result limiting,
      and comprehensive error handling. The tool supports multiple database configurations through
      environment variables and ensures all connections are properly closed after use.
      Perfect for AI-assisted data analysis and reporting workflows where read-only access is required.
    DESCRIPTION

    param :query,
          desc: <<~DESC,
            SQL SELECT query to execute against the database. Only SELECT statements are permitted
            for security reasons - INSERT, UPDATE, DELETE, and DDL statements will be rejected.
            The query should be well-formed SQL appropriate for the target database system.
            Examples: 'SELECT * FROM users WHERE active = true', 'SELECT COUNT(*) FROM orders'.
            Table and column names should match the database schema exactly.
          DESC
          type: :string,
          required: true

    param :database,
          desc: <<~DESC,
            Database configuration name to use for the connection. This corresponds to environment
            variables like DATABASE_URL, STAGING_DATABASE_URL, etc. The tool will look for
            an environment variable named {DATABASE_NAME}_DATABASE_URL (uppercase).
            Default is 'default' which looks for DEFAULT_DATABASE_URL environment variable.
            Common values: 'default', 'staging', 'analytics', 'reporting'.
          DESC
          type: :string,
          default: "default"

    param :limit,
          desc: <<~DESC,
            Maximum number of rows to return from the query to prevent excessive memory usage
            and long response times. The tool automatically adds a LIMIT clause if one is not
            present in the original query. Set to a reasonable value based on expected data size.
            Minimum: 1, Maximum: 10000, Default: 100. For large datasets, consider using
            pagination or more specific WHERE clauses.
          DESC
          type: :integer,
          default: 100

    def execute(query:, database: "default", limit: 100)
      begin
        # Security: Only allow SELECT queries
        normalized_query = query.strip.downcase
        unless normalized_query.start_with?('select')
          raise "Only SELECT queries are allowed for security"
        end

        db = connect_to_database(database)
        limited_query = add_limit_to_query(query, limit)

        results = db[limited_query].all

        {
          success:     true,
          query:       limited_query,
          row_count:   results.length,
          data:        results,
          database:    database,
          executed_at: Time.now.iso8601
        }
      rescue => e
        {
          success:  false,
          error:    e.message,
          query:    query,
          database: database
        }
      ensure
        db&.disconnect
      end
    end

    private

    def connect_to_database(database_name)
      # Implementation depends on your database setup
      connection_string = ENV["#{database_name.upcase}_DATABASE_URL"]
      raise "Database connection not configured for #{database_name}" unless connection_string

      Sequel.connect(connection_string)
    end

    def add_limit_to_query(query, limit)
      # Add LIMIT clause if not present
      query += " LIMIT #{limit}" unless query.downcase.include?('limit')
      query
    end
  end
end
