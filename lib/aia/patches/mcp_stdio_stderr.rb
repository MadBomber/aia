# lib/aia/patches/mcp_stdio_stderr.rb
#
# Redirect the stderr of stdio MCP server processes away from the terminal.
#
# ruby_llm 2.x's RubyLLM::MCP::Stdio#start launches each server with
# Open3.popen2, so the child inherits aia's stderr ("Its stderr is the
# parent's"). Every server banner, npm notice, stack trace and Python
# validation dump then lands on the terminal, interleaved with the
# TTY::Spinner::Multi "Connecting MCP servers" display, which corrupts it.
# (ruby_llm-mcp 1.x used popen3 and drained stderr, so aia 1.x was quiet.)
#
# The destination comes from AIA.config.logger.mcp.server_stderr:
#   a file path  - appended to (default: ~/.config/aia/logs/mcp_servers.log)
#   STDERR       - the old passthrough behavior
#   null         - discard (also: none, /dev/null)
#
# Stdio#start has no hook for spawn options. Rather than copy its body
# (which changed between ruby_llm 2.1 and 2.2), the patch calls the original
# #start and adds err: to the Open3.popen2 call made on this fiber while it
# runs. If a future ruby_llm drops Stdio#start, the patch is skipped with a
# warning instead of breaking MCP.

require 'fileutils'
require 'open3'

module AIA
  module MCPStdioStderr
    DEFAULT_PATH = '~/.config/aia/logs/mcp_servers.log'.freeze
    DISCARD      = %w[NULL NONE /DEV/NULL].freeze
    REDIRECT_KEY = :aia_mcp_stdio_stderr_target

    class << self
      # The spawn option value for a server's stderr.
      #
      # @param setting [String, nil] logger.mcp.server_stderr
      # @return [Array(String, String), nil] [path, mode] for Process.spawn's
      #   err: option, or nil to inherit the parent's stderr
      def spawn_target(setting = configured_setting)
        value = setting.to_s.strip
        value = DEFAULT_PATH if value.empty?

        case value.upcase
        when 'STDERR' then nil
        when *DISCARD then [File::NULL, 'w']
        else log_file_target(value)
        end
      end

      # Spawn options for Open3 with the stderr redirect added.
      #
      # @param options [Hash] options ruby_llm would pass (e.g. chdir:)
      # @param target [Array, nil] from .spawn_target
      # @return [Hash]
      def spawn_options(options, target = spawn_target)
        target ? options.merge(err: target) : options
      end

      # Install the patch onto RubyLLM::MCP::Stdio (idempotent).
      #
      # @return [Class, nil] the patched class, or nil when it can't be patched
      def install!(stdio = stdio_class)
        return unless stdio&.private_method_defined?(:start)

        Open3.singleton_class.prepend(Open3Redirect) unless Open3.singleton_class.ancestors.include?(Open3Redirect)
        stdio.prepend(StdioPatch) unless stdio.ancestors.include?(StdioPatch)
        stdio
      end

      # Run the block with Open3.popen2 calls on this fiber sending the
      # child's stderr to +target+.
      def redirecting_stderr(target = spawn_target)
        previous = Thread.current[REDIRECT_KEY]
        Thread.current[REDIRECT_KEY] = target
        yield
      ensure
        Thread.current[REDIRECT_KEY] = previous
      end

      private

      def configured_setting
        AIA.config&.logger&.mcp&.server_stderr
      rescue StandardError
        nil # config not loaded yet (or malformed): fall back to the default file
      end

      def log_file_target(value)
        path = File.expand_path(value)
        FileUtils.mkdir_p(File.dirname(path))
        [path, 'a']
      rescue SystemCallError
        [File::NULL, 'w'] # unwritable location: still keep the terminal clean
      end

      def stdio_class
        RubyLLM::MCP::Stdio if defined?(RubyLLM::MCP::Stdio)
      end
    end

    # Prepended onto Open3's singleton class. Only acts inside
    # MCPStdioStderr.redirecting_stderr, so other popen2 callers are untouched.
    module Open3Redirect
      def popen2(*args, **options, &block)
        target = Thread.current[REDIRECT_KEY]
        options = MCPStdioStderr.spawn_options(options, target) if target && !options.key?(:err)
        super(*args, **options, &block)
      end
    end

    # Prepended onto RubyLLM::MCP::Stdio.
    module StdioPatch
      private

      def start
        MCPStdioStderr.redirecting_stderr { super }
      end
    end
  end
end

unless AIA::MCPStdioStderr.install!
  warn 'AIA: RubyLLM::MCP::Stdio#start not found; MCP server stderr will reach the terminal'
end
