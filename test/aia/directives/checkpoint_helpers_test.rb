require_relative '../../test_helper'

class DirectivesCheckpointHelpersTest < Minitest::Test
  def setup
    @instance = AIA::ContextDirectives.new
  end

  def test_reset_clears_all_state
    @instance.checkpoint_store['test'] = { position: 1 }
    @instance.checkpoint_counter = 5
    @instance.last_checkpoint_name = 'test'

    @instance.reset!

    assert_empty @instance.checkpoint_store
    assert_equal 0, @instance.checkpoint_counter
    assert_nil @instance.last_checkpoint_name
  end

  def test_checkpoint_names_returns_keys
    @instance.checkpoint_store['alpha'] = { position: 1 }
    @instance.checkpoint_store['beta'] = { position: 2 }

    names = @instance.checkpoint_names
    assert_includes names, 'alpha'
    assert_includes names, 'beta'
    assert_equal 2, names.size
  end

  def test_checkpoint_names_empty
    assert_empty @instance.checkpoint_names
  end

  def test_checkpoint_positions_maps_positions_to_names
    @instance.checkpoint_store['a'] = { position: 1 }
    @instance.checkpoint_store['b'] = { position: 2 }
    @instance.checkpoint_store['c'] = { position: 1 }

    positions = @instance.checkpoint_positions
    assert_equal ['a', 'c'], positions[1].sort
    assert_equal ['b'], positions[2]
  end

  def test_checkpoint_positions_empty
    assert_empty @instance.checkpoint_positions
  end

  def test_remove_invalid_checkpoints_removes_higher_positions
    @instance.checkpoint_store['a'] = { position: 1 }
    @instance.checkpoint_store['b'] = { position: 3 }
    @instance.checkpoint_store['c'] = { position: 5 }

    removed = @instance.remove_invalid_checkpoints(2)
    assert_equal 2, removed
    assert @instance.checkpoint_store.key?('a')
    refute @instance.checkpoint_store.key?('b')
    refute @instance.checkpoint_store.key?('c')
  end

  def test_remove_invalid_checkpoints_keeps_equal_positions
    @instance.checkpoint_store['a'] = { position: 2 }
    @instance.checkpoint_store['b'] = { position: 2 }

    removed = @instance.remove_invalid_checkpoints(2)
    assert_equal 0, removed
    assert_equal 2, @instance.checkpoint_store.size
  end

  def test_remove_invalid_checkpoints_returns_zero_when_none_removed
    @instance.checkpoint_store['a'] = { position: 1 }
    removed = @instance.remove_invalid_checkpoints(10)
    assert_equal 0, removed
  end

  def test_find_previous_checkpoint_returns_nil_with_fewer_than_two
    assert_nil @instance.find_previous_checkpoint

    @instance.checkpoint_store['only'] = { position: 1 }
    assert_nil @instance.find_previous_checkpoint
  end

  def test_find_previous_checkpoint_returns_second_to_last
    @instance.checkpoint_store['first'] = { position: 1 }
    @instance.checkpoint_store['second'] = { position: 5 }
    @instance.checkpoint_store['third'] = { position: 10 }

    result = @instance.find_previous_checkpoint
    assert_equal 'second', result
  end

  def test_find_previous_checkpoint_with_two_checkpoints
    @instance.checkpoint_store['early'] = { position: 1 }
    @instance.checkpoint_store['late'] = { position: 10 }

    result = @instance.find_previous_checkpoint
    assert_equal 'early', result
  end

  def test_aliases_exist
    assert_respond_to @instance, :ckp
    assert_respond_to @instance, :cp
    assert_respond_to @instance, :context
    assert_respond_to @instance, :checkpoints
  end
end
