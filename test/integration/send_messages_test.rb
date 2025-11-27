# frozen_string_literal: true

require "test_helper"

class SendMessagesTest < IntegrationTest
  def setup
    super
    @client.create_queue(@test_queue)
  end

  def test_send_returns_message_id
    msg_id = @client.send(@test_queue, { "data" => "test" })

    assert_instance_of Integer, msg_id
    assert_operator msg_id, :>, 0
  end

  def test_send_with_hash_payload
    msg_id = @client.send(@test_queue, { "key" => "value", "number" => 42 })

    messages = @client.read(@test_queue, vt: 1)
    assert_equal 1, messages.length
    assert_equal({ "key" => "value", "number" => 42 }, messages.first.payload)
  end

  def test_send_with_nested_hash_payload
    payload = {
      "user" => {
        "id" => 123,
        "name" => "John",
        "emails" => ["john@example.com", "j@example.org"]
      }
    }
    @client.send(@test_queue, payload)

    messages = @client.read(@test_queue, vt: 1)
    assert_equal payload, messages.first.payload
  end

  def test_send_with_array_payload
    payload = [1, 2, 3, { "nested" => true }]
    @client.send(@test_queue, payload)

    messages = @client.read(@test_queue, vt: 1)
    assert_equal payload, messages.first.payload
  end

  def test_send_with_delay_makes_message_invisible
    @client.send(@test_queue, { "delayed" => true }, delay: 2)

    # Message should not be visible immediately
    messages = @client.read(@test_queue, vt: 1)
    assert_empty messages

    # Wait for delay to expire
    sleep 2.5

    messages = @client.read(@test_queue, vt: 1)
    assert_equal 1, messages.length
    assert_equal({ "delayed" => true }, messages.first.payload)
  end

  def test_send_batch_returns_array_of_ids
    payloads = [
      { "id" => 1 },
      { "id" => 2 },
      { "id" => 3 }
    ]

    msg_ids = @client.send_batch(@test_queue, payloads)

    assert_instance_of Array, msg_ids
    assert_equal 3, msg_ids.length
    assert msg_ids.all? { |id| id.is_a?(Integer) && id > 0 }
  end

  def test_send_batch_with_empty_array_returns_empty
    msg_ids = @client.send_batch(@test_queue, [])

    assert_equal [], msg_ids
  end

  def test_send_batch_preserves_order
    payloads = (1..5).map { |i| { "order" => i } }

    @client.send_batch(@test_queue, payloads)
    messages = @client.read(@test_queue, vt: 1, qty: 5)

    orders = messages.map { |m| m["order"] }
    assert_equal [1, 2, 3, 4, 5], orders
  end

  def test_send_batch_with_delay
    payloads = [{ "id" => 1 }, { "id" => 2 }]

    @client.send_batch(@test_queue, payloads, delay: 2)

    # Messages should not be visible immediately
    messages = @client.read(@test_queue, vt: 1, qty: 10)
    assert_empty messages

    sleep 2.5

    messages = @client.read(@test_queue, vt: 1, qty: 10)
    assert_equal 2, messages.length
  end

  def test_send_to_nonexistent_queue_raises_error
    assert_raises(PG::Error) do
      @client.send("nonexistent_queue_#{SecureRandom.hex(4)}", { "data" => "test" })
    end
  end

  def test_send_with_special_characters_in_payload
    payload = {
      "message" => "Hello \"world\" with 'quotes'",
      "backslash" => "path\\to\\file",
      "unicode" => "émoji 🎉"
    }

    @client.send(@test_queue, payload)
    messages = @client.read(@test_queue, vt: 1)

    assert_equal payload, messages.first.payload
  end
end
