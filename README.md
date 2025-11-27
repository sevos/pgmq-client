# pgmq-client

A Ruby client for [PGMQ](https://github.com/tembo-io/pgmq) (PostgreSQL Message Queue).

PGMQ is a lightweight message queue built on PostgreSQL. This gem provides a clean Ruby interface to all PGMQ functionality, with support for both synchronous and asynchronous operation via Ruby's Fiber Scheduler.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pgmq-client'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install pgmq-client
```

## Requirements

- Ruby 3.3+
- PostgreSQL with [PGMQ extension](https://github.com/tembo-io/pgmq) installed

## Usage

### Basic Example

```ruby
require 'pgmq_client'

# Connect to PostgreSQL with PGMQ
client = PGMQ::Client.new(
  host: "localhost",
  port: 5432,
  username: "postgres",
  password: "password",
  database: "myapp"
)

# Create a queue
client.create_queue("orders")

# Send a message
msg_id = client.send("orders", { order_id: 123, customer: "John" })

# Read messages (sets visibility timeout)
messages = client.read("orders", vt: 30, qty: 1)
message = messages.first

puts message.msg_id      # => 1
puts message.payload     # => { "order_id" => 123, "customer" => "John" }
puts message.read_ct     # => 1
puts message.enqueued_at # => 2024-01-15 10:30:00 UTC

# Delete after processing
client.delete("orders", message.msg_id)

# Close connection
client.close
```

### Configuration

#### Explicit Parameters

```ruby
client = PGMQ::Client.new(
  host: "localhost",
  port: 5432,
  username: "postgres",
  password: "secret",
  database: "myapp"
)
```

#### Environment Variables

The client reads from standard PostgreSQL environment variables:

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=secret
export PGDATABASE=myapp
```

Or PGMQ-specific variables (take precedence):

```bash
export PGMQ_HOST=localhost
export PGMQ_PORT=5432
export PGMQ_USERNAME=postgres
export PGMQ_PASSWORD=secret
export PGMQ_DATABASE=myapp
```

```ruby
client = PGMQ::Client.new  # Uses environment variables
```

### Queue Management

```ruby
# Create a standard queue
client.create_queue("my_queue")

# Create an unlogged queue (faster, but not crash-safe)
client.create_unlogged_queue("fast_queue")

# Create a partitioned queue (for high volume)
client.create_partitioned_queue("events", "1 day", "30 days")

# List all queues
queues = client.list_queues
queues.each do |q|
  puts "#{q.queue_name} - created: #{q.created_at}"
end

# Drop a queue
client.drop_queue("my_queue")

# Purge all messages from a queue
count = client.purge_queue("my_queue")
```

### Sending Messages

```ruby
# Send a single message
msg_id = client.send("orders", { order_id: 123 })

# Send with delay (message invisible for 60 seconds)
msg_id = client.send("orders", { order_id: 456 }, delay: 60)

# Send multiple messages
msg_ids = client.send_batch("orders", [
  { order_id: 1 },
  { order_id: 2 },
  { order_id: 3 }
])
```

### Reading Messages

```ruby
# Read messages with visibility timeout
messages = client.read("orders", vt: 30, qty: 10)

# Read with polling (blocks until messages available or timeout)
messages = client.read_with_poll(
  "orders",
  vt: 30,
  qty: 1,
  max_poll_seconds: 5,
  poll_interval_ms: 100
)

# Pop a message (read and delete atomically)
message = client.pop("orders")

# Peek at messages without affecting visibility or read count
# (useful for monitoring, debugging, admin UIs)
messages = client.peek("orders", qty: 10)
```

### Message Processing

```ruby
# Read a message
messages = client.read("orders", vt: 30)
message = messages.first

# Access message data
message.msg_id       # Unique message ID
message.payload      # The message content (Hash)
message.message      # Alias for payload
message["key"]       # Access payload keys directly
message.read_ct      # Number of times message was read
message.enqueued_at  # When message was sent
message.vt           # Visibility timeout expiration

# Delete after successful processing
client.delete("orders", message.msg_id)

# Or archive (moves to archive table)
client.archive("orders", message.msg_id)

# Batch operations
client.delete_batch("orders", [msg_id1, msg_id2])
client.archive_batch("orders", [msg_id1, msg_id2])
```

### Visibility Timeout

```ruby
# Extend visibility timeout for long-running tasks
client.set_vt("orders", message.msg_id, 120)  # 120 more seconds

# Make message immediately visible again
client.set_vt("orders", message.msg_id, 0)
```

### Queue Metrics

```ruby
# Get metrics for a queue
metrics = client.metrics("orders")

puts metrics.queue_name        # => "orders"
puts metrics.queue_length      # => 42
puts metrics.oldest_msg_age_sec # => 300
puts metrics.newest_msg_age_sec # => 5
puts metrics.total_messages    # => 1000
puts metrics.scrape_time       # => 2024-01-15 10:30:00 UTC

# Get metrics for all queues
all_metrics = client.metrics_all
```

### Connection Pooling

For concurrent applications, use the built-in connection pool:

```ruby
pool = PGMQ::ConnectionPool.new(
  size: 10,
  host: "localhost",
  database: "myapp"
)

# Use a connection from the pool
pool.with_connection do |client|
  client.send("orders", { order_id: 123 })
end

# Pool is thread-safe and fiber-safe
threads = 10.times.map do |i|
  Thread.new do
    pool.with_connection do |client|
      client.send("orders", { thread: i })
    end
  end
end
threads.each(&:join)

pool.close
```

### Async Support

The gem works with Ruby's Fiber Scheduler for non-blocking I/O. Use with the `async` gem or any Fiber Scheduler implementation:

```ruby
require 'async'
require 'pgmq_client'

Sync do |task|
  pool = PGMQ::ConnectionPool.new(size: 5, host: "localhost", database: "myapp")

  # Concurrent message processing
  10.times do |i|
    task.async do
      pool.with_connection do |client|
        messages = client.read_with_poll("orders", vt: 30, max_poll_seconds: 5)
        messages.each do |msg|
          process(msg)
          client.delete("orders", msg.msg_id)
        end
      end
    end
  end

  pool.close
end
```

## API Reference

### PGMQ::Client

| Method | Description |
|--------|-------------|
| `create_queue(name)` | Create a standard queue |
| `create_unlogged_queue(name)` | Create an unlogged queue |
| `create_partitioned_queue(name, partition_interval, retention_interval)` | Create a partitioned queue |
| `list_queues` | List all queues |
| `drop_queue(name)` | Delete a queue |
| `purge_queue(name)` | Remove all messages from a queue |
| `send(queue, message, delay: 0)` | Send a single message |
| `send_batch(queue, messages, delay: 0)` | Send multiple messages |
| `read(queue, vt:, qty: 1)` | Read messages with visibility timeout |
| `read_with_poll(queue, vt:, qty:, max_poll_seconds:, poll_interval_ms:)` | Read with blocking poll |
| `pop(queue)` | Read and delete atomically |
| `peek(queue, qty: 1)` | View messages without affecting visibility or read count |
| `delete(queue, msg_id)` | Delete a message |
| `delete_batch(queue, msg_ids)` | Delete multiple messages |
| `archive(queue, msg_id)` | Archive a message |
| `archive_batch(queue, msg_ids)` | Archive multiple messages |
| `set_vt(queue, msg_id, vt)` | Set visibility timeout |
| `metrics(queue)` | Get queue metrics |
| `metrics_all` | Get all queues' metrics |
| `close` | Close connection |
| `connected?` | Check connection status |

### PGMQ::Message

| Attribute | Description |
|-----------|-------------|
| `msg_id` | Unique message identifier |
| `message` / `payload` | Message content (Hash) |
| `read_ct` | Read count |
| `enqueued_at` | Enqueue timestamp |
| `vt` | Visibility timeout expiration |

### PGMQ::ConnectionPool

| Method | Description |
|--------|-------------|
| `with_connection { \|client\| ... }` | Execute block with pooled connection |
| `close` | Close all connections |
| `size` | Pool size |
| `current_size` | Number of connections created |

## Development

### Setup

```bash
git clone https://github.com/your-username/pgmq-client.git
cd pgmq-client
bundle install
```

### Running Tests

Start the test database:

```bash
docker-compose up -d
```

Run the test suite:

```bash
bundle exec rake test
```

### Building the Gem

```bash
gem build pgmq-client.gemspec
```

## License

This gem is available as open source under the terms of the [MIT License](LICENSE).

## Contributing

Bug reports and pull requests are welcome on GitHub.
