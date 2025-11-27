# frozen_string_literal: true

require "test_helper"

class PeekMessagesTest < IntegrationTest
  def setup
    super
    @client.create_queue(@test_queue)
  end

  def test_peek_returns_array_of_messages
    @client.send(@test_queue, { "data" => "test" })

    messages = @client.peek(@test_queue)

    assert_instance_of Array, messages
    assert_equal 1, messages.length
    assert messages.first.is_a?(PGMQ::Message)
  end

  def test_peek_returns_empty_array_when_queue_empty
    messages = @client.peek(@test_queue)

    assert_equal [], messages
  end

  def test_peek_returns_message_objects_with_all_attributes
    @client.send(@test_queue, { "key" => "value" })

    messages = @client.peek(@test_queue)
    message = messages.first

    assert_instance_of Integer, message.msg_id
    assert_instance_of Integer, message.read_ct
    assert_instance_of Time, message.enqueued_at
    assert_instance_of Time, message.vt
    assert_equal({ "key" => "value" }, message.payload)
  end

  def test_peek_respects_qty_parameter
    5.times { |i| @client.send(@test_queue, { "id" => i }) }

    messages = @client.peek(@test_queue, qty: 3)

    assert_equal 3, messages.length
  end

  def test_peek_does_not_set_visibility_timeout
    @client.send(@test_queue, { "data" => "test" })

    # Peek at the message
    messages1 = @client.peek(@test_queue)
    assert_equal 1, messages1.length

    # Peek again - message should still be visible (not affected by previous peek)
    messages2 = @client.peek(@test_queue)
    assert_equal 1, messages2.length

    # Read should also work - message wasn't consumed by peek
    messages3 = @client.read(@test_queue, vt: 30)
    assert_equal 1, messages3.length
  end

  def test_peek_does_not_increment_read_count
    @client.send(@test_queue, { "data" => "test" })

    # Peek multiple times
    messages1 = @client.peek(@test_queue)
    messages2 = @client.peek(@test_queue)
    messages3 = @client.peek(@test_queue)

    # Read count should still be 0 (peek doesn't affect it)
    assert_equal 0, messages1.first.read_ct
    assert_equal 0, messages2.first.read_ct
    assert_equal 0, messages3.first.read_ct
  end

  def test_peek_after_read_shows_invisible_messages
    @client.send(@test_queue, { "data" => "test" })

    # Read the message (makes it invisible)
    read_messages = @client.read(@test_queue, vt: 60)
    assert_equal 1, read_messages.length

    # Read again - should be empty (message is invisible)
    read_messages2 = @client.read(@test_queue, vt: 30)
    assert_empty read_messages2

    # But peek should still show it (peek sees all messages regardless of VT)
    peek_messages = @client.peek(@test_queue)
    assert_equal 1, peek_messages.length
  end

  def test_peek_returns_messages_in_order
    3.times { |i| @client.send(@test_queue, { "order" => i }) }

    messages = @client.peek(@test_queue, qty: 3)

    assert_equal 0, messages[0].payload["order"]
    assert_equal 1, messages[1].payload["order"]
    assert_equal 2, messages[2].payload["order"]
  end

  def test_peek_default_qty_is_one
    3.times { |i| @client.send(@test_queue, { "id" => i }) }

    messages = @client.peek(@test_queue)

    assert_equal 1, messages.length
  end

  def test_pop_works_after_peek
    @client.send(@test_queue, { "data" => "test" })

    # Peek at the message
    peek_messages = @client.peek(@test_queue)
    assert_equal 1, peek_messages.length

    # Pop should still work (peek didn't affect message)
    popped = @client.pop(@test_queue)
    assert_instance_of PGMQ::Message, popped
    assert_equal({ "data" => "test" }, popped.payload)

    # Queue should be empty now
    assert_nil @client.pop(@test_queue)
  end
end
