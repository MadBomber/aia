# test/aia/tools_test.rb

require_relative '../test_helper'
require_relative '../../lib/aia/tools'

class ToolsTest < Minitest::Test

  def setup
    @klass = Class.new(Tools) do
      meta name: 'TestTool', version: '1.0'
    end
  end


  def test_inherited_registers_subclass
    assert_includes(Tools.catalog, @klass._metadata)
  end


  def test_meta_assigns_metadata
    assert_equal('TestTool', @klass.meta[:name])
    assert_equal('1.0', @klass.meta[:version])
  end


  def test_get_meta_returns_metadata
    assert_equal(@klass._metadata, @klass.get_meta)
  end


  def test_search_for_finds_correct_subclasses
    results = Tools.search_for(name: 'TestTool')
    assert_equal(1, results.size)
    assert_equal(@klass._metadata, results.first)
  end


  def test_catalog_returns_all_subclasses
    new_klass = Class.new(Tools) { meta name: 'NewTool', version: '1.1' }

    assert_includes(Tools.catalog.map { |meta| meta[:name] }, 'TestTool')
    assert_includes(Tools.catalog.map { |meta| meta[:name] }, 'NewTool')
  end


  def test_search_for_with_no_criteria_returns_all
    assert_equal(Tools.catalog, Tools.search_for({}))
  end


  def test_load_tools_require_files
    Tools.load_tools
    assert(Tools.catalog.any?, 'Expected Tools.catalog to have loaded subclasses')
  end
end
