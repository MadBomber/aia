# frozen_string_literal: true

require 'time'
require 'ruby_llm/tool'

# Long-term key/value memory store backed by RobotLab::Memory.
#
# Memory.new(backend: :auto) selects Redis when available (same detection and
# connection logic as the robot_lab core) and falls back to an in-memory Hash
# automatically — no duplicated detection logic here.
#
# Semantic search is powered by store_document / search_documents from the
# robot_lab-document_store gem when loaded. The tool degrades gracefully to
# substring search when that gem is absent.
#
# A single Memory instance is shared across all tool invocations in the session
# (class-level singleton). memory.redis? reports whether data is Redis-backed.
#
# Actions: put, get, delete, list, search
class MemoryTool < RubyLLM::Tool
  # Reject keys that RobotLab::Memory treats as reserved so the LLM cannot
  # accidentally overwrite runtime coordination state (:data, :results, etc.).
  RESERVED = RobotLab::Memory::RESERVED_KEYS.map(&:to_s).freeze

  def self.name = 'memory_tool'

  description <<~DESC
    Persistent long-term memory store backed by RobotLab::Memory (Redis when
    available; in-session Hash otherwise). Semantic search via the
    robot_lab-document_store gem when loaded; falls back to substring search
    when not. Every response includes a 'backend' field.
    Actions: put, get, delete, list, search.
  DESC

  parameter :action, type: :string, required: true,
            description: 'One of: put, get, delete, list, search.'
  parameter :key,    type: :string,
            description: 'Memory key (required for put, get, delete).'
  parameter :value,  type: :string,
            description: 'Value to store (required for put).'
  parameter :tags,   type: :string,
            description: 'Comma-separated tags (optional on put; filters list and search).'
  parameter :query,  type: :string,
            description: 'Search query (required for search; semantic when available).'

  def execute(action:, key: nil, value: nil, tags: nil, query: nil)
    case action.to_s.strip.downcase
    when 'put'    then put_entry(key, value, tags)
    when 'get'    then get_entry(key)
    when 'delete' then delete_entry(key)
    when 'list'   then list_entries(filter_tags: parse_tags(tags))
    when 'search' then search_entries(query, filter_tags: parse_tags(tags))
    else error('unknown action; use put, get, delete, list, or search')
    end
  rescue StandardError => e
    error(e.message)
  end

  private

  # ------------------------------------------------------------------ actions

  def put_entry(key, value, tags)
    return error('key is required for put')     if blank?(key)
    return error('value is required for put')   if blank?(value)
    return error("'#{key}' is a reserved key")  if reserved_key?(key)

    sym   = key.to_sym
    now   = Time.now.utc.iso8601
    prior = memory.get(sym)
    entry = {
      value:      value,
      tags:       parse_tags(tags),
      created_at: prior ? prior[:created_at] : now,
      updated_at: now
    }

    memory.set(sym, entry)
    store_document_safe(sym, value)

    { success: true, action: 'put', key: key, backend: backend_name, **entry }
  end

  def get_entry(key)
    return error('key is required for get') if blank?(key)

    entry = memory.get(key.to_sym)
    return error("memory not found: #{key}") unless entry

    { success: true, action: 'get', key: key, **entry }
  end

  def delete_entry(key)
    return error('key is required for delete') if blank?(key)
    return error("memory not found: #{key}")  unless memory.key?(key.to_sym)

    memory.delete(key.to_sym)
    delete_document_safe(key.to_sym)

    { success: true, action: 'delete', key: key }
  end

  def list_entries(filter_tags: [])
    raw = memory.keys.filter_map do |sym|
      e = memory.get(sym)
      next unless e.is_a?(Hash) && e[:value]
      e.merge(key: sym.to_s)
    end
    entries = raw.sort_by { |e| e[:key] }
    entries = filter_by_tags(entries, filter_tags) if filter_tags.any?

    { success: true, action: 'list', backend: backend_name,
      count: entries.size, memories: entries }
  end

  def search_entries(query, filter_tags: [])
    return error('query is required for search') if blank?(query)

    hits = search_documents_safe(query)
    if hits
      semantic_search_results(hits, query, filter_tags)
    else
      substring_search_results(query, filter_tags)
    end
  end

  # ------------------------------------------------------------------ helpers

  def semantic_search_results(hits, query, filter_tags)
    entries = hits.filter_map do |hit|
      e = memory.get(hit[:key])
      next unless e.is_a?(Hash) && e[:value]
      e.merge(key: hit[:key].to_s, score: hit[:score])
    end
    entries = filter_by_tags(entries, filter_tags) if filter_tags.any?
    { success: true, action: 'search', query: query,
      search_type: 'semantic', backend: backend_name,
      count: entries.size, memories: entries }
  end

  def substring_search_results(query, filter_tags)
    q = query.downcase
    raw = memory.keys.filter_map do |sym|
      e = memory.get(sym)
      next unless e.is_a?(Hash) && e[:value]
      needle = [sym.to_s, e[:value].to_s, Array(e[:tags]).join(' ')].join(' ').downcase
      e.merge(key: sym.to_s) if needle.include?(q)
    end
    entries = raw.sort_by { |e| e[:key] }
    entries = filter_by_tags(entries, filter_tags) if filter_tags.any?
    { success: true, action: 'search', query: query,
      search_type: 'substring', backend: backend_name,
      count: entries.size, memories: entries }
  end

  def memory       = self.class.memory
  def backend_name = memory.redis? ? 'redis' : 'hash'
  def blank?(v)    = v.to_s.strip.empty?
  def error(msg)   = { success: false, error: msg }
  def reserved_key?(key) = RESERVED.include?(key.to_s.downcase)
  def parse_tags(v) = v.to_s.split(',').map(&:strip).reject(&:empty?).uniq

  def filter_by_tags(entries, tags)
    entries.select { |e| (tags - Array(e[:tags])).empty? }
  end

  # store_document / search_documents / delete_document require the optional
  # robot_lab-document_store gem. Rescue DependencyError so the tool still
  # functions (with substring fallback) when the gem is absent.

  def store_document_safe(key, text)
    memory.store_document(key, text)
  rescue RobotLab::DependencyError
    nil
  end

  def search_documents_safe(query)
    memory.search_documents(query)
  rescue RobotLab::DependencyError
    nil
  end

  def delete_document_safe(key)
    memory.delete_document(key)
  rescue RobotLab::DependencyError
    nil
  end

  # ---------------------------------------------------- class-level singleton

  class << self
    # Single RobotLab::Memory instance shared across all tool calls in a session.
    # backend: :auto — Memory's own redis_available? logic picks Redis or Hash.
    # enable_cache: false — the semantic LLM response cache is for chat; not
    # needed in a standalone key/value store.
    def memory
      @memory ||= RobotLab::Memory.new(backend: :auto, enable_cache: false)
    end
  end
end
