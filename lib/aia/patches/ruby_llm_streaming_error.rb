# lib/aia/patches/ruby_llm_streaming_error.rb
#
# Patches RubyLLM::Streaming#handle_error_chunk to locate the SSE `data:` line
# robustly.
#
# The shipped implementation assumes the `data:` line is the SECOND line of the
# same chunk as `event: error`:
#
#     error_data = chunk.split("\n")[1].delete_prefix('data: ')
#
# When a provider flushes `event: error` and its `data:` line in SEPARATE stream
# chunks (LM Studio does this on, e.g., a context-length overflow),
# chunk.split("\n")[1] is nil and the real provider message is masked as the
# cryptic `NoMethodError: undefined method 'delete_prefix' for nil`. This
# version scans the chunk for the `data:` line so the actual error propagates to
# the user. Falls back to the whole chunk when no data line is present, which
# still parses cleanly instead of raising.
#
# Applied via #prepend so it cleanly overrides the buggy method while reusing
# ruby_llm's own private parse_error_from_json. Guarded against API drift: if
# parse_error_from_json is renamed/removed the patch is skipped with a warning.
#
# ruby_llm >= 2.0 moved the module to RubyLLM::Protocol::Streaming and fixed
# the bug upstream (nil-safe data-line access plus SSE event buffering), so on
# 2.0+ this patch deliberately does not apply. It stays for the 1.x line only.

module AIA
  module RubyLLMStreamingError
    private

    def handle_error_chunk(chunk, env)
      data_line  = chunk.to_s.lines.find { |line| line.start_with?('data:') }
      error_data = data_line ? data_line.sub(/\Adata:\s*/, '').strip : chunk.to_s.strip
      parse_error_from_json(error_data, env, 'Failed to parse error chunk')
    end
  end
end

# ruby_llm is Zeitwerk-managed, so the constants must be referenced (not
# defined?-probed) to trigger their autoload; NameError means "not this version".
streaming =
  begin
    RubyLLM::Streaming # ruby_llm 1.x
  rescue NameError
    nil
  end

if streaming.nil?
  begin
    RubyLLM::Protocol::Streaming # ruby_llm >= 2.0: fixed upstream, no patch needed
  rescue NameError
    $stderr.puts "WARNING: [AIA] ruby_llm patch skipped: no streaming module found " \
                 "(ruby_llm #{RubyLLM::VERSION}). Streaming error messages may be cryptic."
  end
elsif streaming.private_method_defined?(:parse_error_from_json)
  streaming.prepend(AIA::RubyLLMStreamingError)
else
  $stderr.puts "WARNING: [AIA] ruby_llm patch skipped: RubyLLM::Streaming#parse_error_from_json " \
               "not found (ruby_llm #{RubyLLM::VERSION}). Streaming error messages may be cryptic."
end
