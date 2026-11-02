# lib/aia/mcp_server_config.rb

module AIA
  # Normalized view of one MCP server hash. Server configs arrive with
  # symbol or string keys, and with connection fields either nested under
  # :transport or at the top level; this object owns all of that fallback
  # logic so callers never touch the raw hash shape.
  McpServerConfig = Data.define(:name, :command, :args, :env, :timeout_raw, :url) do
    def self.from_hash(server)
      return from_class(server) unless server.is_a?(Hash)

      transport = fetch_key(server, :transport) || {}
      new(
        name:        AIA::Utility.server_name(server),
        command:     fetch_key(transport, :command) || fetch_key(server, :command),
        args:        Array(fetch_key(transport, :args) || fetch_key(server, :args)),
        env:         fetch_key(transport, :env) || fetch_key(server, :env) || {},
        timeout_raw: fetch_key(server, :timeout),
        url:         fetch_key(transport, :url) || fetch_key(server, :url)
      )
    end

    # A RubyLLM::MCP subclass describes itself through its class DSL. A
    # constant name whose class is not loaded yet yields just its name.
    def self.from_class(server)
      klass = server.is_a?(Class) ? server : nil
      argv  = klass.respond_to?(:command) ? Array(klass.command) : []
      new(
        name:        AIA::Utility.server_name(server),
        command:     argv.first,
        args:        argv.drop(1),
        env:         {},
        timeout_raw: (klass.timeout if klass.respond_to?(:timeout)),
        url:         (klass.url if klass.respond_to?(:url))
      )
    end

    # Read a hash entry by symbol or string key.
    def self.fetch_key(hash, key) = hash[key] || hash[key.to_s]

    # Timeout in milliseconds; raw values below 1000 are treated as seconds.
    def timeout_ms(default: 8_000, cap: 30_000)
      raw = (timeout_raw || default).to_i
      ms  = raw < 1000 ? raw * 1000 : raw
      [ms, cap].min
    end
  end
end
