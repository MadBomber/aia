require_relative '../test_helper'
require_relative '../../lib/aia/topic_context'

class TopicContextTest < Minitest::Test
  def setup
    @ctx = AIA::TopicContext.new
  end

  def test_initialize_defaults
    assert_equal 128_000, @ctx.context_size
    assert_empty @ctx.topics
    assert_equal 0, @ctx.total_chars
    assert_empty @ctx.all_conversations
  end

  def test_initialize_custom_context_size
    ctx = AIA::TopicContext.new(1000)
    assert_equal 1000, ctx.context_size
  end

  def test_store_conversation_with_explicit_topic
    topic = @ctx.store_conversation("hello", "world", "greeting")
    assert_equal "greeting", topic
    assert_includes @ctx.topics, "greeting"
  end

  def test_store_conversation_auto_generates_topic
    topic = @ctx.store_conversation("tell me about ruby programming", "Ruby is great")
    assert_equal "tell_me_about", topic
  end

  def test_store_conversation_tracks_total_chars
    @ctx.store_conversation("hello", "world", "t1")
    expected = "hello".bytesize + "world".bytesize
    assert_equal expected, @ctx.total_chars
  end

  def test_store_conversation_accumulates_total_chars
    @ctx.store_conversation("aaa", "bbb", "t1")
    @ctx.store_conversation("ccc", "ddd", "t2")
    expected = ("aaa".bytesize + "bbb".bytesize) + ("ccc".bytesize + "ddd".bytesize)
    assert_equal expected, @ctx.total_chars
  end

  def test_store_conversation_raises_on_non_string_request
    assert_raises(ArgumentError) { @ctx.store_conversation(123, "world") }
  end

  def test_store_conversation_raises_on_non_string_response
    assert_raises(ArgumentError) { @ctx.store_conversation("hello", 456) }
  end

  def test_get_conversation_returns_entries
    @ctx.store_conversation("req1", "resp1", "topic1")
    @ctx.store_conversation("req2", "resp2", "topic1")

    entries = @ctx.get_conversation("topic1")
    assert_equal 2, entries.size
    assert_equal "req1", entries[0][:request]
    assert_equal "resp1", entries[0][:response]
    assert_equal "req2", entries[1][:request]
    assert_equal "resp2", entries[1][:response]
  end

  def test_get_conversation_returns_empty_for_unknown_topic
    entries = @ctx.get_conversation("nonexistent")
    assert_empty entries
  end

  def test_topics_returns_all_topic_names
    @ctx.store_conversation("a", "b", "t1")
    @ctx.store_conversation("c", "d", "t2")
    @ctx.store_conversation("e", "f", "t3")

    assert_equal %w[t1 t2 t3], @ctx.topics.sort
  end

  def test_all_conversations_returns_dup
    @ctx.store_conversation("a", "b", "topic")
    all = @ctx.all_conversations
    assert_kind_of Hash, all
    assert_equal 1, all.size
    assert all.key?("topic")
  end

  def test_clear_resets_everything
    @ctx.store_conversation("a", "b", "topic")
    @ctx.clear
    assert_empty @ctx.topics
    assert_equal 0, @ctx.total_chars
    assert_empty @ctx.all_conversations
  end

  def test_topic_stats_for_existing_topic
    @ctx.store_conversation("hello", "world", "t1")
    @ctx.store_conversation("foo", "bar", "t1")

    stats = @ctx.topic_stats("t1")
    assert_equal 2, stats[:count]
    expected_size = ("hello".bytesize + "world".bytesize) + ("foo".bytesize + "bar".bytesize)
    assert_equal expected_size, stats[:size]
    assert_in_delta expected_size / 2.0, stats[:avg_size], 0.01
  end

  def test_topic_stats_for_nonexistent_topic
    stats = @ctx.topic_stats("nonexistent")
    assert_equal({}, stats)
  end

  def test_auto_topic_from_empty_request
    topic = @ctx.store_conversation("", "response")
    assert_equal "general", topic
  end

  def test_auto_topic_from_punctuation_only
    topic = @ctx.store_conversation("!@#$%", "response")
    assert_equal "general", topic
  end

  def test_auto_topic_uses_first_three_words
    topic = @ctx.store_conversation("one two three four five", "resp")
    assert_equal "one_two_three", topic
  end

  def test_auto_topic_strips_non_alphanumeric
    topic = @ctx.store_conversation("Hello, World! How are you?", "fine")
    assert_equal "hello_world_how", topic
  end

  def test_auto_topic_with_fewer_than_three_words
    topic = @ctx.store_conversation("hello", "resp")
    assert_equal "hello", topic

    @ctx.clear
    topic = @ctx.store_conversation("two words", "resp")
    assert_equal "two_words", topic
  end

  def test_trim_topic_removes_oldest_when_over_limit
    # Use a small context size to trigger trimming
    ctx = AIA::TopicContext.new(20)
    ctx.store_conversation("aaaaaaaaaa", "bbbbbbbbbb", "t1")  # 20 bytes, at limit
    ctx.store_conversation("cccccccccc", "dddddddddd", "t1")  # 20 more bytes, over limit

    entries = ctx.get_conversation("t1")
    # The oldest entry should have been trimmed
    assert_equal 1, entries.size
    assert_equal "cccccccccc", entries[0][:request]
  end

  def test_trim_topic_adjusts_total_chars
    ctx = AIA::TopicContext.new(20)
    ctx.store_conversation("aaaaaaaaaa", "bbbbbbbbbb", "t1")  # 20 bytes
    initial_total = ctx.total_chars
    assert_equal 20, initial_total

    ctx.store_conversation("cc", "dd", "t1")  # 4 bytes, total would be 24, triggers trim
    # After trimming, only the second entry should remain
    assert_equal 4, ctx.total_chars
  end

  def test_entries_have_time_field
    @ctx.store_conversation("hello", "world", "t1")
    entries = @ctx.get_conversation("t1")
    assert_kind_of Time, entries[0][:time]
  end

  def test_entries_have_size_field
    @ctx.store_conversation("hello", "world", "t1")
    entries = @ctx.get_conversation("t1")
    assert_equal "hello".bytesize + "world".bytesize, entries[0][:size]
  end

  def test_thread_safety_with_concurrent_writes
    threads = 10.times.map do |i|
      Thread.new do
        @ctx.store_conversation("req#{i}", "resp#{i}", "concurrent")
      end
    end
    threads.each(&:join)

    entries = @ctx.get_conversation("concurrent")
    assert entries.size <= 10
    assert entries.size > 0
  end
end
