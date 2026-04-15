# frozen_string_literal: true
# test/aia/tool_filter/embedding_model_loader_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia'
require_relative '../../../lib/aia/tool_filter/embedding_model_loader'

class EmbeddingModelLoaderTest < Minitest::Test
  # A concrete class to include the mixin under test
  class FakeFilter
    include AIA::ToolFilter::EmbeddingModelLoader
    attr_reader :model, :label
    def initialize(label)
      @label = label
    end
  end

  def setup
    # Clear the module cache between tests
    AIA::ToolFilter::EmbeddingModelLoader._cache.clear
  end

  def test_load_embedding_model_stores_in_model_ivar
    fake_model = Object.new
    Informers.stubs(:pipeline).with("embedding", "test-model").returns(fake_model)

    filter = FakeFilter.new("TestA")
    filter.load_embedding_model("TestA", "test-model")

    assert_same fake_model, filter.model
  end

  def test_second_call_uses_cache_without_loading_again
    fake_model = Object.new
    Informers.expects(:pipeline).with("embedding", "test-model").returns(fake_model).once

    filter_a = FakeFilter.new("TestA")
    filter_a.load_embedding_model("TestA", "test-model")

    filter_b = FakeFilter.new("TestB")
    filter_b.load_embedding_model("TestB", "test-model")

    assert_same fake_model, filter_a.model
    assert_same fake_model, filter_b.model
  end

  def test_different_model_names_cached_separately
    model_a = Object.new
    model_b = Object.new
    Informers.stubs(:pipeline).with("embedding", "model-a").returns(model_a)
    Informers.stubs(:pipeline).with("embedding", "model-b").returns(model_b)

    filter = FakeFilter.new("TestA")
    filter.load_embedding_model("TestA", "model-a")
    assert_same model_a, filter.model

    filter.load_embedding_model("TestA", "model-b")
    assert_same model_b, filter.model
  end
end
