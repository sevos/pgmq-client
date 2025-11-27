# frozen_string_literal: true

require "test_helper"

class DeleteArchiveTest < IntegrationTest
  def setup
    super
    @client.create_queue(@test_queue)
  end

  # =========================================================================
  # Delete Tests
  # =========================================================================

  def test_delete_returns_true_for_existing_message
    msg_id = @client.send(@test_queue, { "data" => "test" })

    result = @client.delete(@test_queue, msg_id)

    assert_equal true, result
  end

  def test_delete_returns_false_for_nonexistent_message
    result = @client.delete(@test_queue, 999_999_999)

    assert_equal false, result
  end

  def test_delete_removes_message_from_queue
    msg_id = @client.send(@test_queue, { "data" => "test" })
    @client.delete(@test_queue, msg_id)

    messages = @client.read(@test_queue, vt: 30)

    assert_empty messages
  end

  def test_delete_batch_returns_deleted_ids
    msg_ids = 3.times.map { |i| @client.send(@test_queue, { "id" => i }) }

    deleted_ids = @client.delete_batch(@test_queue, msg_ids)

    assert_equal 3, deleted_ids.length
    assert_equal msg_ids.sort, deleted_ids.sort
  end

  def test_delete_batch_with_empty_array_returns_empty
    deleted_ids = @client.delete_batch(@test_queue, [])

    assert_equal [], deleted_ids
  end

  def test_delete_batch_removes_all_messages
    3.times { |i| @client.send(@test_queue, { "id" => i }) }
    messages = @client.read(@test_queue, vt: 1, qty: 10)
    msg_ids = messages.map(&:msg_id)

    @client.delete_batch(@test_queue, msg_ids)

    # Wait for VT to expire
    sleep 1.5

    remaining = @client.read(@test_queue, vt: 30, qty: 10)
    assert_empty remaining
  end

  def test_delete_batch_with_some_invalid_ids
    valid_id = @client.send(@test_queue, { "data" => "test" })
    invalid_id = 999_999_999

    deleted_ids = @client.delete_batch(@test_queue, [valid_id, invalid_id])

    # Should only return the valid deleted ID
    assert_equal [valid_id], deleted_ids
  end

  # =========================================================================
  # Archive Tests
  # =========================================================================

  def test_archive_returns_true_for_existing_message
    msg_id = @client.send(@test_queue, { "data" => "test" })

    result = @client.archive(@test_queue, msg_id)

    assert_equal true, result
  end

  def test_archive_returns_false_for_nonexistent_message
    result = @client.archive(@test_queue, 999_999_999)

    assert_equal false, result
  end

  def test_archive_removes_message_from_queue
    msg_id = @client.send(@test_queue, { "data" => "test" })
    @client.archive(@test_queue, msg_id)

    messages = @client.read(@test_queue, vt: 30)

    assert_empty messages
  end

  def test_archive_batch_returns_archived_ids
    msg_ids = 3.times.map { |i| @client.send(@test_queue, { "id" => i }) }

    archived_ids = @client.archive_batch(@test_queue, msg_ids)

    assert_equal 3, archived_ids.length
    assert_equal msg_ids.sort, archived_ids.sort
  end

  def test_archive_batch_with_empty_array_returns_empty
    archived_ids = @client.archive_batch(@test_queue, [])

    assert_equal [], archived_ids
  end

  def test_archive_batch_removes_all_messages
    3.times { |i| @client.send(@test_queue, { "id" => i }) }
    messages = @client.read(@test_queue, vt: 1, qty: 10)
    msg_ids = messages.map(&:msg_id)

    @client.archive_batch(@test_queue, msg_ids)

    # Wait for VT to expire
    sleep 1.5

    remaining = @client.read(@test_queue, vt: 30, qty: 10)
    assert_empty remaining
  end

  def test_archive_batch_with_some_invalid_ids
    valid_id = @client.send(@test_queue, { "data" => "test" })
    invalid_id = 999_999_999

    archived_ids = @client.archive_batch(@test_queue, [valid_id, invalid_id])

    # Should only return the valid archived ID
    assert_equal [valid_id], archived_ids
  end

  # =========================================================================
  # Detach Archive Tests
  # =========================================================================

  def test_detach_archive_completes_without_error
    # Just verify the method runs without error
    # The archive table should exist after creating queue
    @client.detach_archive(@test_queue)

    # Should be able to still use the queue
    msg_id = @client.send(@test_queue, { "data" => "test" })
    assert_instance_of Integer, msg_id
  end
end
