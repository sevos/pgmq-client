# frozen_string_literal: true

require "test_helper"

class QueueInfoTest < Minitest::Test
  def setup
    @queue_data = {
      queue_name: "orders",
      created_at: Time.new(2024, 1, 10, 8, 0, 0, "+00:00"),
      is_partitioned: false,
      is_unlogged: true
    }
    @queue_info = PGMQ::QueueInfo.new(**@queue_data)
  end

  def test_initializes_with_all_attributes
    assert_equal "orders", @queue_info.queue_name
    assert_equal @queue_data[:created_at], @queue_info.created_at
    assert_equal false, @queue_info.is_partitioned
    assert_equal true, @queue_info.is_unlogged
  end

  def test_to_h_returns_hash_representation
    hash = @queue_info.to_h

    assert_equal "orders", hash[:queue_name]
    assert_equal @queue_data[:created_at], hash[:created_at]
    assert_equal false, hash[:is_partitioned]
    assert_equal true, hash[:is_unlogged]
  end

  def test_created_at_is_time_object
    assert_instance_of Time, @queue_info.created_at
  end

  def test_is_partitioned_returns_boolean
    assert_includes [true, false], @queue_info.is_partitioned
  end

  def test_is_unlogged_returns_boolean
    assert_includes [true, false], @queue_info.is_unlogged
  end

  def test_from_pg_row_parses_database_result
    pg_row = {
      "queue_name" => "events",
      "created_at" => "2024-01-15 10:30:00+00",
      "is_partitioned" => "f",
      "is_unlogged" => "t"
    }

    queue_info = PGMQ::QueueInfo.from_pg_row(pg_row)

    assert_equal "events", queue_info.queue_name
    assert_instance_of Time, queue_info.created_at
    assert_equal false, queue_info.is_partitioned
    assert_equal true, queue_info.is_unlogged
  end

  def test_from_pg_row_handles_true_boolean_strings
    pg_row = {
      "queue_name" => "test",
      "created_at" => "2024-01-15 10:30:00+00",
      "is_partitioned" => "t",
      "is_unlogged" => "f"
    }

    queue_info = PGMQ::QueueInfo.from_pg_row(pg_row)

    assert_equal true, queue_info.is_partitioned
    assert_equal false, queue_info.is_unlogged
  end

  def test_partitioned_predicate_method
    assert_equal false, @queue_info.partitioned?

    partitioned_queue = PGMQ::QueueInfo.new(
      queue_name: "events",
      created_at: Time.now,
      is_partitioned: true,
      is_unlogged: false
    )
    assert_equal true, partitioned_queue.partitioned?
  end

  def test_unlogged_predicate_method
    assert_equal true, @queue_info.unlogged?

    logged_queue = PGMQ::QueueInfo.new(
      queue_name: "events",
      created_at: Time.now,
      is_partitioned: false,
      is_unlogged: false
    )
    assert_equal false, logged_queue.unlogged?
  end
end
