require_relative '../../test_helper'

class DirectivesCheckpointHelpersTest < Minitest::Test
  def setup
    AIA::Directives::Checkpoint.reset!
  end

  def teardown
    AIA::Directives::Checkpoint.reset!
  end

  def test_reset_clears_all_state
    AIA::Directives::Checkpoint.checkpoint_store['test'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_counter = 5
    AIA::Directives::Checkpoint.last_checkpoint_name = 'test'

    AIA::Directives::Checkpoint.reset!

    assert_empty AIA::Directives::Checkpoint.checkpoint_store
    assert_equal 0, AIA::Directives::Checkpoint.checkpoint_counter
    assert_nil AIA::Directives::Checkpoint.last_checkpoint_name
  end

  def test_checkpoint_names_returns_keys
    AIA::Directives::Checkpoint.checkpoint_store['alpha'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_store['beta'] = { position: 2 }

    names = AIA::Directives::Checkpoint.checkpoint_names
    assert_includes names, 'alpha'
    assert_includes names, 'beta'
    assert_equal 2, names.size
  end

  def test_checkpoint_names_empty
    assert_empty AIA::Directives::Checkpoint.checkpoint_names
  end

  def test_checkpoint_positions_maps_positions_to_names
    AIA::Directives::Checkpoint.checkpoint_store['a'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_store['b'] = { position: 2 }
    AIA::Directives::Checkpoint.checkpoint_store['c'] = { position: 1 }

    positions = AIA::Directives::Checkpoint.checkpoint_positions
    assert_equal ['a', 'c'], positions[1].sort
    assert_equal ['b'], positions[2]
  end

  def test_checkpoint_positions_empty
    assert_empty AIA::Directives::Checkpoint.checkpoint_positions
  end

  def test_remove_invalid_checkpoints_removes_higher_positions
    AIA::Directives::Checkpoint.checkpoint_store['a'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_store['b'] = { position: 3 }
    AIA::Directives::Checkpoint.checkpoint_store['c'] = { position: 5 }

    removed = AIA::Directives::Checkpoint.remove_invalid_checkpoints(2)
    assert_equal 2, removed
    assert AIA::Directives::Checkpoint.checkpoint_store.key?('a')
    refute AIA::Directives::Checkpoint.checkpoint_store.key?('b')
    refute AIA::Directives::Checkpoint.checkpoint_store.key?('c')
  end

  def test_remove_invalid_checkpoints_keeps_equal_positions
    AIA::Directives::Checkpoint.checkpoint_store['a'] = { position: 2 }
    AIA::Directives::Checkpoint.checkpoint_store['b'] = { position: 2 }

    removed = AIA::Directives::Checkpoint.remove_invalid_checkpoints(2)
    assert_equal 0, removed
    assert_equal 2, AIA::Directives::Checkpoint.checkpoint_store.size
  end

  def test_remove_invalid_checkpoints_returns_zero_when_none_removed
    AIA::Directives::Checkpoint.checkpoint_store['a'] = { position: 1 }
    removed = AIA::Directives::Checkpoint.remove_invalid_checkpoints(10)
    assert_equal 0, removed
  end

  def test_find_previous_checkpoint_returns_nil_with_fewer_than_two
    assert_nil AIA::Directives::Checkpoint.find_previous_checkpoint

    AIA::Directives::Checkpoint.checkpoint_store['only'] = { position: 1 }
    assert_nil AIA::Directives::Checkpoint.find_previous_checkpoint
  end

  def test_find_previous_checkpoint_returns_second_to_last
    AIA::Directives::Checkpoint.checkpoint_store['first'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_store['second'] = { position: 5 }
    AIA::Directives::Checkpoint.checkpoint_store['third'] = { position: 10 }

    result = AIA::Directives::Checkpoint.find_previous_checkpoint
    assert_equal 'second', result
  end

  def test_find_previous_checkpoint_with_two_checkpoints
    AIA::Directives::Checkpoint.checkpoint_store['early'] = { position: 1 }
    AIA::Directives::Checkpoint.checkpoint_store['late'] = { position: 10 }

    result = AIA::Directives::Checkpoint.find_previous_checkpoint
    assert_equal 'early', result
  end

  def test_aliases_exist
    assert_respond_to AIA::Directives::Checkpoint, :ckp
    assert_respond_to AIA::Directives::Checkpoint, :cp
    assert_respond_to AIA::Directives::Checkpoint, :context
    assert_respond_to AIA::Directives::Checkpoint, :checkpoints
  end
end
