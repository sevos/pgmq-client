# frozen_string_literal: true

require "test_helper"

begin
  require "async"
  ASYNC_AVAILABLE = true
rescue LoadError
  ASYNC_AVAILABLE = false
end

class AsyncTest < IntegrationTest
  def setup
    skip "async gem not available" unless ASYNC_AVAILABLE
    super
    @client.create_queue(@test_queue)
  end

  def test_async_send_and_read
    Sync do
      msg_id = @client.send(@test_queue, { "async" => true })

      assert_instance_of Integer, msg_id

      messages = @client.read(@test_queue, vt: 30)
      assert_equal 1, messages.length
      assert_equal({ "async" => true }, messages.first.payload)
    end
  end

  def test_async_concurrent_operations
    params = DockerHelper.connection_params

    Sync do |task|
      queue1 = "#{@test_queue}_1"
      queue2 = "#{@test_queue}_2"

      # Create queues in separate clients
      client1 = PGMQ::Client.new(**params)
      client2 = PGMQ::Client.new(**params)

      client1.create_queue(queue1)
      client2.create_queue(queue2)

      results = []

      # Run concurrent sends
      task1 = task.async do
        5.times { |i| client1.send(queue1, { "client" => 1, "id" => i }) }
        :client1_done
      end

      task2 = task.async do
        5.times { |i| client2.send(queue2, { "client" => 2, "id" => i }) }
        :client2_done
      end

      # Wait for both tasks
      results << task1.wait
      results << task2.wait

      assert_equal [:client1_done, :client2_done], results

      # Verify messages
      msgs1 = client1.read(queue1, vt: 30, qty: 10)
      msgs2 = client2.read(queue2, vt: 30, qty: 10)

      assert_equal 5, msgs1.length
      assert_equal 5, msgs2.length

      # Cleanup
      client1.drop_queue(queue1)
      client2.drop_queue(queue2)
      client1.close
      client2.close
    end
  end

  def test_async_connection_pool
    params = DockerHelper.connection_params

    Sync do |task|
      pool = PGMQ::ConnectionPool.new(size: 3, **params)

      results = []
      barrier = Async::Barrier.new

      # Spawn multiple concurrent tasks
      5.times do |i|
        barrier.async do
          pool.with_connection do |client|
            client.send(@test_queue, { "pool_task" => i })
            results << i
          end
        end
      end

      barrier.wait

      assert_equal 5, results.length

      # Verify all messages were sent
      messages = pool.with_connection do |client|
        client.read(@test_queue, vt: 30, qty: 10)
      end

      assert_equal 5, messages.length

      pool.close
    end
  end

  def test_async_read_with_poll_non_blocking
    params = DockerHelper.connection_params

    Sync do |task|
      producer_client = PGMQ::Client.new(**params)
      producer_started = false

      # Start a producer that will send after a delay
      producer = task.async do
        producer_started = true
        sleep 0.5
        producer_client.send(@test_queue, { "from_producer" => true })
        producer_client.close
      end

      # Wait for producer to start
      sleep 0.1 until producer_started

      # Consumer should block waiting for message
      start_time = Time.now
      messages = @client.read_with_poll(@test_queue, vt: 30, qty: 1, max_poll_seconds: 3)
      elapsed = Time.now - start_time

      # Should have received the message
      assert_equal 1, messages.length
      assert_equal({ "from_producer" => true }, messages.first.payload)

      # Should not have waited full 3 seconds
      assert_operator elapsed, :<, 2

      producer.wait
    end
  end
end
