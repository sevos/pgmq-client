# frozen_string_literal: true

require "test_helper"

class QueueManagementTest < IntegrationTest
  def test_create_queue_creates_new_queue
    @client.create_queue(@test_queue)

    queues = @client.list_queues
    queue_names = queues.map(&:queue_name)

    assert_includes queue_names, @test_queue
  end

  def test_create_queue_is_idempotent
    @client.create_queue(@test_queue)
    @client.create_queue(@test_queue) # Should not raise

    queues = @client.list_queues
    queue_names = queues.map(&:queue_name)

    assert_includes queue_names, @test_queue
  end

  def test_create_unlogged_queue_creates_unlogged_queue
    @client.create_unlogged_queue(@test_queue)

    queues = @client.list_queues
    queue = queues.find { |q| q.queue_name == @test_queue }

    assert_equal true, queue.unlogged?
    assert_equal false, queue.partitioned?
  end

  def test_list_queues_returns_array_of_queue_info
    @client.create_queue(@test_queue)

    queues = @client.list_queues

    assert_instance_of Array, queues
    assert queues.all? { |q| q.is_a?(PGMQ::QueueInfo) }
  end

  def test_list_queues_returns_queue_info_with_all_attributes
    @client.create_queue(@test_queue)

    queues = @client.list_queues
    queue = queues.find { |q| q.queue_name == @test_queue }

    assert_instance_of String, queue.queue_name
    assert_instance_of Time, queue.created_at
    assert_includes [true, false], queue.is_partitioned
    assert_includes [true, false], queue.is_unlogged
  end

  def test_drop_queue_removes_queue
    @client.create_queue(@test_queue)
    @client.drop_queue(@test_queue)

    queues = @client.list_queues
    queue_names = queues.map(&:queue_name)

    refute_includes queue_names, @test_queue
  end

  def test_drop_queue_returns_true_on_success
    @client.create_queue(@test_queue)

    result = @client.drop_queue(@test_queue)

    assert_equal true, result
  end

  def test_drop_queue_returns_false_for_nonexistent
    result = @client.drop_queue("nonexistent_queue_#{SecureRandom.hex(4)}")

    assert_equal false, result
  end

  def test_purge_queue_removes_all_messages
    @client.create_queue(@test_queue)
    @client.send(@test_queue, { "data" => "test1" })
    @client.send(@test_queue, { "data" => "test2" })

    purged_count = @client.purge_queue(@test_queue)

    # Verify messages are gone
    messages = @client.read(@test_queue, vt: 1, qty: 10)
    assert_empty messages
    assert_operator purged_count, :>=, 2
  end

  def test_purge_queue_returns_count_of_purged
    @client.create_queue(@test_queue)
    3.times { |i| @client.send(@test_queue, { "id" => i }) }

    purged_count = @client.purge_queue(@test_queue)

    assert_equal 3, purged_count
  end
end
