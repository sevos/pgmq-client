# frozen_string_literal: true

require "test_helper"

class ConnectionPoolTest < Minitest::Test
  def setup
    @mock_client_class = Class.new do
      attr_reader :closed

      def initialize(**_opts)
        @closed = false
      end

      def close
        @closed = true
      end

      def connected?
        !@closed
      end
    end
  end

  def test_initializes_with_size_and_options
    pool = PGMQ::ConnectionPool.new(
      size: 5,
      host: "localhost",
      port: 5432,
      client_class: @mock_client_class
    )

    assert_equal 5, pool.size
  ensure
    pool&.close
  end

  def test_with_connection_yields_client
    pool = PGMQ::ConnectionPool.new(
      size: 2,
      host: "localhost",
      client_class: @mock_client_class
    )

    yielded = false
    pool.with_connection do |client|
      yielded = true
      assert_instance_of @mock_client_class, client
    end

    assert yielded
  ensure
    pool&.close
  end

  def test_returns_connection_to_pool_after_block
    pool = PGMQ::ConnectionPool.new(
      size: 1,
      host: "localhost",
      client_class: @mock_client_class
    )

    first_client = nil
    pool.with_connection { |c| first_client = c }

    second_client = nil
    pool.with_connection { |c| second_client = c }

    assert_same first_client, second_client
  ensure
    pool&.close
  end

  def test_creates_connections_lazily
    pool = PGMQ::ConnectionPool.new(
      size: 5,
      host: "localhost",
      client_class: @mock_client_class
    )

    # No connections created yet
    assert_equal 0, pool.current_size

    # First checkout creates one
    pool.with_connection { |_| }
    assert_equal 1, pool.current_size
  ensure
    pool&.close
  end

  def test_close_closes_all_connections
    pool = PGMQ::ConnectionPool.new(
      size: 2,
      host: "localhost",
      client_class: @mock_client_class
    )

    clients = []
    pool.with_connection { |c| clients << c }
    pool.with_connection { |c| clients << c }

    pool.close

    clients.each do |client|
      assert client.closed
    end
  end

  def test_with_connection_returns_block_value
    pool = PGMQ::ConnectionPool.new(
      size: 1,
      host: "localhost",
      client_class: @mock_client_class
    )

    result = pool.with_connection { 42 }

    assert_equal 42, result
  ensure
    pool&.close
  end

  def test_with_connection_returns_connection_on_exception
    pool = PGMQ::ConnectionPool.new(
      size: 1,
      host: "localhost",
      client_class: @mock_client_class
    )

    assert_raises(RuntimeError) do
      pool.with_connection { raise "test error" }
    end

    # Connection should be back in pool
    pool.with_connection do |client|
      assert client.connected?
    end
  ensure
    pool&.close
  end
end
