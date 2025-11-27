# frozen_string_literal: true

require "test_helper"

class MessageTest < Minitest::Test
  def setup
    @msg_data = {
      msg_id: 123,
      read_ct: 2,
      enqueued_at: Time.new(2024, 1, 15, 10, 30, 0, "+00:00"),
      vt: Time.new(2024, 1, 15, 10, 30, 30, "+00:00"),
      message: { "user_id" => 42, "action" => "signup" }
    }
    @message = PGMQ::Message.new(**@msg_data)
  end

  def test_initializes_with_all_attributes
    assert_equal 123, @message.msg_id
    assert_equal 2, @message.read_ct
    assert_equal @msg_data[:enqueued_at], @message.enqueued_at
    assert_equal @msg_data[:vt], @message.vt
    assert_equal({ "user_id" => 42, "action" => "signup" }, @message.message)
  end

  def test_payload_returns_message_hash
    assert_equal @message.message, @message.payload
    assert_equal({ "user_id" => 42, "action" => "signup" }, @message.payload)
  end

  def test_bracket_accessor_delegates_to_message
    assert_equal 42, @message["user_id"]
    assert_equal "signup", @message["action"]
    assert_nil @message["nonexistent"]
  end

  def test_bracket_accessor_with_symbol_key
    assert_equal 42, @message[:user_id]
    assert_equal "signup", @message[:action]
  end

  def test_to_h_returns_hash_representation
    hash = @message.to_h

    assert_equal 123, hash[:msg_id]
    assert_equal 2, hash[:read_ct]
    assert_equal @msg_data[:enqueued_at], hash[:enqueued_at]
    assert_equal @msg_data[:vt], hash[:vt]
    assert_equal({ "user_id" => 42, "action" => "signup" }, hash[:message])
  end

  def test_enqueued_at_is_time_object
    assert_instance_of Time, @message.enqueued_at
  end

  def test_vt_is_time_object
    assert_instance_of Time, @message.vt
  end

  def test_from_pg_row_parses_database_result
    pg_row = {
      "msg_id" => "456",
      "read_ct" => "3",
      "enqueued_at" => "2024-01-15 10:30:00+00",
      "vt" => "2024-01-15 10:31:00+00",
      "message" => '{"event":"test"}'
    }

    message = PGMQ::Message.from_pg_row(pg_row)

    assert_equal 456, message.msg_id
    assert_equal 3, message.read_ct
    assert_instance_of Time, message.enqueued_at
    assert_instance_of Time, message.vt
    assert_equal({ "event" => "test" }, message.message)
  end

  def test_msg_id_is_integer
    assert_instance_of Integer, @message.msg_id
  end

  def test_read_ct_is_integer
    assert_instance_of Integer, @message.read_ct
  end
end
