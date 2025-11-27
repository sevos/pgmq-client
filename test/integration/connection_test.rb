# frozen_string_literal: true

require "test_helper"

class ConnectionTest < Minitest::Test
  def setup
    @params = DockerHelper.connection_params
  end

  def teardown
    @connection&.close
  end

  def test_connects_with_explicit_params
    @connection = PGMQ::Connection.new(
      host: @params[:host],
      port: @params[:port],
      username: @params[:username],
      password: @params[:password],
      database: @params[:database]
    )

    assert @connection.connected?
  end

  def test_connects_with_configuration_object
    config = PGMQ::Configuration.new(**@params)
    @connection = PGMQ::Connection.new(config)

    assert @connection.connected?
  end

  def test_connected_returns_true_when_connected
    @connection = PGMQ::Connection.new(**@params)

    assert @connection.connected?
  end

  def test_connected_returns_false_after_close
    @connection = PGMQ::Connection.new(**@params)
    @connection.close

    refute @connection.connected?
  end

  def test_close_releases_connection
    @connection = PGMQ::Connection.new(**@params)
    assert @connection.connected?

    @connection.close
    refute @connection.connected?

    # Can close multiple times without error
    @connection.close
    refute @connection.connected?
  end

  def test_exec_returns_result
    @connection = PGMQ::Connection.new(**@params)

    result = @connection.exec("SELECT 1 AS num")

    assert_equal 1, result.ntuples
    assert_equal "1", result.first["num"]
  end

  def test_exec_with_params
    @connection = PGMQ::Connection.new(**@params)

    result = @connection.exec("SELECT $1::int AS num", [42])

    assert_equal "42", result.first["num"]
  end

  def test_raises_connection_error_on_invalid_params
    assert_raises(PGMQ::ConnectionError) do
      PGMQ::Connection.new(
        host: "nonexistent-host",
        port: 5432,
        username: "postgres",
        password: "postgres",
        database: "postgres"
      )
    end
  end

  def test_can_execute_pgmq_functions
    @connection = PGMQ::Connection.new(**@params)

    # Test that PGMQ extension is available
    result = @connection.exec("SELECT pgmq.create('test_connection_queue')")
    assert result

    # Clean up
    @connection.exec("SELECT pgmq.drop_queue('test_connection_queue')")
  end

  def test_reconnects_after_connection_lost
    @connection = PGMQ::Connection.new(**@params)

    # Simulate connection loss by closing internal connection
    @connection.instance_variable_get(:@conn)&.close

    # Should automatically reconnect on next exec
    result = @connection.exec("SELECT 1 AS num")
    assert_equal "1", result.first["num"]
  end
end
