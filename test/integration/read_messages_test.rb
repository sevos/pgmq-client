# frozen_string_literal: true

require "test_helper"

class ReadMessagesTest < IntegrationTest
  def setup
    super
    @client.create_queue(@test_queue)
  end

  def test_read_returns_array_of_messages
    @client.send(@test_queue, { "data" => "test" })

    messages = @client.read(@test_queue, vt: 30)

    assert_instance_of Array, messages
    assert_equal 1, messages.length
    assert messages.first.is_a?(PGMQ::Message)
  end

  def test_read_returns_empty_array_when_queue_empty
    messages = @client.read(@test_queue, vt: 30)

    assert_equal [], messages
  end

  def test_read_returns_message_objects
    @client.send(@test_queue, { "key" => "value" })

    messages = @client.read(@test_queue, vt: 30)
    message = messages.first

    assert_instance_of Integer, message.msg_id
    assert_instance_of Integer, message.read_ct
    assert_instance_of Time, message.enqueued_at
    assert_instance_of Time, message.vt
    assert_equal({ "key" => "value" }, message.message)
  end

  def test_read_respects_qty_parameter
    5.times { |i| @client.send(@test_queue, { "id" => i }) }

    messages = @client.read(@test_queue, vt: 30, qty: 3)

    assert_equal 3, messages.length
  end

  def test_read_sets_visibility_timeout
    @client.send(@test_queue, { "data" => "test" })

    # Read with short VT
    messages1 = @client.read(@test_queue, vt: 1)
    assert_equal 1, messages1.length

    # Immediately read again - should be empty (message invisible)
    messages2 = @client.read(@test_queue, vt: 30)
    assert_empty messages2

    # Wait for VT to expire
    sleep 1.5

    # Now message should be visible again
    messages3 = @client.read(@test_queue, vt: 30)
    assert_equal 1, messages3.length
  end

  def test_read_increments_read_count
    @client.send(@test_queue, { "data" => "test" })

    # First read
    messages1 = @client.read(@test_queue, vt: 1)
    assert_equal 1, messages1.first.read_ct

    sleep 1.5

    # Second read
    messages2 = @client.read(@test_queue, vt: 1)
    assert_equal 2, messages2.first.read_ct
  end

  def test_read_with_poll_waits_for_messages
    # Start a thread that will send a message after a delay using a separate client
    params = DockerHelper.connection_params
    Thread.new do
      sleep 0.5
      thread_client = PGMQ::Client.new(**params)
      thread_client.send(@test_queue, { "delayed" => true })
      thread_client.close
    end

    start_time = Time.now
    messages = @client.read_with_poll(@test_queue, vt: 30, qty: 1, max_poll_seconds: 3)
    elapsed = Time.now - start_time

    assert_equal 1, messages.length
    assert_equal({ "delayed" => true }, messages.first.payload)
    assert_operator elapsed, :>=, 0.4 # Should have waited at least ~0.5 second
  end

  def test_read_with_poll_returns_immediately_when_messages_available
    @client.send(@test_queue, { "immediate" => true })

    start_time = Time.now
    messages = @client.read_with_poll(@test_queue, vt: 30, qty: 1, max_poll_seconds: 5)
    elapsed = Time.now - start_time

    assert_equal 1, messages.length
    assert_operator elapsed, :<, 1 # Should return almost immediately
  end

  def test_read_with_poll_respects_max_poll_seconds
    start_time = Time.now
    messages = @client.read_with_poll(@test_queue, vt: 30, qty: 1, max_poll_seconds: 2)
    elapsed = Time.now - start_time

    assert_empty messages
    assert_operator elapsed, :>=, 1.5 # Should wait close to max_poll_seconds
    assert_operator elapsed, :<, 3 # But not too long
  end

  def test_pop_returns_single_message
    @client.send(@test_queue, { "data" => "test" })

    message = @client.pop(@test_queue)

    assert_instance_of PGMQ::Message, message
    assert_equal({ "data" => "test" }, message.payload)
  end

  def test_pop_deletes_message_atomically
    @client.send(@test_queue, { "data" => "test" })

    message = @client.pop(@test_queue)
    assert_instance_of PGMQ::Message, message

    # Message should be gone - no more messages available
    messages = @client.read(@test_queue, vt: 30)
    assert_empty messages
  end

  def test_pop_returns_nil_when_queue_empty
    message = @client.pop(@test_queue)

    assert_nil message
  end
end
