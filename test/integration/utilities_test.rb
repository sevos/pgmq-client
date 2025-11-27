# frozen_string_literal: true

require "test_helper"

class UtilitiesTest < IntegrationTest
  def setup
    super
    @client.create_queue(@test_queue)
  end

  # =========================================================================
  # set_vt Tests
  # =========================================================================

  def test_set_vt_returns_updated_message
    msg_id = @client.send(@test_queue, { "data" => "test" })
    @client.read(@test_queue, vt: 30) # Make message invisible

    message = @client.set_vt(@test_queue, msg_id, 60)

    assert_instance_of PGMQ::Message, message
    assert_equal msg_id, message.msg_id
  end

  def test_set_vt_changes_visibility_timeout
    msg_id = @client.send(@test_queue, { "data" => "test" })
    @client.read(@test_queue, vt: 30) # Make message invisible

    # Set VT to 1 second from now
    @client.set_vt(@test_queue, msg_id, 1)

    # Message should not be visible yet
    messages = @client.read(@test_queue, vt: 30)
    assert_empty messages

    # Wait for VT to expire
    sleep 1.5

    # Now message should be visible
    messages = @client.read(@test_queue, vt: 30)
    assert_equal 1, messages.length
  end

  def test_set_vt_can_make_message_immediately_visible
    msg_id = @client.send(@test_queue, { "data" => "test" })
    @client.read(@test_queue, vt: 60) # Make message invisible for 60s

    # Set VT to 0 (immediately visible)
    @client.set_vt(@test_queue, msg_id, 0)

    # Message should be visible now
    messages = @client.read(@test_queue, vt: 30)
    assert_equal 1, messages.length
  end

  # =========================================================================
  # metrics Tests
  # =========================================================================

  def test_metrics_returns_metrics_object
    metrics = @client.metrics(@test_queue)

    assert_instance_of PGMQ::Metrics, metrics
  end

  def test_metrics_returns_correct_queue_name
    metrics = @client.metrics(@test_queue)

    assert_equal @test_queue, metrics.queue_name
  end

  def test_metrics_returns_queue_length
    3.times { |i| @client.send(@test_queue, { "id" => i }) }

    metrics = @client.metrics(@test_queue)

    assert_equal 3, metrics.queue_length
  end

  def test_metrics_returns_total_messages
    # Send some messages
    3.times { |i| @client.send(@test_queue, { "id" => i }) }

    metrics = @client.metrics(@test_queue)

    # total_messages should be at least what we sent
    assert_operator metrics.total_messages, :>=, 3
  end

  def test_metrics_tracks_oldest_message_age
    @client.send(@test_queue, { "data" => "test" })
    sleep 1

    metrics = @client.metrics(@test_queue)

    # Age should be at least 1 second
    assert_operator metrics.oldest_msg_age_sec, :>=, 1
  end

  def test_metrics_returns_nil_age_when_empty
    metrics = @client.metrics(@test_queue)

    assert_nil metrics.oldest_msg_age_sec
  end

  def test_metrics_returns_scrape_time
    @client.send(@test_queue, { "data" => "test" })

    metrics = @client.metrics(@test_queue)

    assert_instance_of Time, metrics.scrape_time
  end

  # =========================================================================
  # metrics_all Tests
  # =========================================================================

  def test_metrics_all_returns_array
    metrics = @client.metrics_all

    assert_instance_of Array, metrics
  end

  def test_metrics_all_includes_test_queue
    @client.send(@test_queue, { "data" => "test" })

    metrics = @client.metrics_all
    queue_names = metrics.map(&:queue_name)

    assert_includes queue_names, @test_queue
  end

  def test_metrics_all_returns_metrics_objects
    metrics = @client.metrics_all

    assert metrics.all? { |m| m.is_a?(PGMQ::Metrics) }
  end
end
