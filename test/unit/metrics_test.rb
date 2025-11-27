# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def setup
    @metrics_data = {
      queue_name: "orders",
      queue_length: 150,
      newest_msg_age_sec: 5,
      oldest_msg_age_sec: 3600,
      total_messages: 10_000,
      scrape_time: Time.new(2024, 1, 15, 12, 0, 0, "+00:00")
    }
    @metrics = PGMQ::Metrics.new(**@metrics_data)
  end

  def test_initializes_with_all_attributes
    assert_equal "orders", @metrics.queue_name
    assert_equal 150, @metrics.queue_length
    assert_equal 5, @metrics.newest_msg_age_sec
    assert_equal 3600, @metrics.oldest_msg_age_sec
    assert_equal 10_000, @metrics.total_messages
    assert_equal @metrics_data[:scrape_time], @metrics.scrape_time
  end

  def test_to_h_returns_hash_representation
    hash = @metrics.to_h

    assert_equal "orders", hash[:queue_name]
    assert_equal 150, hash[:queue_length]
    assert_equal 5, hash[:newest_msg_age_sec]
    assert_equal 3600, hash[:oldest_msg_age_sec]
    assert_equal 10_000, hash[:total_messages]
    assert_equal @metrics_data[:scrape_time], hash[:scrape_time]
  end

  def test_scrape_time_is_time_object
    assert_instance_of Time, @metrics.scrape_time
  end

  def test_queue_length_is_integer
    assert_instance_of Integer, @metrics.queue_length
  end

  def test_newest_msg_age_sec_is_integer
    assert_instance_of Integer, @metrics.newest_msg_age_sec
  end

  def test_oldest_msg_age_sec_is_integer
    assert_instance_of Integer, @metrics.oldest_msg_age_sec
  end

  def test_total_messages_is_integer
    assert_instance_of Integer, @metrics.total_messages
  end

  def test_from_pg_row_parses_database_result
    pg_row = {
      "queue_name" => "events",
      "queue_length" => "250",
      "newest_msg_age_sec" => "10",
      "oldest_msg_age_sec" => "7200",
      "total_messages" => "50000",
      "scrape_time" => "2024-01-15 12:30:00+00"
    }

    metrics = PGMQ::Metrics.from_pg_row(pg_row)

    assert_equal "events", metrics.queue_name
    assert_equal 250, metrics.queue_length
    assert_equal 10, metrics.newest_msg_age_sec
    assert_equal 7200, metrics.oldest_msg_age_sec
    assert_equal 50_000, metrics.total_messages
    assert_instance_of Time, metrics.scrape_time
  end

  def test_from_pg_row_handles_nil_age_values
    pg_row = {
      "queue_name" => "empty_queue",
      "queue_length" => "0",
      "newest_msg_age_sec" => nil,
      "oldest_msg_age_sec" => nil,
      "total_messages" => "0",
      "scrape_time" => "2024-01-15 12:30:00+00"
    }

    metrics = PGMQ::Metrics.from_pg_row(pg_row)

    assert_equal "empty_queue", metrics.queue_name
    assert_equal 0, metrics.queue_length
    assert_nil metrics.newest_msg_age_sec
    assert_nil metrics.oldest_msg_age_sec
  end

  def test_empty_queue_predicate
    empty_metrics = PGMQ::Metrics.new(
      queue_name: "test",
      queue_length: 0,
      newest_msg_age_sec: nil,
      oldest_msg_age_sec: nil,
      total_messages: 0,
      scrape_time: Time.now
    )

    assert empty_metrics.empty?
    refute @metrics.empty?
  end
end
